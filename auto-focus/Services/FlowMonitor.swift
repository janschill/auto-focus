import CoreGraphics
import Foundation

/// Publishes the live flow reading by re-classifying the trailing window of the app event log.
final class FlowMonitor: ObservableObject {
    @Published private(set) var reading = FlowReading(state: .neutral, switches: 0)

    static let refreshInterval: TimeInterval = 30
    /// Without keyboard or mouse input for this long, the user counts as away.
    static let presenceIdleLimit: TimeInterval = 5 * 60

    private let appEventRepo: AppEventRepository
    private let focusContext: () -> FocusContext
    private let idleTime: () -> TimeInterval
    private var refreshTimer: Timer?

    /// - Parameter idleTime: Seconds since the last keyboard or mouse input; defaults to the system's.
    init(
        appEventRepo: AppEventRepository = AppEventRepository(),
        focusContext: @escaping () -> FocusContext,
        idleTime: @escaping () -> TimeInterval = FlowMonitor.systemIdleTime
    ) {
        self.appEventRepo = appEventRepo
        self.focusContext = focusContext
        self.idleTime = idleTime
    }

    /// Seconds since any keyboard or mouse input in this login session. Needs no permission.
    static func systemIdleTime() -> TimeInterval {
        guard let anyInput = CGEventType(rawValue: UInt32.max) else { return 0 }
        return CGEventSource.secondsSinceLastEventType(.combinedSessionState, eventType: anyInput)
    }

    deinit {
        refreshTimer?.invalidate()
    }

    func start() {
        guard refreshTimer == nil else { return }
        refresh()
        let timer = Timer(timeInterval: Self.refreshInterval, repeats: true) { [weak self] _ in
            self?.refresh()
        }
        RunLoop.main.add(timer, forMode: .common)
        refreshTimer = timer
    }

    func refresh(now: Date = Date()) {
        let windowStart = now.addingTimeInterval(-FlowAnalyzer.windowLength)
        let events: [AppEvent]
        do {
            // The last earlier event gives the context at the window start; +1s includes the current second.
            let earlier = try appEventRepo.fetchLastEvent(before: windowStart)
            events = (earlier.map { [$0] } ?? []) + (try appEventRepo.fetchEvents(since: windowStart, until: now.addingTimeInterval(1)))
        } catch {
            AppLogger.focus.error("Failed to read events for flow state", error: error)
            return
        }
        let newReading = FlowAnalyzer.currentReading(
            events: events,
            context: focusContext(),
            now: now,
            userIsPresent: idleTime() < Self.presenceIdleLimit
        )
        if newReading != reading {
            reading = newReading
        }
    }
}

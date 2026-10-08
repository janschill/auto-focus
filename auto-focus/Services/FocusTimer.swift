import Foundation

/// Tracks focus time. Elapsed time is measured from the clock rather than by counting ticks,
/// so coalesced or delayed timer fires (App Nap, energy saving) don't lose time.
class FocusTimer {
    private var timer: Timer?
    /// Time accumulated in previous running segments.
    private var accumulatedTime: TimeInterval = 0
    /// Start of the current running segment, nil while stopped or paused.
    private var segmentStart: Date?
    private let interval: TimeInterval
    private let now: () -> Date

    /// Callback invoked on each timer tick with the current elapsed time
    var onTick: ((TimeInterval) -> Void)?

    /// Current elapsed time
    var currentTime: TimeInterval {
        guard let segmentStart else { return accumulatedTime }
        return accumulatedTime + now().timeIntervalSince(segmentStart)
    }

    /// Whether the timer is currently running
    var isRunning: Bool {
        return segmentStart != nil
    }

    init(interval: TimeInterval = AppConfiguration.checkInterval, now: @escaping () -> Date = Date.init) {
        self.interval = interval
        self.now = now
    }

    // MARK: - Timer Control

    /// Start the timer, optionally preserving existing elapsed time
    /// - Parameter preserveTime: If true, keeps current elapsed time; if false, resets to 0
    func start(preserveTime: Bool = false) {
        accumulatedTime = preserveTime ? currentTime : 0
        invalidateTimer()
        segmentStart = now()

        let timer = Timer(timeInterval: interval, repeats: true) { [weak self] _ in
            self?.tick()
        }
        timer.tolerance = interval * 0.1
        RunLoop.main.add(timer, forMode: .common)
        self.timer = timer

        AppLogger.focus.info("FocusTimer started", metadata: [
            "preserve_time": String(preserveTime),
            "elapsed_time": String(format: "%.1f", accumulatedTime)
        ])
    }

    /// Pause the timer without resetting elapsed time
    func pause() {
        guard isRunning else { return }
        accumulatedTime = currentTime
        segmentStart = nil
        invalidateTimer()

        AppLogger.focus.info("FocusTimer paused", metadata: [
            "elapsed_time": String(format: "%.1f", accumulatedTime)
        ])
    }

    /// Reset elapsed time to 0 and stop the timer
    func reset() {
        segmentStart = nil
        accumulatedTime = 0
        invalidateTimer()
    }

    // MARK: - Private Methods

    private func invalidateTimer() {
        timer?.invalidate()
        timer = nil
    }

    private func tick() {
        guard isRunning else { return }
        onTick?(currentTime)
    }

    deinit {
        invalidateTimer()
    }
}

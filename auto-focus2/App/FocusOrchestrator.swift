import Foundation

@MainActor
final class FocusOrchestrator: ObservableObject {
    @Published private(set) var state: FocusState
    @Published private(set) var lastDomainResult: DomainResult = .unavailable(reason: .unknown)
    @Published private(set) var lastError: String?

    private let clock: Clocking
    private let stateMachine: FocusStateMachine

    private let settingsStore: FocusSettingsStoring
    private let entityStore: FocusEntityStoring
    private let eventStore: FocusEventStoring
    private let sessionStore: FocusSessionStoring

    private let foregroundProvider: ForegroundProviding
    private let domainProvider: BrowserDomainProviding
    private let notificationsController: NotificationsControlling

    private var timer: Timer?
    private let pollIntervalSeconds: Int

    private var lastForegroundBundleId: String?
    private var lastDomain: String?

    private var activeSessionId: UUID?
    private var activeSessionFocusSeconds: Int = 0

    init(
        clock: Clocking,
        stateMachine: FocusStateMachine,
        settingsStore: FocusSettingsStoring,
        entityStore: FocusEntityStoring,
        eventStore: FocusEventStoring,
        sessionStore: FocusSessionStoring,
        foregroundProvider: ForegroundProviding,
        domainProvider: BrowserDomainProviding,
        notificationsController: NotificationsControlling,
        pollIntervalSeconds: Int = 1
    ) {
        self.clock = clock
        self.stateMachine = stateMachine
        self.settingsStore = settingsStore
        self.entityStore = entityStore
        self.eventStore = eventStore
        self.sessionStore = sessionStore
        self.foregroundProvider = foregroundProvider
        self.domainProvider = domainProvider
        self.notificationsController = notificationsController
        self.pollIntervalSeconds = max(1, pollIntervalSeconds)
        self.state = stateMachine.state
    }

    func start() {
        stop()

        timer = Timer.scheduledTimer(withTimeInterval: TimeInterval(pollIntervalSeconds), repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.pollOnce(tickSeconds: self?.pollIntervalSeconds ?? 1)
            }
        }

        pollOnce(tickSeconds: 0)
    }

    func stop() {
        timer?.invalidate()
        timer = nil
    }

    /// Deterministic entry point for tests / manual driving.
    func pollOnce(tickSeconds: Int) {
        let now = clock.now

        do {
            let settings = try settingsStore.load()
            let entities = try entityStore.list().filter { $0.isEnabled }

            let foregroundBundleId = foregroundProvider.currentForegroundAppBundleId()
            let domainResult = domainProvider.currentDomainIfBrowserFrontmost(foregroundBundleId: foregroundBundleId)
            lastDomainResult = domainResult

            let domain: String? = domainResult.isAvailable ? domainResult.domain : nil

            let contextChanged = (foregroundBundleId != lastForegroundBundleId) || (domain != lastDomain)
            if contextChanged {
                if foregroundBundleId != lastForegroundBundleId {
                    appendEvent(kind: .foregroundChanged, now: now, appBundleId: foregroundBundleId, domain: domain, entityId: nil, details: nil)
                }
                if domain != lastDomain {
                    appendEvent(kind: .domainChanged, now: now, appBundleId: foregroundBundleId, domain: domain, entityId: nil, details: domainResult.isAvailable ? nil : domainResult.reason?.rawValue)
                }

                lastForegroundBundleId = foregroundBundleId
                lastDomain = domain

                let matched = matchEntityId(entities: entities, foregroundBundleId: foregroundBundleId, domain: domain)
                let output = stateMachine.updateContext(
                    ForegroundContext(appBundleId: foregroundBundleId, domain: domain),
                    matchedEntityId: matched,
                    settings: settings,
                    now: now
                )
                handle(output: output, now: now, settings: settings, matchedEntityId: matched)
            }

            if tickSeconds > 0 {
                // Accumulate focus-mode seconds (used when closing session).
                if case .inFocusMode = stateMachine.state.phase {
                    activeSessionFocusSeconds += tickSeconds
                }

                let output = stateMachine.tick(by: tickSeconds, settings: settings, now: now)
                handle(output: output, now: now, settings: settings, matchedEntityId: stateMachine.state.currentEntityId)
            }

            state = stateMachine.state
            lastError = nil
        } catch {
            lastError = String(describing: error)
            appendEvent(kind: .error, now: now, appBundleId: nil, domain: nil, entityId: nil, details: lastError)
        }
    }

    private func matchEntityId(entities: [FocusEntity], foregroundBundleId: String?, domain: String?) -> UUID? {
        if let domain, let match = entities.first(where: { $0.type == .domain && $0.matchValue == domain }) {
            return match.id
        }
        if let foregroundBundleId, let match = entities.first(where: { $0.type == .app && $0.matchValue == foregroundBundleId }) {
            return match.id
        }
        return nil
    }

    private func handle(output: FocusOutput, now: Date, settings: FocusSettings, matchedEntityId: UUID?) {
        switch output {
        case .none:
            return

        case .enteredCounting:
            appendEvent(kind: .enteredCounting, now: now, appBundleId: lastForegroundBundleId, domain: lastDomain, entityId: matchedEntityId, details: nil)

        case .enteredFocusMode(let sessionId):
            activeSessionId = sessionId
            activeSessionFocusSeconds = 0
            appendEvent(kind: .enteredFocusMode, now: now, appBundleId: lastForegroundBundleId, domain: lastDomain, entityId: matchedEntityId, details: nil)

            do {
                try sessionStore.start(FocusSession(
                    id: sessionId,
                    startedAt: now,
                    activationMinutes: settings.activationMinutes,
                    bufferSeconds: settings.bufferSeconds
                ))
            } catch {
                AppLog.persistence.error("Failed to start session: \(error)")
            }

            Task {
                do {
                    try await notificationsController.setNotifications(.disabled)
                } catch {
                    appendEvent(kind: .error, now: clock.now, appBundleId: lastForegroundBundleId, domain: lastDomain, entityId: matchedEntityId, details: error.localizedDescription)
                }
            }

        case .enteredBuffer(let until):
            appendEvent(kind: .enteredBuffer, now: now, appBundleId: lastForegroundBundleId, domain: lastDomain, entityId: matchedEntityId, details: "until=\(until.timeIntervalSince1970)")

        case .exitedFocusMode:
            appendEvent(kind: .exitedFocusMode, now: now, appBundleId: lastForegroundBundleId, domain: lastDomain, entityId: matchedEntityId, details: nil)

            if let sessionId = activeSessionId {
                let reason: FocusSessionEndReason
                // If we exit while buffering, treat as buffer timeout; otherwise leaving focus.
                if case .buffering = stateMachine.state.phase {
                    reason = .bufferTimeout
                } else {
                    reason = .leftFocusEntities
                }
                do {
                    try sessionStore.end(
                        sessionId: sessionId,
                        endedAt: now,
                        reason: reason,
                        totalSecondsInFocusMode: activeSessionFocusSeconds
                    )
                } catch {
                    AppLog.persistence.error("Failed to end session: \(error)")
                }
            }
            activeSessionId = nil
            activeSessionFocusSeconds = 0

            Task {
                do {
                    try await notificationsController.setNotifications(.enabled)
                } catch {
                    appendEvent(kind: .error, now: clock.now, appBundleId: lastForegroundBundleId, domain: lastDomain, entityId: matchedEntityId, details: error.localizedDescription)
                }
            }
        }
    }

    private func appendEvent(kind: FocusEventKind, now: Date, appBundleId: String?, domain: String?, entityId: UUID?, details: String?) {
        do {
            try eventStore.append(FocusEvent(
                timestamp: now,
                kind: kind,
                appBundleId: appBundleId,
                domain: domain,
                focusEntityId: entityId,
                details: details
            ))
        } catch {
            AppLog.persistence.error("Failed to append event: \(error)")
        }
    }
}



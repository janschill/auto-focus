import Foundation

public enum FocusPhase: Equatable, Sendable {
    case idle
    case counting(secondsAccumulated: Int)
    case inFocusMode(sessionId: UUID, startedAt: Date)
    case buffering(sessionId: UUID, bufferEndsAt: Date)
}

public struct FocusState: Equatable, Sendable {
    public var phase: FocusPhase
    public var currentEntityId: UUID?
    public var currentContext: ForegroundContext

    public init(phase: FocusPhase = .idle, currentEntityId: UUID? = nil, currentContext: ForegroundContext = .init(appBundleId: nil, domain: nil)) {
        self.phase = phase
        self.currentEntityId = currentEntityId
        self.currentContext = currentContext
    }
}

public enum FocusOutput: Sendable, Equatable {
    case none
    case enteredCounting
    case enteredFocusMode(sessionId: UUID)
    case enteredBuffer(until: Date)
    case exitedFocusMode
}

/// Deterministic state machine driven by context changes and time ticks.
///
/// Note: This is intentionally minimal at first; we’ll expand behavior as tests are added (T033–T035).
public final class FocusStateMachine: @unchecked Sendable {
    public private(set) var state: FocusState

    public init(initialState: FocusState = FocusState()) {
        self.state = initialState
    }

    public func updateContext(
        _ context: ForegroundContext,
        matchedEntityId: UUID?,
        settings: FocusSettings,
        now: Date
    ) -> FocusOutput {
        state.currentContext = context
        state.currentEntityId = matchedEntityId

        let isInFocusEntities = matchedEntityId != nil
        let activationSeconds = max(60, settings.activationMinutes * 60)
        let bufferSeconds = max(0, settings.bufferSeconds)

        switch state.phase {
        case .idle:
            if isInFocusEntities {
                state.phase = .counting(secondsAccumulated: 0)
                return .enteredCounting
            }
            return .none

        case .counting(let secondsAccumulated):
            if !isInFocusEntities {
                state.phase = .idle
                return .none
            }
            // Count progresses via tick(); context update alone does not advance time.
            if secondsAccumulated >= activationSeconds {
                let sessionId = UUID()
                state.phase = .inFocusMode(sessionId: sessionId, startedAt: now)
                return .enteredFocusMode(sessionId: sessionId)
            }
            return .none

        case .inFocusMode(let sessionId, _):
            if isInFocusEntities {
                return .none
            }
            if bufferSeconds > 0 {
                let ends = now.addingTimeInterval(TimeInterval(bufferSeconds))
                state.phase = .buffering(sessionId: sessionId, bufferEndsAt: ends)
                return .enteredBuffer(until: ends)
            } else {
                state.phase = .idle
                return .exitedFocusMode
            }

        case .buffering(let sessionId, let bufferEndsAt):
            if isInFocusEntities {
                // Return to focus mode, preserve session.
                state.phase = .inFocusMode(sessionId: sessionId, startedAt: now)
                return .none
            }
            // Buffer timeout is handled by tick().
            if now >= bufferEndsAt {
                state.phase = .idle
                return .exitedFocusMode
            }
            return .none
        }
    }

    public func tick(by seconds: Int, settings: FocusSettings, now: Date) -> FocusOutput {
        guard seconds > 0 else { return .none }
        let activationSeconds = max(60, settings.activationMinutes * 60)

        switch state.phase {
        case .counting(let accumulated):
            let newAccumulated = accumulated + seconds
            state.phase = .counting(secondsAccumulated: newAccumulated)
            if newAccumulated >= activationSeconds {
                let sessionId = UUID()
                state.phase = .inFocusMode(sessionId: sessionId, startedAt: now)
                return .enteredFocusMode(sessionId: sessionId)
            }
            return .none

        case .buffering(_, let bufferEndsAt):
            if now >= bufferEndsAt {
                state.phase = .idle
                return .exitedFocusMode
            }
            return .none

        case .idle, .inFocusMode:
            return .none
        }
    }
}



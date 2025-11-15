import Foundation

/// Domain-specific errors for focus control functionality
enum FocusError: LocalizedError {
    case sessionStartFailed
    case sessionEndFailed
    case invalidStateTransition(from: String, to: String)
    case timerStartFailed
    case timerResetFailed
    case focusModeActivationFailed(String)
    case focusModeDeactivationFailed(String)
    case appDetectionFailed
    case bufferStartFailed

    var errorDescription: String? {
        switch self {
        case .sessionStartFailed:
            return "Failed to start focus session"
        case .sessionEndFailed:
            return "Failed to end focus session"
        case .invalidStateTransition(let from, let to):
            return "Invalid state transition from \(from) to \(to)"
        case .timerStartFailed:
            return "Failed to start focus timer"
        case .timerResetFailed:
            return "Failed to reset focus timer"
        case .focusModeActivationFailed(let reason):
            return "Failed to activate focus mode: \(reason)"
        case .focusModeDeactivationFailed(let reason):
            return "Failed to deactivate focus mode: \(reason)"
        case .appDetectionFailed:
            return "Failed to detect active application"
        case .bufferStartFailed:
            return "Failed to start buffer period"
        }
    }

    var failureReason: String? {
        switch self {
        case .sessionStartFailed:
            return "Session manager was unable to start a new session"
        case .sessionEndFailed:
            return "Session manager was unable to end the current session"
        case .invalidStateTransition(let from, let to):
            return "Cannot transition from \(from) state to \(to) state"
        case .timerStartFailed:
            return "Focus timer encountered an error during startup"
        case .timerResetFailed:
            return "Focus timer encountered an error during reset"
        case .focusModeActivationFailed(let reason):
            return reason
        case .focusModeDeactivationFailed(let reason):
            return reason
        case .appDetectionFailed:
            return "Unable to determine the currently active application"
        case .bufferStartFailed:
            return "Buffer manager was unable to start the buffer period"
        }
    }
}


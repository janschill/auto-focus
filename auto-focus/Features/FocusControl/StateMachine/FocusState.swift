import Foundation

/// Represents the possible states of the focus system
enum FocusState: Equatable {
    /// Not tracking focus - idle state
    case idle
    
    /// Tracking time but haven't reached threshold yet
    case counting(timeSpent: TimeInterval)
    
    /// In active focus mode (DND enabled)
    case focusMode(timeSpent: TimeInterval)
    
    /// In buffer period after leaving focus
    case buffer(timeRemaining: TimeInterval)
    
    /// State name for logging/debugging
    var name: String {
        switch self {
        case .idle:
            return "idle"
        case .counting:
            return "counting"
        case .focusMode:
            return "focusMode"
        case .buffer:
            return "buffer"
        }
    }
    
    /// Whether focus mode (DND) should be active
    var isFocusModeActive: Bool {
        if case .focusMode = self {
            return true
        }
        return false
    }
    
    /// Whether we're currently tracking time
    var isTracking: Bool {
        switch self {
        case .idle, .buffer:
            return false
        case .counting, .focusMode:
            return true
        }
    }
}

/// Represents a transition between focus states
struct FocusTransition {
    let from: FocusState
    let to: FocusState
    let timestamp: Date
    
    init(from: FocusState, to: FocusState) {
        self.from = from
        self.to = to
        self.timestamp = Date()
    }
    
    var description: String {
        return "\(from.name) → \(to.name)"
    }
}


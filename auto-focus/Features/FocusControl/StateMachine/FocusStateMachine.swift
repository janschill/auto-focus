import Foundation

/// Manages focus state transitions and validates state changes
class FocusStateMachine {
    private(set) var currentState: FocusState = .idle
    private var transitionHistory: [FocusTransition] = []

    /// Callback invoked when state changes
    var onStateChanged: ((FocusTransition) -> Void)?

    /// Maximum number of transitions to keep in history
    private let maxHistorySize = 100

    init() {
        AppLogger.focus.info("Focus state machine initialized", metadata: [
            "initial_state": currentState.name
        ])
    }

    // MARK: - State Transitions

    /// Transition to idle state
    func transitionToIdle() {
        transition(to: .idle)
    }

    /// Transition to counting state
    /// - Parameter timeSpent: Current elapsed time
    func transitionToCounting(timeSpent: TimeInterval) {
        transition(to: .counting(timeSpent: timeSpent))
    }

    /// Transition to focus mode
    /// - Parameter timeSpent: Current elapsed time
    func transitionToFocusMode(timeSpent: TimeInterval) {
        transition(to: .focusMode(timeSpent: timeSpent))
    }

    /// Transition to buffer state
    /// - Parameter timeRemaining: Remaining buffer time
    func transitionToBuffer(timeRemaining: TimeInterval) {
        transition(to: .buffer(timeRemaining: timeRemaining))
    }

    // MARK: - State Updates

    /// Update the current state with new time values (for counting/focusMode states)
    func updateTime(timeSpent: TimeInterval) {
        switch currentState {
        case .counting:
            currentState = .counting(timeSpent: timeSpent)
        case .focusMode:
            currentState = .focusMode(timeSpent: timeSpent)
        default:
            // No update needed for other states
            break
        }
    }

    /// Update buffer time remaining
    func updateBufferTime(timeRemaining: TimeInterval) {
        if case .buffer = currentState {
            currentState = .buffer(timeRemaining: timeRemaining)
        }
    }

    // MARK: - Private Methods

    private func transition(to newState: FocusState) {
        // Don't transition if already in the same state (unless it's a state with associated values)
        if currentState.name == newState.name && !hasAssociatedValues(currentState) {
            return
        }

        let transition = FocusTransition(from: currentState, to: newState)

        // Validate transition
        guard isValidTransition(from: currentState, to: newState) else {
            AppLogger.focus.warning("Invalid state transition attempted", metadata: [
                "from": currentState.name,
                "to": newState.name
            ])
            return
        }

        currentState = newState
        transitionHistory.append(transition)

        // Limit history size
        if transitionHistory.count > maxHistorySize {
            transitionHistory.removeFirst()
        }

        AppLogger.focus.stateChange(
            from: transition.from.name,
            to: transition.to.name,
            metadata: [
                "timestamp": ISO8601DateFormatter().string(from: transition.timestamp)
            ]
        )

        onStateChanged?(transition)
    }

    private func isValidTransition(from: FocusState, to: FocusState) -> Bool {
        // Define valid transitions
        switch (from, to) {
        // From idle: can go to counting
        case (.idle, .counting):
            return true

        // From counting: can go to focusMode, idle, or buffer
        case (.counting, .focusMode), (.counting, .idle), (.counting, .buffer):
            return true

        // From focusMode: can go to buffer or idle
        case (.focusMode, .buffer), (.focusMode, .idle):
            return true

        // From buffer: can go to counting, focusMode, or idle
        case (.buffer, .counting), (.buffer, .focusMode), (.buffer, .idle):
            return true

        // Same state transitions (for updating associated values)
        case (.counting, .counting), (.focusMode, .focusMode), (.buffer, .buffer):
            return true

        default:
            return false
        }
    }

    private func hasAssociatedValues(_ state: FocusState) -> Bool {
        switch state {
        case .idle:
            return false
        case .counting, .focusMode, .buffer:
            return true
        }
    }

    // MARK: - Debugging

    /// Get recent transition history
    func getRecentTransitions(count: Int = 10) -> [FocusTransition] {
        return Array(transitionHistory.suffix(count))
    }

    /// Reset state machine to idle
    func reset() {
        transitionToIdle()
        transitionHistory.removeAll()
        AppLogger.focus.info("Focus state machine reset")
    }
}


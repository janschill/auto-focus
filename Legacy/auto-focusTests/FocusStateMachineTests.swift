import XCTest
@testable import auto_focus

final class FocusStateMachineTests: XCTestCase {
    var stateMachine: FocusStateMachine!
    var receivedTransitions: [FocusTransition] = []

    override func setUp() {
        super.setUp()
        stateMachine = FocusStateMachine()
        receivedTransitions = []

        // Set up callback to capture transitions
        stateMachine.onStateChanged = { [weak self] transition in
            self?.receivedTransitions.append(transition)
        }
    }

    override func tearDown() {
        stateMachine = nil
        receivedTransitions = []
        super.tearDown()
    }

    // MARK: - Initial State Tests

    func testInitialStateIsIdle() {
        XCTAssertEqual(stateMachine.currentState, .idle)
    }

    // MARK: - Valid Transition Tests

    func testIdleToCounting() {
        stateMachine.transitionToCounting(timeSpent: 0.0)
        XCTAssertEqual(stateMachine.currentState.name, "counting")
        XCTAssertEqual(receivedTransitions.count, 1)
        XCTAssertEqual(receivedTransitions.first?.from.name, "idle")
        XCTAssertEqual(receivedTransitions.first?.to.name, "counting")
    }

    func testCountingToFocusMode() {
        stateMachine.transitionToCounting(timeSpent: 0.0)
        stateMachine.transitionToFocusMode(timeSpent: 720.0) // 12 minutes

        XCTAssertEqual(stateMachine.currentState.name, "focusMode")
        XCTAssertEqual(receivedTransitions.count, 2)
        XCTAssertEqual(receivedTransitions.last?.from.name, "counting")
        XCTAssertEqual(receivedTransitions.last?.to.name, "focusMode")
    }

    func testCountingToIdle() {
        stateMachine.transitionToCounting(timeSpent: 10.0)
        stateMachine.transitionToIdle()

        XCTAssertEqual(stateMachine.currentState, .idle)
        XCTAssertEqual(receivedTransitions.count, 2)
        XCTAssertEqual(receivedTransitions.last?.to.name, "idle")
    }

    func testFocusModeToBuffer() {
        stateMachine.transitionToCounting(timeSpent: 0.0)
        stateMachine.transitionToFocusMode(timeSpent: 720.0)
        stateMachine.transitionToBuffer(timeRemaining: 120.0) // 2 minutes buffer

        XCTAssertEqual(stateMachine.currentState.name, "buffer")
        XCTAssertEqual(receivedTransitions.count, 3)
        XCTAssertEqual(receivedTransitions.last?.from.name, "focusMode")
        XCTAssertEqual(receivedTransitions.last?.to.name, "buffer")
    }

    func testBufferToIdle() {
        stateMachine.transitionToCounting(timeSpent: 0.0)
        stateMachine.transitionToFocusMode(timeSpent: 720.0)
        stateMachine.transitionToBuffer(timeRemaining: 120.0)
        stateMachine.transitionToIdle()

        XCTAssertEqual(stateMachine.currentState, .idle)
        XCTAssertEqual(receivedTransitions.count, 4)
    }

    func testBufferToCounting() {
        stateMachine.transitionToCounting(timeSpent: 0.0)
        stateMachine.transitionToFocusMode(timeSpent: 720.0)
        stateMachine.transitionToBuffer(timeRemaining: 120.0)
        stateMachine.transitionToCounting(timeSpent: 720.0)

        XCTAssertEqual(stateMachine.currentState.name, "counting")
        XCTAssertEqual(receivedTransitions.count, 4)
    }

    func testBufferToFocusMode() {
        stateMachine.transitionToCounting(timeSpent: 0.0)
        stateMachine.transitionToFocusMode(timeSpent: 720.0)
        stateMachine.transitionToBuffer(timeRemaining: 120.0)
        stateMachine.transitionToFocusMode(timeSpent: 720.0)

        XCTAssertEqual(stateMachine.currentState.name, "focusMode")
        XCTAssertEqual(receivedTransitions.count, 4)
    }

    // MARK: - Invalid Transition Tests

    func testInvalidTransitionFromIdleToFocusMode() {
        let initialTransitionCount = receivedTransitions.count
        stateMachine.transitionToFocusMode(timeSpent: 720.0)

        // Should remain in idle state
        XCTAssertEqual(stateMachine.currentState, .idle)
        // Should not create a transition
        XCTAssertEqual(receivedTransitions.count, initialTransitionCount)
    }

    func testInvalidTransitionFromIdleToBuffer() {
        let initialTransitionCount = receivedTransitions.count
        stateMachine.transitionToBuffer(timeRemaining: 120.0)

        // Should remain in idle state
        XCTAssertEqual(stateMachine.currentState, .idle)
        // Should not create a transition
        XCTAssertEqual(receivedTransitions.count, initialTransitionCount)
    }

    func testInvalidTransitionFromFocusModeToCounting() {
        stateMachine.transitionToCounting(timeSpent: 0.0)
        stateMachine.transitionToFocusMode(timeSpent: 720.0)
        let transitionCountBefore = receivedTransitions.count

        // Try invalid transition
        stateMachine.transitionToCounting(timeSpent: 800.0)

        // Should remain in focusMode
        XCTAssertEqual(stateMachine.currentState.name, "focusMode")
        // Should not create a new transition
        XCTAssertEqual(receivedTransitions.count, transitionCountBefore)
    }

    // MARK: - State Update Tests

    func testUpdateTimeInCountingState() {
        stateMachine.transitionToCounting(timeSpent: 10.0)
        let transitionCountBefore = receivedTransitions.count

        // Update time - updateTime silently updates without creating transitions
        stateMachine.updateTime(timeSpent: 20.0)

        // Should update the time value
        if case .counting(let time) = stateMachine.currentState {
            XCTAssertEqual(time, 20.0, accuracy: 0.01)
        } else {
            XCTFail("State should be counting with updated time")
        }

        // Should not create new transitions (updateTime is silent)
        XCTAssertEqual(receivedTransitions.count, transitionCountBefore)

        // Update again
        stateMachine.updateTime(timeSpent: 30.0)
        if case .counting(let time) = stateMachine.currentState {
            XCTAssertEqual(time, 30.0, accuracy: 0.01)
        } else {
            XCTFail("State should be counting with updated time")
        }
    }

    func testUpdateTimeInFocusModeState() {
        stateMachine.transitionToCounting(timeSpent: 0.0)
        stateMachine.transitionToFocusMode(timeSpent: 720.0)

        stateMachine.updateTime(timeSpent: 800.0)

        if case .focusMode(let time) = stateMachine.currentState {
            XCTAssertEqual(time, 800.0, accuracy: 0.01)
        } else {
            XCTFail("State should be focusMode with updated time")
        }
    }

    func testUpdateTimeInIdleState() {
        // Should not update time in idle state
        stateMachine.updateTime(timeSpent: 100.0)
        XCTAssertEqual(stateMachine.currentState, .idle)
    }

    func testUpdateBufferTime() {
        stateMachine.transitionToCounting(timeSpent: 0.0)
        stateMachine.transitionToFocusMode(timeSpent: 720.0)
        stateMachine.transitionToBuffer(timeRemaining: 120.0)

        stateMachine.updateBufferTime(timeRemaining: 60.0)

        if case .buffer(let remaining) = stateMachine.currentState {
            XCTAssertEqual(remaining, 60.0, accuracy: 0.01)
        } else {
            XCTFail("State should be buffer with updated time")
        }
    }

    func testUpdateBufferTimeWhenNotInBuffer() {
        stateMachine.transitionToCounting(timeSpent: 10.0)

        // Should not update if not in buffer state
        stateMachine.updateBufferTime(timeRemaining: 60.0)

        XCTAssertEqual(stateMachine.currentState.name, "counting")
    }

    // MARK: - Same State Transition Tests

    func testSameStateTransitionWithDifferentValues() {
        stateMachine.transitionToCounting(timeSpent: 10.0)
        let transitionCountBefore = receivedTransitions.count

        // Transition to counting again with different time
        stateMachine.transitionToCounting(timeSpent: 20.0)

        // Should create a new transition (counting has associated values)
        XCTAssertEqual(receivedTransitions.count, transitionCountBefore + 1)
        XCTAssertEqual(stateMachine.currentState.name, "counting")
    }

    func testSameStateTransitionToIdle() {
        // Transitioning to idle when already idle should not create transition
        let transitionCountBefore = receivedTransitions.count
        stateMachine.transitionToIdle()

        XCTAssertEqual(receivedTransitions.count, transitionCountBefore)
    }

    // MARK: - Transition History Tests

    func testTransitionHistoryIsRecorded() {
        stateMachine.transitionToCounting(timeSpent: 0.0)
        stateMachine.transitionToFocusMode(timeSpent: 720.0)
        stateMachine.transitionToBuffer(timeRemaining: 120.0)

        let recentTransitions = stateMachine.getRecentTransitions(count: 10)
        XCTAssertEqual(recentTransitions.count, 3)
        XCTAssertEqual(recentTransitions[0].from.name, "idle")
        XCTAssertEqual(recentTransitions[0].to.name, "counting")
        XCTAssertEqual(recentTransitions[1].to.name, "focusMode")
        XCTAssertEqual(recentTransitions[2].to.name, "buffer")
    }

    func testTransitionHistoryLimit() {
        // Create more than maxHistorySize transitions
        for i in 0..<150 {
            if i % 2 == 0 {
                stateMachine.transitionToCounting(timeSpent: Double(i))
            } else {
                stateMachine.transitionToIdle()
            }
        }

        let recentTransitions = stateMachine.getRecentTransitions(count: 10)
        // Should only return the last 10
        XCTAssertEqual(recentTransitions.count, 10)
    }

    // MARK: - Reset Tests

    func testReset() {
        stateMachine.transitionToCounting(timeSpent: 0.0)
        stateMachine.transitionToFocusMode(timeSpent: 720.0)
        stateMachine.transitionToBuffer(timeRemaining: 120.0)

        stateMachine.reset()

        XCTAssertEqual(stateMachine.currentState, .idle)
        XCTAssertEqual(stateMachine.getRecentTransitions().count, 0)
    }

    // MARK: - State Properties Tests

    func testIsFocusModeActive() {
        XCTAssertFalse(stateMachine.currentState.isFocusModeActive)

        stateMachine.transitionToCounting(timeSpent: 0.0)
        XCTAssertFalse(stateMachine.currentState.isFocusModeActive)

        stateMachine.transitionToFocusMode(timeSpent: 720.0)
        XCTAssertTrue(stateMachine.currentState.isFocusModeActive)

        stateMachine.transitionToBuffer(timeRemaining: 120.0)
        XCTAssertFalse(stateMachine.currentState.isFocusModeActive)
    }

    func testIsTracking() {
        XCTAssertFalse(stateMachine.currentState.isTracking)

        stateMachine.transitionToCounting(timeSpent: 0.0)
        XCTAssertTrue(stateMachine.currentState.isTracking)

        stateMachine.transitionToFocusMode(timeSpent: 720.0)
        XCTAssertTrue(stateMachine.currentState.isTracking)

        stateMachine.transitionToBuffer(timeRemaining: 120.0)
        XCTAssertFalse(stateMachine.currentState.isTracking)

        stateMachine.transitionToIdle()
        XCTAssertFalse(stateMachine.currentState.isTracking)
    }

    // MARK: - Real-World Flow Tests

    func testCompleteFocusSessionFlow() {
        // Start: idle
        XCTAssertEqual(stateMachine.currentState, .idle)

        // User opens focus app: idle → counting
        stateMachine.transitionToCounting(timeSpent: 0.0)
        XCTAssertEqual(stateMachine.currentState.name, "counting")

        // Timer reaches threshold: counting → focusMode
        stateMachine.transitionToFocusMode(timeSpent: 720.0)
        XCTAssertEqual(stateMachine.currentState.name, "focusMode")
        XCTAssertTrue(stateMachine.currentState.isFocusModeActive)

        // User switches away: focusMode → buffer
        stateMachine.transitionToBuffer(timeRemaining: 120.0)
        XCTAssertEqual(stateMachine.currentState.name, "buffer")
        XCTAssertFalse(stateMachine.currentState.isFocusModeActive)

        // Buffer times out: buffer → idle
        stateMachine.transitionToIdle()
        XCTAssertEqual(stateMachine.currentState, .idle)
    }

    func testUserReturnsDuringBuffer() {
        // Start focus session
        stateMachine.transitionToCounting(timeSpent: 0.0)
        stateMachine.transitionToFocusMode(timeSpent: 720.0)
        stateMachine.transitionToBuffer(timeRemaining: 120.0)

        // User returns to focus app: buffer → counting (preserving time)
        stateMachine.transitionToCounting(timeSpent: 720.0)
        XCTAssertEqual(stateMachine.currentState.name, "counting")
        XCTAssertTrue(stateMachine.currentState.isTracking)

        // Back to focus mode
        stateMachine.transitionToFocusMode(timeSpent: 800.0)
        XCTAssertEqual(stateMachine.currentState.name, "focusMode")
    }

    func testUserLeavesBeforeThreshold() {
        // Start counting
        stateMachine.transitionToCounting(timeSpent: 100.0)

        // User leaves before threshold: counting → idle
        stateMachine.transitionToIdle()
        XCTAssertEqual(stateMachine.currentState, .idle)
        XCTAssertFalse(stateMachine.currentState.isTracking)
    }
}


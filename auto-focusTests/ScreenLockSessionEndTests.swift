@testable import auto_focus
import XCTest

#if DEBUG

final class ScreenLockSessionEndTests: XCTestCase {
    var focusManager: FocusManager!
    var mockSessionManager: MockSessionManager!
    var mockAppMonitor: MockAppMonitor!
    var mockBufferManager: MockBufferManager!
    var mockFocusModeManager: MockFocusModeManager!

    override func setUp() {
        super.setUp()
        let mocks = MockFactory.createMockDependencies()
        mockSessionManager = mocks.sessionManager
        mockAppMonitor = mocks.appMonitor
        mockBufferManager = mocks.bufferManager
        mockFocusModeManager = mocks.focusModeManager
        focusManager = MockFactory.createFocusManager(
            sessionManager: mockSessionManager,
            appMonitor: mockAppMonitor,
            bufferManager: mockBufferManager,
            focusModeManager: mockFocusModeManager
        )
    }

    func testScreenLockEndsSessionWhenThresholdReached() {
        mockSessionManager.startSession()
        focusManager.isFocusAppActive = true
        focusManager.isInFocusMode = true
        focusManager.didReachFocusThreshold = true
        focusManager.timeSpent = 600

        focusManager.handleScreenInactive()

        XCTAssertEqual(mockSessionManager.focusSessions.count, 1, "Session should be saved when threshold was reached")
        XCTAssertFalse(focusManager.isFocusAppActive)
        XCTAssertFalse(focusManager.isInFocusMode)
        XCTAssertFalse(focusManager.didReachFocusThreshold)
        XCTAssertEqual(focusManager.timeSpent, 0)
    }

    func testScreenLockDiscardsPreThresholdSession() {
        mockSessionManager.startSession()
        focusManager.isFocusAppActive = true
        focusManager.didReachFocusThreshold = false
        focusManager.timeSpent = 5

        focusManager.handleScreenInactive()

        XCTAssertEqual(mockSessionManager.focusSessions.count, 0, "Pre-threshold session should be discarded")
        XCTAssertFalse(focusManager.isFocusAppActive)
        XCTAssertEqual(focusManager.timeSpent, 0)
    }

    func testScreenLockCancelsActiveBuffer() {
        focusManager.isFocusAppActive = true
        focusManager.didReachFocusThreshold = true
        mockBufferManager.startBuffer(duration: 60)
        XCTAssertTrue(mockBufferManager.isInBufferPeriod)

        focusManager.handleScreenInactive()

        XCTAssertFalse(mockBufferManager.isInBufferPeriod, "Buffer should be cancelled on lock")
        XCTAssertEqual(mockSessionManager.focusSessions.count, 1, "Session should still be saved when threshold was reached")
    }

    func testScreenLockNoOpWhenPaused() {
        focusManager.isPaused = true
        focusManager.isFocusAppActive = true
        focusManager.didReachFocusThreshold = true

        focusManager.handleScreenInactive()

        XCTAssertEqual(mockSessionManager.focusSessions.count, 0)
    }

    func testScreenLockResetsAppMonitorStateSoTimerCanRestartAfterUnlock() {
        focusManager.isFocusAppActive = true
        focusManager.didReachFocusThreshold = true
        focusManager.timeSpent = 600
        let resetsBefore = mockAppMonitor.resetStateCallCount

        focusManager.handleScreenInactive()

        XCTAssertEqual(
            mockAppMonitor.resetStateCallCount,
            resetsBefore + 1,
            "AppMonitor.resetState() must be called so its lastFocusAppActive flips to false; otherwise the next tick after unlock won't fire didDetectFocusApp and the timer won't restart"
        )
    }
}

#endif

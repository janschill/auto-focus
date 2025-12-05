// FocusManagerStateTests.swift
// Unit tests for FocusManager state management after refactor

@testable import auto_focus
import XCTest

#if DEBUG

final class FocusManagerStateTests: XCTestCase {
    var focusManager: FocusManager!
    var mockPersistence: MockPersistenceManager!
    var mockSessionManager: MockSessionManager!
    var mockAppMonitor: MockAppMonitor!
    var mockBufferManager: MockBufferManager!
    var mockFocusModeManager: MockFocusModeManager!

    override func setUp() {
        super.setUp()
        mockPersistence = MockPersistenceManager()
        mockSessionManager = MockSessionManager()
        mockAppMonitor = MockAppMonitor()
        mockBufferManager = MockBufferManager()
        mockFocusModeManager = MockFocusModeManager()
        focusManager = FocusManager(
            userDefaultsManager: mockPersistence,
            sessionManager: mockSessionManager,
            appMonitor: mockAppMonitor,
            bufferManager: mockBufferManager,
            focusModeController: mockFocusModeManager
        )
    }

    func testPauseToggle() {
        let initialPauseState = focusManager.isPaused
        focusManager.togglePause()
        XCTAssertEqual(focusManager.isPaused, !initialPauseState)
    }

    func testShortcutStatusCached() {
        // Test cached property is updated via refreshShortcutStatus()
        // Initial state depends on mock setup during init
        mockFocusModeManager.shouldFailShortcutCheck = false

        // refreshShortcutStatus() runs async, so we need to wait
        let expectation = expectation(description: "Shortcut status updated")
        focusManager.refreshShortcutStatus()

        // Wait a bit for async update to complete
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            XCTAssertTrue(self.focusManager.isShortcutInstalled)

            // Now test when shortcut doesn't exist
            self.mockFocusModeManager.shouldFailShortcutCheck = true
            self.focusManager.refreshShortcutStatus()

            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                XCTAssertFalse(self.focusManager.isShortcutInstalled)
                expectation.fulfill()
            }
        }

        wait(for: [expectation], timeout: 1.0)
    }

    func testFocusThresholdPersistence() {
        focusManager.focusThreshold = 15
        XCTAssertEqual(mockPersistence.getDouble(forKey: UserDefaultsManager.Keys.focusThreshold), 15)
    }
}

#endif

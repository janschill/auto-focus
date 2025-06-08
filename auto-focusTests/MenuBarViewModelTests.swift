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

    func testShortcutStatusComputed() {
        // Test computed property returns correct value
        mockFocusModeManager.shouldFailShortcutCheck = false
        XCTAssertTrue(focusManager.isShortcutInstalled)

        mockFocusModeManager.shouldFailShortcutCheck = true
        focusManager.refreshShortcutStatus()
        XCTAssertFalse(focusManager.isShortcutInstalled)
    }

    func testFocusThresholdPersistence() {
        focusManager.focusThreshold = 15
        XCTAssertEqual(mockPersistence.getDouble(forKey: UserDefaultsManager.Keys.focusThreshold), 15)
    }
}

#endif

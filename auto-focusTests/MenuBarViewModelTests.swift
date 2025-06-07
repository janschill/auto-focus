// MenuBarViewModelTests.swift
// Unit tests for MenuBarViewModel

@testable import auto_focus
import XCTest

#if DEBUG

final class MenuBarViewModelTests: XCTestCase {
    var focusManager: FocusManager!
    var viewModel: MenuBarViewModel!
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
        viewModel = MenuBarViewModel(focusManager: focusManager)
    }

    func testPauseSync() {
        viewModel.togglePause()
        XCTAssertEqual(viewModel.isPaused, focusManager.isPaused)
    }
}

#endif

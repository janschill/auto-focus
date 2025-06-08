// ConfigurationViewModelTests.swift
// Unit tests for ConfigurationViewModel

@testable import auto_focus
import XCTest

#if DEBUG

final class ConfigurationViewModelTests: XCTestCase {
    var focusManager: FocusManager!
    var viewModel: ConfigurationViewModel!
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
        viewModel = ConfigurationViewModel(focusManager: focusManager)
    }

    func testShortcutStatusInitialization() {
        // Test that ConfigurationViewModel properly initializes shortcut status
        XCTAssertNotNil(viewModel.shortcutInstalled)

        // Test that refreshing shortcut status calls the focus manager
        mockFocusModeManager.shouldFailShortcutCheck = false
        viewModel.updateShortcutInstalled()

        // Verify the shortcut status is properly retrieved
        XCTAssertTrue(viewModel.shortcutInstalled)
    }

    func testShortcutStatusWithFailure() {
        // Test behavior when shortcut check fails
        mockFocusModeManager.shouldFailShortcutCheck = true
        viewModel.updateShortcutInstalled()

        XCTAssertFalse(viewModel.shortcutInstalled)
    }
}

#endif

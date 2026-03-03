// ConfigurationViewModelTests.swift
// Unit tests for ConfigurationViewModel

@testable import auto_focus
import XCTest

#if DEBUG

final class ConfigurationViewModelTests: XCTestCase {
    var focusManager: FocusManager!
    var viewModel: ConfigurationViewModel!
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
        viewModel = ConfigurationViewModel(focusManager: focusManager)
    }

    func testShortcutStatusInitialization() {
        // Test that ConfigurationViewModel properly initializes shortcut status
        XCTAssertNotNil(viewModel.shortcutInstalled)

        // refreshShortcutStatus is async — set mock to succeed then wait for update
        mockFocusModeManager.shouldFailShortcutCheck = false
        viewModel.updateShortcutInstalled()

        let expectation = expectation(description: "Shortcut status updated")
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
            // Re-read after async update completes
            self.viewModel.updateShortcutInstalled()
            expectation.fulfill()
        }
        wait(for: [expectation], timeout: 1.0)

        XCTAssertTrue(focusManager.isShortcutInstalled)
    }

    func testShortcutStatusWithFailure() {
        // Test behavior when shortcut check fails
        mockFocusModeManager.shouldFailShortcutCheck = true
        viewModel.updateShortcutInstalled()

        XCTAssertFalse(viewModel.shortcutInstalled)
    }
}

#endif

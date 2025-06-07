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

    func testThresholdSync() {
        focusManager.focusThreshold = 10
        viewModel.setFocusThreshold(15)
        XCTAssertEqual(focusManager.focusThreshold, 15)
        focusManager.focusLossBuffer = 5
        viewModel.setFocusLossBuffer(7)
        XCTAssertEqual(focusManager.focusLossBuffer, 7)
    }
}

#endif

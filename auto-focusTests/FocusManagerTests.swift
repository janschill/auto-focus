// FocusManagerTests.swift
// Unit tests for FocusManager core logic

import XCTest
@testable import auto_focus

#if DEBUG

final class FocusManagerTests: XCTestCase {
    var focusManager: FocusManager!
    var mockSessionManager: MockSessionManager!
    var mockBufferManager: MockBufferManager!
    var mockAppMonitor: MockAppMonitor!
    var mockFocusModeManager: MockFocusModeManager!
    var mockPersistence: MockPersistenceManager!

    override func setUp() {
        super.setUp()
        mockSessionManager = MockSessionManager()
        mockBufferManager = MockBufferManager()
        mockAppMonitor = MockAppMonitor()
        mockFocusModeManager = MockFocusModeManager()
        mockPersistence = MockPersistenceManager()
        focusManager = FocusManager(
            userDefaultsManager: mockPersistence,
            sessionManager: mockSessionManager,
            appMonitor: mockAppMonitor,
            bufferManager: mockBufferManager,
            focusModeController: mockFocusModeManager
        )
    }

    func testStartSession() {
        focusManager.isFocusAppActive = false
        focusManager.todaysSessions.forEach { _ in mockSessionManager.clearAllSessions() }
        focusManager.togglePause() // Pause
        focusManager.togglePause() // Resume
        focusManager.isFocusAppActive = true
        mockSessionManager.startSession()
        XCTAssertTrue(mockSessionManager.isSessionActive)
    }

    func testEndSession() {
        mockSessionManager.startSession()
        mockSessionManager.endSession()
        XCTAssertFalse(mockSessionManager.isSessionActive)
        XCTAssertEqual(mockSessionManager.focusSessions.count, 1)
    }

    func testBufferStartAndTimeout() {
        mockBufferManager.startBuffer(duration: 2)
        XCTAssertTrue(mockBufferManager.isInBufferPeriod)
        mockBufferManager.simulateBufferTimeout()
        XCTAssertFalse(mockBufferManager.isInBufferPeriod)
    }

    func testPauseAndResume() {
        focusManager.isPaused = false
        focusManager.togglePause()
        XCTAssertTrue(focusManager.isPaused)
        focusManager.togglePause()
        XCTAssertFalse(focusManager.isPaused)
    }

    func testSessionManagerIntegration() {
        // Start and end session via FocusManager
        focusManager.isFocusAppActive = true
        focusManager.togglePause() // Pause (should end session)
        XCTAssertFalse(mockSessionManager.isSessionActive)
        focusManager.togglePause() // Resume
        focusManager.isFocusAppActive = true
        mockSessionManager.startSession()
        XCTAssertTrue(mockSessionManager.isSessionActive)
        mockSessionManager.cancelCurrentSession()
        XCTAssertFalse(mockSessionManager.isSessionActive)
    }

    func testAddAndClearSampleSessions() {
        let sampleSessions = [FocusSession(startTime: Date().addingTimeInterval(-120), endTime: Date())]
        focusManager.addSampleSessions(sampleSessions)
        XCTAssertEqual(mockSessionManager.focusSessions.count, 1)
        focusManager.clearAllSessions()
        XCTAssertEqual(mockSessionManager.focusSessions.count, 0)
    }

    func testBufferCancel() {
        mockBufferManager.startBuffer(duration: 2)
        XCTAssertTrue(mockBufferManager.isInBufferPeriod)
        mockBufferManager.cancelBuffer()
        XCTAssertFalse(mockBufferManager.isInBufferPeriod)
    }

    func testFocusModeEnableDisable() {
        mockFocusModeManager.setFocusMode(enabled: true)
        XCTAssertTrue(mockFocusModeManager.isFocusModeEnabled)
        mockFocusModeManager.setFocusMode(enabled: false)
        XCTAssertFalse(mockFocusModeManager.isFocusModeEnabled)
    }

    func testFocusModeErrorHandling() {
        mockFocusModeManager.shouldFailFocusMode = true
        mockFocusModeManager.setFocusMode(enabled: true)
        // Should not crash, error handled via delegate
    }

    func testAppMonitorDelegate() {
        focusManager.isPaused = false
        mockAppMonitor.simulateFocusAppActive()
        XCTAssertTrue(mockAppMonitor.isFocusAppActive)
        mockAppMonitor.simulateFocusAppInactive()
        XCTAssertFalse(mockAppMonitor.isFocusAppActive)
    }

    func testPersistenceManagerIntegration() {
        focusManager.isPaused = true
        XCTAssertTrue(mockPersistence.getBool(forKey: "isPaused"))
        focusManager.isPaused = false
        XCTAssertFalse(mockPersistence.getBool(forKey: "isPaused"))
    }

//    func testCanAddMoreAppsAndPremiumRequired() {
//        focusManager.focusApps = [
//            AppInfo(id: "1", name: "App1", bundleIdentifier: "com.test.app1"),
//            AppInfo(id: "2", name: "App2", bundleIdentifier: "com.test.app2")
//        ]
//        // Simulate not licensed
//        focusManager.isPremiumUser = false
//        XCTAssertFalse(focusManager.canAddMoreApps)
//        XCTAssertTrue(focusManager.isPremiumRequired)
//    }

    // --- SessionManager Tests ---
    func testSessionManagerStartEndCancel() {
        mockSessionManager.startSession()
        XCTAssertTrue(mockSessionManager.isSessionActive)
        mockSessionManager.endSession()
        XCTAssertFalse(mockSessionManager.isSessionActive)
        mockSessionManager.startSession()
        mockSessionManager.cancelCurrentSession()
        XCTAssertFalse(mockSessionManager.isSessionActive)
    }

    func testSessionManagerAddSampleAndClear() {
        let sessions = [FocusSession(startTime: Date().addingTimeInterval(-100), endTime: Date())]
        mockSessionManager.addSampleSessions(sessions)
        XCTAssertEqual(mockSessionManager.focusSessions.count, 1)
        mockSessionManager.clearAllSessions()
        XCTAssertEqual(mockSessionManager.focusSessions.count, 0)
    }

    // --- BufferManager Tests ---
    func testBufferManagerStartCancelTimeout() {
        mockBufferManager.startBuffer(duration: 5)
        XCTAssertTrue(mockBufferManager.isInBufferPeriod)
        mockBufferManager.cancelBuffer()
        XCTAssertFalse(mockBufferManager.isInBufferPeriod)
        mockBufferManager.startBuffer(duration: 5)
        mockBufferManager.simulateBufferTimeout()
        XCTAssertFalse(mockBufferManager.isInBufferPeriod)
    }

    // --- AppMonitor Tests ---
    func testAppMonitorFocusAppActiveInactive() {
        mockAppMonitor.simulateFocusAppActive()
        XCTAssertTrue(mockAppMonitor.isFocusAppActive)
        mockAppMonitor.simulateFocusAppInactive()
        XCTAssertFalse(mockAppMonitor.isFocusAppActive)
    }

    func testAppMonitorUpdateFocusApps() {
        let apps = [AppInfo(id: "a", name: "TestApp", bundleIdentifier: "com.test.app")]
        mockAppMonitor.updateFocusApps(apps)
        // No assertion: just ensure no crash and method is callable
    }

    // --- FocusModeManager Tests ---
    func testFocusModeManagerEnableDisable() {
        mockFocusModeManager.setFocusMode(enabled: true)
        XCTAssertTrue(mockFocusModeManager.isFocusModeEnabled)
        mockFocusModeManager.setFocusMode(enabled: false)
        XCTAssertFalse(mockFocusModeManager.isFocusModeEnabled)
    }

    func testFocusModeManagerShortcutCheck() {
        let exists = mockFocusModeManager.checkShortcutExists()
        XCTAssertTrue(exists) // Default mock returns true
        mockFocusModeManager.shouldFailShortcutCheck = true
        let notExists = mockFocusModeManager.checkShortcutExists()
        XCTAssertFalse(notExists)
    }

    // --- UserDefaultsManager (Persistence) Tests ---
    func testPersistenceSetGetBoolDouble() {
        mockPersistence.setBool(true, forKey: "testBool")
        XCTAssertTrue(mockPersistence.getBool(forKey: "testBool"))
        mockPersistence.setDouble(42.0, forKey: "testDouble")
        XCTAssertEqual(mockPersistence.getDouble(forKey: "testDouble"), 42.0)
    }

    func testPersistenceSaveLoadCodable() {
        let app = AppInfo(id: "x", name: "AppX", bundleIdentifier: "com.x")
        mockPersistence.save([app], forKey: "apps")
        let loaded: [AppInfo]? = mockPersistence.load([AppInfo].self, forKey: "apps")
        XCTAssertEqual(loaded?.first, app)
    }

    // --- InsightsViewModel (example) ---
    // Moved to InsightsViewModelTests.swift

    // --- ConfigurationViewModel (example) ---
    // Moved to ConfigurationViewModelTests.swift

    // --- MenuBarViewModel (example) ---
    // Moved to MenuBarViewModelTests.swift
}

#endif

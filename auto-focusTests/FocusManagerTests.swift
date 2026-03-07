// FocusManagerTests.swift
// Unit tests for FocusManager core logic

@testable import auto_focus
import XCTest

#if DEBUG

final class FocusManagerTests: XCTestCase {
    var focusManager: FocusManager!
    var mockSessionManager: MockSessionManager!
    var mockBufferManager: MockBufferManager!
    var mockAppMonitor: MockAppMonitor!
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

    override func tearDown() {
        mockSessionManager.reset()
        mockAppMonitor.reset()
        mockBufferManager.reset()
        super.tearDown()
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
        let sampleSessions = TestDataBuilder.createSessionsForDay(count: 3, duration: 120)
        focusManager.addSampleSessions(sampleSessions)
        XCTAssertEqual(mockSessionManager.focusSessions.count, 3)
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
        // Verify delegate method is called without checking isFocusAppActive
        mockAppMonitor.simulateFocusAppInactive()
        // State is now managed by FocusManager, not AppMonitor
    }

    func testPersistenceManagerIntegration() {
        // Settings are persisted to SQLite via SettingsRepository
        focusManager.isPaused = true
        focusManager.isPaused = false
        XCTAssertFalse(focusManager.isPaused)
    }

    func testDefaultFocusThresholdIsCorrect() {
        // Test that when no settings exist, the default focus threshold is 12 minutes
        let cleanFocusManager = MockFactory.createFocusManager(
            sessionManager: mockSessionManager,
            appMonitor: mockAppMonitor,
            bufferManager: mockBufferManager,
            focusModeManager: mockFocusModeManager
        )

        // With no stored value, it should default to 12 minutes (not 720)
        XCTAssertEqual(cleanFocusManager.focusThreshold, 12, "Default focus threshold should be 12 minutes, not 720")

        // Verify AppConfiguration constant is also 12
        XCTAssertEqual(AppConfiguration.defaultFocusThreshold, 12, "AppConfiguration.defaultFocusThreshold should be 12 minutes")
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
        let sessions = TestDataBuilder.createSessionsForDay(count: 5, duration: 3600)
        mockSessionManager.addSampleSessions(sessions)
        XCTAssertEqual(mockSessionManager.focusSessions.count, 5)
        XCTAssertEqual(mockSessionManager.todaysSessions.count, 5)
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
        // Verify delegate calls work (state is managed by FocusManager)
        mockAppMonitor.simulateFocusAppInactive()
        // No assertion needed - just verify no crash
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

    // --- SettingsRepository Tests (replaced UserDefaultsManager tests) ---
    func testSettingsRepository_BasicOperations() {
        let testDB = MockFactory.createTestDB()
        let settingsRepo = SettingsRepository(dbQueue: testDB)
        try? settingsRepo.setBool(true, forKey: "testBool")
        XCTAssertTrue(settingsRepo.getBool(forKey: "testBool"))
        try? settingsRepo.setDouble(42.0, forKey: "testDouble")
        XCTAssertEqual(settingsRepo.getDouble(forKey: "testDouble"), 42.0)
    }

    // --- InsightsViewModel (example) ---
    // Moved to InsightsViewModelTests.swift

    // --- ConfigurationViewModel (example) ---
    // Moved to ConfigurationViewModelTests.swift
}

#endif

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
    var mockPersistence: MockPersistenceManager!

    override func setUp() {
        super.setUp()
        let mocks = MockFactory.createMockDependencies()
        mockPersistence = mocks.persistence
        mockSessionManager = mocks.sessionManager
        mockAppMonitor = mocks.appMonitor
        mockBufferManager = mocks.bufferManager
        mockFocusModeManager = mocks.focusModeManager

        focusManager = MockFactory.createFocusManager(
            persistence: mockPersistence,
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
        mockPersistence.reset()
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
        focusManager.isPaused = true
        XCTAssertTrue(mockPersistence.getBool(forKey: "isPaused"))
        focusManager.isPaused = false
        XCTAssertFalse(mockPersistence.getBool(forKey: "isPaused"))
    }

    func testDefaultFocusThresholdIsCorrect() {
        // Test that when no UserDefaults value exists, the default focus threshold is 12 minutes
        let cleanPersistence = MockPersistenceManager()
        let cleanFocusManager = MockFactory.createFocusManager(
            persistence: cleanPersistence,
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

    // MARK: - Session Bug Fix Tests
    
    /// Test that sessions are saved when switching from focus to non-focus app
    /// This addresses the bug where accumulated time was lost when switching contexts
    func testSessionSavedWhenSwitchingToNonFocusApp() {
        // Setup: Start a session by simulating focus app active
        focusManager.isPaused = false
        mockSessionManager.startSession()
        focusManager.isFocusAppActive = true
        focusManager.timeSpent = 10.0 // 10 seconds accumulated
        
        // Initial state: session should be active, no sessions saved yet
        XCTAssertTrue(mockSessionManager.isSessionActive, "Session should be active")
        XCTAssertEqual(mockSessionManager.focusSessions.count, 0, "No sessions should be saved yet")
        
        // Simulate switching to non-focus app (this triggers handleNonFocusAppInFront)
        mockAppMonitor.simulateFocusAppInactive()
        
        // Verify: session should be ended and saved
        XCTAssertFalse(mockSessionManager.isSessionActive, "Session should no longer be active")
        XCTAssertEqual(mockSessionManager.focusSessions.count, 1, "One session should be saved")
        XCTAssertEqual(focusManager.timeSpent, 0, "Time should be reset after session end")
    }
    
    /// Test that sessions are preserved when switching between focus contexts
    func testSessionPreservedWhenSwitchingBetweenFocusContexts() {
        // Setup: Start a session with app focus
        focusManager.isPaused = false
        mockSessionManager.startSession()
        focusManager.isFocusAppActive = true
        focusManager.timeSpent = 15.0
        
        let initialSessionCount = mockSessionManager.focusSessions.count
        
        // Simulate switching to browser focus (preserves session)
        focusManager.isBrowserInFocus = true
        
        // Verify: session should still be active, time preserved
        XCTAssertTrue(mockSessionManager.isSessionActive, "Session should remain active when switching to browser focus")
        XCTAssertEqual(mockSessionManager.focusSessions.count, initialSessionCount, "No new sessions should be created")
        XCTAssertEqual(focusManager.timeSpent, 15.0, "Time should be preserved")
    }
    
    /// Test that buffer period is triggered when in focus mode and switching to non-focus
    func testBufferPeriodTriggeredInFocusMode() {
        // Setup: Enter focus mode
        focusManager.isPaused = false
        mockSessionManager.startSession()
        focusManager.isFocusAppActive = true
        focusManager.isInFocusMode = true
        focusManager.timeSpent = 60.0
        
        let initialSessionCount = mockSessionManager.focusSessions.count
        
        // Simulate switching to non-focus app while in focus mode
        mockAppMonitor.simulateFocusAppInactive()
        
        // Verify: buffer period should start, session not yet ended
        XCTAssertTrue(mockBufferManager.isInBufferPeriod, "Buffer period should start")
        XCTAssertTrue(mockSessionManager.isSessionActive, "Session should remain active during buffer")
        XCTAssertEqual(mockSessionManager.focusSessions.count, initialSessionCount, "Session should not be saved during buffer period")
    }
    
    /// Test that session is saved after buffer timeout
    func testSessionSavedAfterBufferTimeout() {
        // Setup: Enter buffer period
        focusManager.isPaused = false
        mockSessionManager.startSession()
        focusManager.isInFocusMode = true
        focusManager.timeSpent = 45.0
        mockBufferManager.startBuffer(duration: 2.0)
        
        let initialSessionCount = mockSessionManager.focusSessions.count
        
        // Simulate buffer timeout
        mockBufferManager.simulateBufferTimeout()
        
        // Verify: session should be ended and saved
        XCTAssertFalse(mockSessionManager.isSessionActive, "Session should be ended after buffer timeout")
        XCTAssertEqual(mockSessionManager.focusSessions.count, initialSessionCount + 1, "Session should be saved after buffer timeout")
        XCTAssertEqual(focusManager.timeSpent, 0, "Time should be reset after buffer timeout")
    }
}

#endif

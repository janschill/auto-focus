// PauseAndBrowserHandoffTests.swift
// Pausing must stop all focus tracking, and the focus app → browser hand-off
// is decided by the browser's first poll result rather than a fixed delay.

@testable import auto_focus
import Combine
import XCTest

#if DEBUG

final class PauseAndBrowserHandoffTests: XCTestCase {
    private let browserBundleId = "com.google.Chrome"
    private let focusAppBundleId = "com.test.focusapp"

    private var focusManager: FocusManager!
    private var sessionManager: MockSessionManager!
    private var appMonitor: MockAppMonitor!
    private var bufferManager: MockBufferManager!
    private var browserManager: MockBrowserManager!

    override func setUp() {
        super.setUp()
        let mocks = MockFactory.createMockDependencies()
        sessionManager = mocks.sessionManager
        appMonitor = mocks.appMonitor
        bufferManager = mocks.bufferManager
        browserManager = mocks.browserManager

        focusManager = MockFactory.createFocusManager(
            sessionManager: sessionManager,
            appMonitor: appMonitor,
            bufferManager: bufferManager,
            focusModeManager: mocks.focusModeManager,
            browserManager: browserManager
        )
        focusManager.focusApps = [
            AppInfo(id: "1", name: "TestApp", bundleIdentifier: focusAppBundleId)
        ]
    }

    override func tearDown() {
        focusManager = nil
        super.tearDown()
    }

    private func switchTo(_ bundleId: String, isFocusApp: Bool) {
        let wasFocusApp = appMonitor.currentApp == focusAppBundleId
        appMonitor.currentApp = bundleId
        focusManager.appMonitor(appMonitor, didChangeToApp: bundleId)
        if isFocusApp != wasFocusApp {
            focusManager.appMonitor(appMonitor, didDetectFocusApp: isFocusApp)
        }
    }

    // MARK: - Pause

    func testPauseDuringBrowserFocusEndsFocusAndStopsPolling() {
        switchTo(browserBundleId, isFocusApp: false)
        browserManager.simulateBrowserFocusActivated()
        focusManager.timeSpent = 5
        XCTAssertTrue(browserManager.isPolling)
        XCTAssertTrue(focusManager.isBrowserInFocus)

        focusManager.togglePause()

        XCTAssertFalse(browserManager.isPolling)
        XCTAssertFalse(focusManager.isBrowserInFocus)
        XCTAssertEqual(focusManager.timeSpent, 0)
        XCTAssertFalse(sessionManager.isSessionActive)
    }

    func testPauseDuringBufferCancelsBuffer() {
        switchTo(focusAppBundleId, isFocusApp: true)
        focusManager.timeSpent = 5
        switchTo("com.test.other", isFocusApp: false)
        XCTAssertTrue(bufferManager.isInBufferPeriod)

        focusManager.togglePause()

        XCTAssertFalse(bufferManager.isInBufferPeriod)
        XCTAssertEqual(focusManager.timeSpent, 0)
    }

    func testBrowserFocusIsIgnoredWhilePaused() {
        focusManager.togglePause()

        browserManager.simulateBrowserFocusActivated()

        XCTAssertFalse(focusManager.isBrowserInFocus)
        XCTAssertFalse(sessionManager.isSessionActive)
    }

    // MARK: - Focus app → browser hand-off

    func testHandoffWaitsForFirstBrowserResult() {
        switchTo(focusAppBundleId, isFocusApp: true)
        focusManager.timeSpent = 5

        switchTo(browserBundleId, isFocusApp: false)

        XCTAssertTrue(browserManager.isPolling)
        XCTAssertFalse(focusManager.isFocusAppActive)
        XCTAssertEqual(bufferManager.bufferStartCount, 0, "No buffer before the browser reports")
        XCTAssertEqual(focusManager.timeSpent, 5)
    }

    func testHandoffToFocusURLContinuesWithoutBuffer() {
        switchTo(focusAppBundleId, isFocusApp: true)
        focusManager.timeSpent = 5
        switchTo(browserBundleId, isFocusApp: false)

        browserManager.simulateBrowserFocusActivated()

        XCTAssertTrue(focusManager.isBrowserInFocus)
        XCTAssertTrue(focusManager.isInOverallFocus)
        XCTAssertEqual(bufferManager.bufferStartCount, 0)
    }

    func testHandoffToNonFocusURLStartsPreSessionBuffer() {
        switchTo(focusAppBundleId, isFocusApp: true)
        focusManager.timeSpent = 5
        switchTo(browserBundleId, isFocusApp: false)

        browserManager.simulateBrowserFocusDeactivated()

        XCTAssertEqual(bufferManager.bufferStartCount, 1)
        XCTAssertEqual(bufferManager.lastStartedBufferDuration, AppConfiguration.preSessionBuffer)
    }

    func testReturningToFocusAppBeforeBrowserResultKeepsTime() {
        switchTo(focusAppBundleId, isFocusApp: true)
        focusManager.timeSpent = 5
        switchTo(browserBundleId, isFocusApp: false)

        switchTo(focusAppBundleId, isFocusApp: true)

        XCTAssertFalse(browserManager.isPolling)
        XCTAssertTrue(focusManager.isFocusAppActive)
        XCTAssertEqual(bufferManager.bufferStartCount, 0)
        XCTAssertEqual(focusManager.timeSpent, 5)
    }

    func testNonFocusBrowserResultWithoutFocusIsIgnored() {
        switchTo(browserBundleId, isFocusApp: false)

        browserManager.simulateBrowserFocusDeactivated()

        XCTAssertEqual(bufferManager.bufferStartCount, 0)
        XCTAssertFalse(focusManager.isInOverallFocus)
    }

    func testLeavingBrowserFocusForNonFocusAppStartsBuffer() {
        switchTo(browserBundleId, isFocusApp: false)
        browserManager.simulateBrowserFocusActivated()
        focusManager.timeSpent = 5

        switchTo("com.test.other", isFocusApp: false)

        XCTAssertFalse(focusManager.isBrowserInFocus)
        XCTAssertEqual(bufferManager.bufferStartCount, 1)
    }

    // MARK: - Buffer countdown

    func testBufferChangesNotifyFocusManagerObservers() {
        var changeCount = 0
        let cancellable = focusManager.objectWillChange.sink { _ in changeCount += 1 }
        defer { cancellable.cancel() }

        bufferManager.startBuffer(duration: 10)

        XCTAssertGreaterThan(changeCount, 0)
        XCTAssertEqual(focusManager.bufferTimeRemaining, 10)
    }
}

#endif

// FocusContextTests.swift
// The menu bar names the app or site holding focus, including while a buffer
// is running and the frontmost app is no longer a focus app.

@testable import auto_focus
import XCTest

#if DEBUG

final class FocusContextTests: XCTestCase {
    private let browserBundleId = "com.google.Chrome"
    private let focusAppBundleId = "com.test.focusapp"

    private var focusManager: FocusManager!
    private var appMonitor: MockAppMonitor!
    private var bufferManager: MockBufferManager!
    private var browserManager: MockBrowserManager!

    override func setUp() {
        super.setUp()
        let mocks = MockFactory.createMockDependencies()
        appMonitor = mocks.appMonitor
        bufferManager = mocks.bufferManager
        browserManager = mocks.browserManager

        focusManager = MockFactory.createFocusManager(
            sessionManager: mocks.sessionManager,
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

    func testNoContextWhenIdle() {
        XCTAssertNil(focusManager.focusContextName)
    }

    func testFocusAppSetsContext() {
        switchTo(focusAppBundleId, isFocusApp: true)

        XCTAssertEqual(focusManager.focusContextName, "TestApp")
    }

    func testContextSurvivesBuffer() {
        switchTo(focusAppBundleId, isFocusApp: true)
        focusManager.timeSpent = 5

        switchTo("com.test.other", isFocusApp: false)

        XCTAssertTrue(bufferManager.isInBufferPeriod)
        XCTAssertEqual(focusManager.focusContextName, "TestApp")
    }

    func testBufferTimeoutClearsContext() {
        switchTo(focusAppBundleId, isFocusApp: true)
        focusManager.timeSpent = 5
        switchTo("com.test.other", isFocusApp: false)

        bufferManager.simulateBufferTimeout()

        XCTAssertNil(focusManager.focusContextName)
    }

    func testSwitchingBetweenFocusAppsUpdatesContext() {
        focusManager.focusApps.append(AppInfo(id: "2", name: "OtherApp", bundleIdentifier: "com.test.focusapp2"))
        switchTo(focusAppBundleId, isFocusApp: true)

        // Focus-ness doesn't change between two focus apps, so only didChangeToApp fires
        appMonitor.currentApp = "com.test.focusapp2"
        focusManager.appMonitor(appMonitor, didChangeToApp: "com.test.focusapp2")

        XCTAssertEqual(focusManager.focusContextName, "OtherApp")
    }

    func testSwitchingBetweenFocusSitesUpdatesContext() {
        switchTo(browserBundleId, isFocusApp: false)
        browserManager.simulateBrowserFocusActivated(url: "https://github.com")

        // Focus state doesn't flip between two focus sites, so only the tab update arrives
        let tab = BrowserTabInfo(url: "https://linear.app/team", title: "Linear", isFocusURL: true)
        focusManager.browserManager(browserManager, didReceiveTabUpdate: tab)

        XCTAssertEqual(focusManager.focusContextName, "linear.app")
    }

    func testBrowserFocusSetsContextToDomain() {
        switchTo(browserBundleId, isFocusApp: false)

        browserManager.simulateBrowserFocusActivated(url: "https://github.com/janschill/auto-focus")

        XCTAssertEqual(focusManager.focusContextName, "github.com")
    }

    func testBufferExposesItsTotalDuration() {
        switchTo(focusAppBundleId, isFocusApp: true)
        focusManager.timeSpent = 5

        switchTo("com.test.other", isFocusApp: false)

        XCTAssertEqual(focusManager.bufferDuration, focusManager.glanceTolerance)
    }
}

#endif

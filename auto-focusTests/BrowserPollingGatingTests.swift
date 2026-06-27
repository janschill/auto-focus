import GRDB
import XCTest
@testable import auto_focus

#if DEBUG

final class BrowserPollingGatingTests: XCTestCase {
    private var dbQueue: DatabaseQueue!
    private var settingsRepo: SettingsRepository!
    private var enablementStore: BrowserEnablementStore!
    private var checker: MockAETargetPermissionChecker!
    private var permissionService: AutomationPermissionService!
    private var urlQuerier: MockBrowserURLQuerier!
    private var browserManager: BrowserManager!

    override func setUp() {
        super.setUp()
        dbQueue = MockFactory.createTestDB()
        settingsRepo = SettingsRepository(dbQueue: dbQueue)
        enablementStore = BrowserEnablementStore(settingsRepo: settingsRepo)
        checker = MockAETargetPermissionChecker()
        permissionService = AutomationPermissionService(checker: checker)
        urlQuerier = MockBrowserURLQuerier()
        browserManager = BrowserManager(
            focusURLRepo: FocusURLRepository(dbQueue: dbQueue),
            licenseManager: LicenseManager(),
            appEventRepo: AppEventRepository(dbQueue: dbQueue),
            enablementStore: enablementStore,
            permissionService: permissionService,
            urlQuerier: urlQuerier
        )
    }

    func testShouldPollIsFalseWhenBrowserDisabled() {
        permissionService.refreshAll(bundleIds: ["com.google.Chrome"])
        checker.scriptedStatuses = ["com.google.Chrome": OSStatus(noErr)]
        permissionService.refreshAll(bundleIds: ["com.google.Chrome"])

        XCTAssertFalse(browserManager.shouldPoll(bundleId: "com.google.Chrome"))
    }

    func testShouldPollRefreshesUnknownPermissionBeforeBlocking() {
        enablementStore.setEnabled(true, for: "com.google.Chrome")
        checker.scriptedStatuses = ["com.google.Chrome": OSStatus(noErr)]

        XCTAssertTrue(browserManager.shouldPoll(bundleId: "com.google.Chrome"))
        XCTAssertEqual(permissionService.status(for: "com.google.Chrome"), .granted)
        XCTAssertEqual(checker.callLog.last?.bundleId, "com.google.Chrome")
        XCTAssertEqual(checker.callLog.last?.askUserIfNeeded, false)
    }

    func testShouldPollIsFalseWhenPermissionDenied() {
        enablementStore.setEnabled(true, for: "com.google.Chrome")
        checker.scriptedStatuses = ["com.google.Chrome": OSStatus(-1743)]
        permissionService.refreshAll(bundleIds: ["com.google.Chrome"])

        XCTAssertFalse(browserManager.shouldPoll(bundleId: "com.google.Chrome"))
    }

    func testShouldPollIsFalseWhenPermissionNotDetermined() {
        enablementStore.setEnabled(true, for: "com.google.Chrome")
        checker.scriptedStatuses = ["com.google.Chrome": OSStatus(-1744)]
        permissionService.refreshAll(bundleIds: ["com.google.Chrome"])

        XCTAssertFalse(browserManager.shouldPoll(bundleId: "com.google.Chrome"))
    }

    func testShouldPollIsTrueWhenEnabledAndGranted() {
        enablementStore.setEnabled(true, for: "com.google.Chrome")
        checker.scriptedStatuses = ["com.google.Chrome": OSStatus(noErr)]
        permissionService.refreshAll(bundleIds: ["com.google.Chrome"])

        XCTAssertTrue(browserManager.shouldPoll(bundleId: "com.google.Chrome"))
    }

    func testTogglingOffBlocksPolling() {
        enablementStore.setEnabled(true, for: "com.google.Chrome")
        checker.scriptedStatuses = ["com.google.Chrome": OSStatus(noErr)]
        permissionService.refreshAll(bundleIds: ["com.google.Chrome"])
        XCTAssertTrue(browserManager.shouldPoll(bundleId: "com.google.Chrome"))

        enablementStore.setEnabled(false, for: "com.google.Chrome")
        XCTAssertFalse(browserManager.shouldPoll(bundleId: "com.google.Chrome"))
    }

    func testURLQueryFailureClearsStaleBrowserFocus() {
        let delegate = CapturingBrowserDelegate()
        browserManager.delegate = delegate

        browserManager.handleURLQueryResult(
            url: "https://github.com/janschill/auto-focus",
            errorNumber: nil,
            appName: "Google Chrome",
            bundleId: "com.google.Chrome"
        )
        XCTAssertTrue(browserManager.isBrowserInFocus)
        XCTAssertNotNil(browserManager.currentBrowserTab)

        browserManager.handleURLQueryResult(
            url: nil,
            errorNumber: -1719,
            appName: "Google Chrome",
            bundleId: "com.google.Chrome"
        )

        XCTAssertFalse(browserManager.isBrowserInFocus)
        XCTAssertNil(browserManager.currentBrowserTab)
        XCTAssertEqual(delegate.focusStates, [true, false])
    }

    func testNonFocusURLClearsStaleBrowserFocus() {
        let delegate = CapturingBrowserDelegate()
        browserManager.delegate = delegate

        browserManager.handleURLQueryResult(
            url: "https://github.com/janschill/auto-focus",
            errorNumber: nil,
            appName: "Google Chrome",
            bundleId: "com.google.Chrome"
        )
        XCTAssertTrue(browserManager.isBrowserInFocus)

        browserManager.handleURLQueryResult(
            url: "https://www.youtube.com/watch?v=abc123",
            errorNumber: nil,
            appName: "Google Chrome",
            bundleId: "com.google.Chrome"
        )

        XCTAssertFalse(browserManager.isBrowserInFocus)
        XCTAssertEqual(browserManager.currentBrowserTab?.url, "https://www.youtube.com/watch?v=abc123")
        XCTAssertEqual(delegate.focusStates, [true, false])
    }

    func testPollingBlockedClearsStaleBrowserFocus() {
        let delegate = CapturingBrowserDelegate()
        browserManager.delegate = delegate
        enablementStore.setEnabled(true, for: "com.google.Chrome")

        browserManager.handleURLQueryResult(
            url: "https://github.com/janschill/auto-focus",
            errorNumber: nil,
            appName: "Google Chrome",
            bundleId: "com.google.Chrome"
        )
        XCTAssertTrue(browserManager.isBrowserInFocus)

        browserManager.handlePollingBlocked(
            appName: "Google Chrome",
            bundleId: "com.google.Chrome"
        )

        XCTAssertFalse(browserManager.isBrowserInFocus)
        XCTAssertNil(browserManager.currentBrowserTab)
        XCTAssertEqual(delegate.focusStates, [true, false])
    }

    func testPermissionDeniedDuringPollClearsFocusAndCachesDenied() {
        let delegate = CapturingBrowserDelegate()
        browserManager.delegate = delegate
        enablementStore.setEnabled(true, for: "com.google.Chrome")
        checker.scriptedStatuses = ["com.google.Chrome": OSStatus(-1743)]

        browserManager.handleURLQueryResult(
            url: "https://github.com/janschill/auto-focus",
            errorNumber: nil,
            appName: "Google Chrome",
            bundleId: "com.google.Chrome"
        )
        XCTAssertTrue(browserManager.isBrowserInFocus)

        browserManager.handleURLQueryResult(
            url: nil,
            errorNumber: -1743,
            appName: "Google Chrome",
            bundleId: "com.google.Chrome"
        )

        XCTAssertFalse(browserManager.isBrowserInFocus)
        XCTAssertEqual(enablementStore.enablements["com.google.Chrome"]?.lastPermissionStatus, .denied)
        XCTAssertEqual(delegate.focusStates, [true, false])
    }
}

private final class CapturingBrowserDelegate: BrowserManagerDelegate {
    private(set) var focusStates: [Bool] = []
    private(set) var tabUpdates: [BrowserTabInfo] = []
    private(set) var focusURLUpdates: [[FocusURL]] = []

    func browserManager(_ manager: any BrowserManaging, didChangeFocusState isFocus: Bool) {
        focusStates.append(isFocus)
    }

    func browserManager(_ manager: any BrowserManaging, didReceiveTabUpdate tabInfo: BrowserTabInfo) {
        tabUpdates.append(tabInfo)
    }

    func browserManager(_ manager: any BrowserManaging, didUpdateFocusURLs urls: [FocusURL]) {
        focusURLUpdates.append(urls)
    }
}

#endif

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

    func testRepeatedSameFocusURLDoesNotPublishDuplicateUpdates() {
        let delegate = SpyBrowserManagerDelegate()
        browserManager.delegate = delegate

        browserManager.handlePolledURL(
            "https://github.com/janschill/auto-focus",
            appName: "Google Chrome",
            bundleId: "com.google.Chrome"
        )
        let firstTimestamp = browserManager.currentBrowserTab?.timestamp

        browserManager.handlePolledURL(
            "https://github.com/janschill/auto-focus",
            appName: "Google Chrome",
            bundleId: "com.google.Chrome"
        )

        XCTAssertEqual(delegate.focusStates, [true])
        XCTAssertEqual(delegate.tabUpdates.count, 1)
        XCTAssertEqual(browserManager.currentBrowserTab?.timestamp, firstTimestamp)
    }

    func testChangingFocusURLPublishesTabButNotDuplicateFocusState() {
        let delegate = SpyBrowserManagerDelegate()
        browserManager.delegate = delegate

        browserManager.handlePolledURL(
            "https://github.com/janschill/auto-focus",
            appName: "Google Chrome",
            bundleId: "com.google.Chrome"
        )

        browserManager.handlePolledURL(
            "https://stackoverflow.com/questions",
            appName: "Google Chrome",
            bundleId: "com.google.Chrome"
        )

        XCTAssertEqual(delegate.focusStates, [true])
        XCTAssertEqual(delegate.tabUpdates.map(\.url), [
            "https://github.com/janschill/auto-focus",
            "https://stackoverflow.com/questions",
        ])
    }
}

private final class SpyBrowserManagerDelegate: BrowserManagerDelegate {
    private(set) var focusStates: [Bool] = []
    private(set) var tabUpdates: [BrowserTabInfo] = []
    private(set) var urlUpdates: [[FocusURL]] = []

    func browserManager(_ manager: any BrowserManaging, didChangeFocusState isFocus: Bool) {
        focusStates.append(isFocus)
    }

    func browserManager(_ manager: any BrowserManaging, didReceiveTabUpdate tabInfo: BrowserTabInfo) {
        tabUpdates.append(tabInfo)
    }

    func browserManager(_ manager: any BrowserManaging, didUpdateFocusURLs urls: [FocusURL]) {
        urlUpdates.append(urls)
    }
}

#endif

import GRDB
import XCTest
@testable import auto_focus

#if DEBUG

final class BrowserEnablementStoreTests: XCTestCase {
    private var dbQueue: DatabaseQueue!
    private var settingsRepo: SettingsRepository!

    override func setUp() {
        super.setUp()
        dbQueue = MockFactory.createTestDB()
        settingsRepo = SettingsRepository(dbQueue: dbQueue)
    }

    func testDefaultsToEmptyWhenNotPersisted() {
        let store = BrowserEnablementStore(settingsRepo: settingsRepo)
        XCTAssertTrue(store.enablements.isEmpty)
        XCTAssertFalse(store.isEnabled("com.apple.Safari"))
    }

    func testSetEnabledPersistsAcrossInit() {
        let store1 = BrowserEnablementStore(settingsRepo: settingsRepo)
        store1.setEnabled(true, for: "com.google.Chrome")

        let store2 = BrowserEnablementStore(settingsRepo: settingsRepo)
        XCTAssertTrue(store2.isEnabled("com.google.Chrome"))
    }

    func testUpdateCachedStatusPreservesEnabledFlag() {
        let store = BrowserEnablementStore(settingsRepo: settingsRepo)
        store.setEnabled(true, for: "com.google.Chrome")
        store.updateCachedStatus(.granted, for: "com.google.Chrome")

        XCTAssertTrue(store.isEnabled("com.google.Chrome"))
        XCTAssertEqual(store.enablements["com.google.Chrome"]?.lastPermissionStatus, .granted)
    }

    func testAllEnabledBundleIdsReturnsOnlyEnabled() {
        let store = BrowserEnablementStore(settingsRepo: settingsRepo)
        store.setEnabled(true, for: "com.apple.Safari")
        store.setEnabled(true, for: "com.google.Chrome")
        store.setEnabled(false, for: "com.brave.Browser")

        XCTAssertEqual(store.allEnabledBundleIds(), ["com.apple.Safari", "com.google.Chrome"])
    }

    func testInitialMigrationSeedsWhenUserHasFocusURLs() {
        let store = BrowserEnablementStore(settingsRepo: settingsRepo)
        let applied = store.runInitialMigrationIfNeeded(
            installedBundleIds: ["com.apple.Safari", "com.google.Chrome"],
            hasExistingFocusURLs: true
        )

        XCTAssertTrue(applied)
        XCTAssertTrue(store.isEnabled("com.apple.Safari"))
        XCTAssertTrue(store.isEnabled("com.google.Chrome"))
    }

    func testInitialMigrationLeavesBlankOnFreshInstall() {
        let store = BrowserEnablementStore(settingsRepo: settingsRepo)
        let applied = store.runInitialMigrationIfNeeded(
            installedBundleIds: ["com.apple.Safari"],
            hasExistingFocusURLs: false
        )

        XCTAssertTrue(applied)
        XCTAssertFalse(store.isEnabled("com.apple.Safari"))
    }

    func testMigrationRunsOnceOnly() {
        let store = BrowserEnablementStore(settingsRepo: settingsRepo)
        _ = store.runInitialMigrationIfNeeded(
            installedBundleIds: ["com.apple.Safari"],
            hasExistingFocusURLs: true
        )
        store.setEnabled(false, for: "com.apple.Safari")

        let secondRun = store.runInitialMigrationIfNeeded(
            installedBundleIds: ["com.apple.Safari"],
            hasExistingFocusURLs: true
        )

        XCTAssertFalse(secondRun)
        XCTAssertFalse(store.isEnabled("com.apple.Safari"))
    }
}

#endif

// MigrationManagerTests.swift
// Verifies the UserDefaults → SQLite migration never discards legacy data it failed to read.

@testable import auto_focus
import GRDB
import XCTest

#if DEBUG

final class MigrationManagerTests: XCTestCase {
    private let migrationCompleteKey = "sqlite_migration_complete_v1"
    private let legacyKeys = ["focusSessions", "focusApps", "focusURLs"]

    private var suiteName: String!
    private var defaults: UserDefaults!
    private var testDB: DatabaseQueue!

    override func setUp() {
        super.setUp()
        suiteName = "MigrationManagerTests-\(UUID().uuidString)"
        defaults = UserDefaults(suiteName: suiteName)
        testDB = MockFactory.createTestDB()
    }

    override func tearDown() {
        defaults.removePersistentDomain(forName: suiteName)
        defaults = nil
        testDB = nil
        super.tearDown()
    }

    private func seedValidLegacyData() throws {
        let now = Date()
        let sessions = [FocusSession(startTime: now.addingTimeInterval(-600), endTime: now)]
        let apps = [AppInfo(id: "app-1", name: "Xcode", bundleIdentifier: "com.apple.dt.Xcode")]
        let urls = [FocusURL(name: "GitHub", domain: "github.com")]
        defaults.set(try JSONEncoder().encode(sessions), forKey: "focusSessions")
        defaults.set(try JSONEncoder().encode(apps), forKey: "focusApps")
        defaults.set(try JSONEncoder().encode(urls), forKey: "focusURLs")
    }

    private func runMigration() {
        MigrationManager.migrateIfNeeded(
            sessionRepo: SessionRepository(dbQueue: testDB),
            focusAppRepo: FocusAppRepository(dbQueue: testDB),
            focusURLRepo: FocusURLRepository(dbQueue: testDB),
            settingsRepo: SettingsRepository(dbQueue: testDB),
            defaults: defaults
        )
    }

    func testValidLegacyDataMigratesAndCleansUp() throws {
        try seedValidLegacyData()

        runMigration()

        XCTAssertTrue(defaults.bool(forKey: migrationCompleteKey))
        for key in legacyKeys {
            XCTAssertNil(defaults.data(forKey: key), "\(key) should be removed after successful migration")
        }
        XCTAssertEqual(try SessionRepository(dbQueue: testDB).fetchAll().count, 1)
        XCTAssertEqual(try FocusAppRepository(dbQueue: testDB).fetchAll().count, 1)
        XCTAssertEqual(try FocusURLRepository(dbQueue: testDB).fetchAll().count, 1)
    }

    func testDecodeFailureAbortsMigrationAndKeepsLegacyKeys() throws {
        let corruptData = Data("not json".utf8)

        for corruptKey in legacyKeys {
            defaults.removePersistentDomain(forName: suiteName)
            testDB = MockFactory.createTestDB()
            try seedValidLegacyData()
            defaults.set(corruptData, forKey: corruptKey)

            runMigration()

            XCTAssertFalse(defaults.bool(forKey: migrationCompleteKey),
                           "Corrupt \(corruptKey) must not mark migration complete")
            for key in legacyKeys {
                XCTAssertNotNil(defaults.data(forKey: key),
                                "Corrupt \(corruptKey) must not delete legacy key \(key)")
            }
            XCTAssertEqual(defaults.data(forKey: corruptKey), corruptData)
        }
    }
}

#endif

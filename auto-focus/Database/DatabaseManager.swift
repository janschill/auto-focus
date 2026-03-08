import Foundation
import GRDB

final class DatabaseManager {
    static let shared = DatabaseManager()

    let dbQueue: DatabaseQueue

    private init() {
        do {
            let fileManager = FileManager.default
            let appSupportURL = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
            let dbDirectory = appSupportURL.appendingPathComponent("auto-focus.auto-focus")

            try fileManager.createDirectory(at: dbDirectory, withIntermediateDirectories: true)

            let dbPath = dbDirectory.appendingPathComponent("autofocus.sqlite").path
            dbQueue = try DatabaseQueue(path: dbPath)

            try migrator.migrate(dbQueue)

            // Run UserDefaults migration before any repos read from DB.
            // Pass dbQueue directly to avoid circular dependency with DatabaseManager.shared.
            MigrationManager.migrateIfNeeded(
                sessionRepo: SessionRepository(dbQueue: dbQueue),
                focusAppRepo: FocusAppRepository(dbQueue: dbQueue),
                focusURLRepo: FocusURLRepository(dbQueue: dbQueue),
                settingsRepo: SettingsRepository(dbQueue: dbQueue)
            )

            AppLogger.focus.info("Database initialized", metadata: [
                "path": dbPath
            ])
        } catch {
            fatalError("Database setup failed: \(error)")
        }
    }

    /// For testing — accepts an in-memory or custom database queue
    init(dbQueue: DatabaseQueue) throws {
        self.dbQueue = dbQueue
        try migrator.migrate(dbQueue)
    }

    private var migrator: DatabaseMigrator {
        var migrator = DatabaseMigrator()

        migrator.registerMigration("v1_initial") { db in
            try db.create(table: "focusSession") { t in
                t.primaryKey("id", .text)
                t.column("startTime", .double).notNull()
                t.column("endTime", .double).notNull()
            }
            try db.create(
                index: "idx_focusSession_startTime",
                on: "focusSession",
                columns: ["startTime"]
            )

            try db.create(table: "appEvent") { t in
                t.autoIncrementedPrimaryKey("id")
                t.column("bundleIdentifier", .text).notNull()
                t.column("appName", .text)
                t.column("timestamp", .double).notNull()
                t.column("eventType", .text).notNull().defaults(to: "activate")
            }
            try db.create(
                index: "idx_appEvent_timestamp",
                on: "appEvent",
                columns: ["timestamp"]
            )
            try db.create(
                index: "idx_appEvent_bundleIdentifier",
                on: "appEvent",
                columns: ["bundleIdentifier"]
            )

            try db.create(table: "focusApp") { t in
                t.primaryKey("id", .text)
                t.column("name", .text).notNull()
                t.column("bundleIdentifier", .text).notNull().unique()
            }

            try db.create(table: "focusURL") { t in
                t.primaryKey("id", .text)
                t.column("name", .text).notNull()
                t.column("domain", .text).notNull()
                t.column("matchType", .text).notNull()
                t.column("isEnabled", .boolean).notNull().defaults(to: true)
                t.column("category", .text).notNull().defaults(to: "work")
                t.column("isPremium", .boolean).notNull().defaults(to: false)
            }

            try db.create(table: "setting") { t in
                t.primaryKey("key", .text)
                t.column("value", .text).notNull()
            }
        }

        migrator.registerMigration("v2_browser_events") { db in
            try db.alter(table: "appEvent") { t in
                t.add(column: "domain", .text)
                t.add(column: "url", .text)
            }
            try db.create(
                index: "idx_appEvent_domain",
                on: "appEvent",
                columns: ["domain"]
            )
            try db.create(
                index: "idx_appEvent_eventType",
                on: "appEvent",
                columns: ["eventType"]
            )
        }

        return migrator
    }
}

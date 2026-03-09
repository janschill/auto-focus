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

            // Migrate database from sandboxed container if this is the first
            // launch after removing the sandbox.
            Self.migrateSandboxedDatabaseIfNeeded(to: dbDirectory, fileManager: fileManager)
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

    /// Copies the SQLite database from the old sandboxed container to the new
    /// Application Support location. Runs if the destination database doesn't
    /// exist or is empty (e.g., created by a previous launch before migration
    /// was added).
    private static func migrateSandboxedDatabaseIfNeeded(to destinationDir: URL, fileManager: FileManager) {
        let destDB = destinationDir.appendingPathComponent("autofocus.sqlite")

        let homeDir = fileManager.homeDirectoryForCurrentUser
        let containerDB = homeDir
            .appendingPathComponent("Library/Containers/auto-focus.auto-focus/Data/Library/Application Support/auto-focus.auto-focus/autofocus.sqlite")

        guard fileManager.fileExists(atPath: containerDB.path) else { return }

        // Check if destination already has data (successfully migrated before)
        if fileManager.fileExists(atPath: destDB.path) {
            let destSize = (try? fileManager.attributesOfItem(atPath: destDB.path)[.size] as? Int) ?? 0
            let srcSize = (try? fileManager.attributesOfItem(atPath: containerDB.path)[.size] as? Int) ?? 0
            // Skip if destination is already larger or equal — migration already happened.
            // A freshly-created empty GRDB database is ~8KB (schema only), while one with
            // real data will be larger than the source.
            guard srcSize > destSize else { return }

            // Remove the empty/smaller destination so we can replace it
            let extensions = ["", "-wal", "-shm"]
            for ext in extensions {
                let dst = destDB.path + ext
                try? fileManager.removeItem(atPath: dst)
            }
        }

        // Copy the main database file and any WAL/SHM files
        let extensions = ["", "-wal", "-shm"]
        for ext in extensions {
            let src = containerDB.path + ext
            let dst = destDB.path + ext
            guard fileManager.fileExists(atPath: src) else { continue }
            do {
                try fileManager.copyItem(atPath: src, toPath: dst)
            } catch {
                AppLogger.focus.error("Failed to migrate sandboxed database file", error: error, metadata: [
                    "file": ext.isEmpty ? "autofocus.sqlite" : "autofocus.sqlite\(ext)"
                ])
            }
        }

        AppLogger.focus.info("Migrated database from sandboxed container")
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

import Foundation

enum Migrations {
    static let latestVersion = 1

    static func migrate(database: SQLiteDatabase) throws {
        let current = try database.userVersion()
        if current == 0 {
            try migrateToV1(database: database)
            try database.setUserVersion(1)
            AppLog.persistence.info("SQLite migrated to v1")
        } else if current < latestVersion {
            // Future: add additional migrations in order.
            throw SQLiteError.execFailed(message: "Unsupported schema version \(current)", sql: "PRAGMA user_version")
        }
    }

    private static func migrateToV1(database: SQLiteDatabase) throws {
        // Minimal schema based on specs/001-focus-monitoring/data-model.md
        try database.execute("""
        CREATE TABLE IF NOT EXISTS focus_settings (
          id INTEGER PRIMARY KEY CHECK(id = 1),
          activation_minutes INTEGER NOT NULL,
          buffer_seconds INTEGER NOT NULL,
          created_at INTEGER NOT NULL,
          updated_at INTEGER NOT NULL
        );
        """)

        try database.execute("""
        CREATE TABLE IF NOT EXISTS focus_entities (
          id TEXT PRIMARY KEY,
          type TEXT NOT NULL,
          display_name TEXT NOT NULL,
          match_value TEXT NOT NULL,
          is_enabled INTEGER NOT NULL,
          created_at INTEGER NOT NULL,
          updated_at INTEGER NOT NULL
        );
        """)

        try database.execute("""
        CREATE INDEX IF NOT EXISTS idx_focus_entities_type_match_value
          ON focus_entities(type, match_value);
        """)

        try database.execute("""
        CREATE INDEX IF NOT EXISTS idx_focus_entities_enabled
          ON focus_entities(is_enabled);
        """)

        try database.execute("""
        CREATE TABLE IF NOT EXISTS focus_events (
          id TEXT PRIMARY KEY,
          timestamp INTEGER NOT NULL,
          kind TEXT NOT NULL,
          app_bundle_id TEXT NULL,
          domain TEXT NULL,
          focus_entity_id TEXT NULL,
          details TEXT NULL
        );
        """)

        try database.execute("""
        CREATE INDEX IF NOT EXISTS idx_focus_events_timestamp
          ON focus_events(timestamp);
        """)

        try database.execute("""
        CREATE TABLE IF NOT EXISTS focus_sessions (
          id TEXT PRIMARY KEY,
          started_at INTEGER NOT NULL,
          ended_at INTEGER NULL,
          activation_minutes INTEGER NOT NULL,
          buffer_seconds INTEGER NOT NULL,
          ended_reason TEXT NULL,
          total_seconds_in_focus_mode INTEGER NOT NULL DEFAULT 0
        );
        """)
    }
}



import Foundation
import SQLite3

final class SQLiteFocusSettingsStore: FocusSettingsStoring {
    private let db: SQLiteDatabase

    init(database: SQLiteDatabase) {
        self.db = database
    }

    func load() throws -> FocusSettings {
        let stmt = try db.prepare("""
        SELECT activation_minutes, buffer_seconds
        FROM focus_settings
        WHERE id = 1;
        """)
        defer { sqlite3_finalize(stmt) }

        if sqlite3_step(stmt) == SQLITE_ROW {
            let activation = Int(sqlite3_column_int64(stmt, 0))
            let buffer = Int(sqlite3_column_int64(stmt, 1))
            return FocusSettings(activationMinutes: activation, bufferSeconds: buffer)
        }

        // Default settings if none saved yet.
        return FocusSettings(activationMinutes: 12, bufferSeconds: 30)
    }

    func save(_ settings: FocusSettings) throws {
        let now = Int(Date().timeIntervalSince1970)
        try db.execute("""
        INSERT INTO focus_settings (id, activation_minutes, buffer_seconds, created_at, updated_at)
        VALUES (1, \(settings.activationMinutes), \(settings.bufferSeconds), \(now), \(now))
        ON CONFLICT(id) DO UPDATE SET
          activation_minutes = excluded.activation_minutes,
          buffer_seconds = excluded.buffer_seconds,
          updated_at = excluded.updated_at;
        """)
    }
}



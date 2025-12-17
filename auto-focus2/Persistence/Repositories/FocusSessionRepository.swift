import Foundation

final class SQLiteFocusSessionStore: FocusSessionStoring {
    private let db: SQLiteDatabase

    init(database: SQLiteDatabase) {
        self.db = database
    }

    func start(_ session: FocusSession) throws {
        let startedAt = Int(session.startedAt.timeIntervalSince1970)
        try db.execute("""
        INSERT INTO focus_sessions (id, started_at, ended_at, activation_minutes, buffer_seconds, ended_reason, total_seconds_in_focus_mode)
        VALUES ('\(session.id.uuidString)', \(startedAt), NULL, \(session.activationMinutes), \(session.bufferSeconds), NULL, 0);
        """)
    }

    func end(sessionId: UUID, endedAt: Date, reason: FocusSessionEndReason, totalSecondsInFocusMode: Int) throws {
        let endedAtInt = Int(endedAt.timeIntervalSince1970)
        try db.execute("""
        UPDATE focus_sessions
        SET ended_at = \(endedAtInt),
            ended_reason = '\(reason.rawValue)',
            total_seconds_in_focus_mode = \(totalSecondsInFocusMode)
        WHERE id = '\(sessionId.uuidString)';
        """)
    }
}



import Foundation
import SQLite3

final class SQLiteFocusEventStore: FocusEventStoring {
    private let db: SQLiteDatabase

    init(database: SQLiteDatabase) {
        self.db = database
    }

    func append(_ event: FocusEvent) throws {
        let ts = Int(event.timestamp.timeIntervalSince1970)
        let app = event.appBundleId.map(escape) ?? ""
        let domain = event.domain.map(escape) ?? ""
        let entityId = event.focusEntityId?.uuidString ?? ""
        let details = event.details.map(escape) ?? ""

        try db.execute("""
        INSERT INTO focus_events (id, timestamp, kind, app_bundle_id, domain, focus_entity_id, details)
        VALUES (
          '\(event.id.uuidString)',
          \(ts),
          '\(event.kind.rawValue)',
          \(app.isEmpty ? "NULL" : "'\(app)'"),
          \(domain.isEmpty ? "NULL" : "'\(domain)'"),
          \(entityId.isEmpty ? "NULL" : "'\(entityId)'"),
          \(details.isEmpty ? "NULL" : "'\(details)'")
        );
        """)
    }

    private func escape(_ value: String) -> String {
        value.replacingOccurrences(of: "'", with: "''")
    }
}



import Foundation
import SQLite3

final class SQLiteFocusEntityStore: FocusEntityStoring {
    private let db: SQLiteDatabase
    private let licenseStateProvider: () -> LicenseState

    init(database: SQLiteDatabase, licenseStateProvider: @escaping () -> LicenseState = { .unlicensed }) {
        self.db = database
        self.licenseStateProvider = licenseStateProvider
    }

    func list() throws -> [FocusEntity] {
        let stmt = try db.prepare("""
        SELECT id, type, display_name, match_value, is_enabled, created_at, updated_at
        FROM focus_entities
        ORDER BY display_name COLLATE NOCASE ASC;
        """)
        defer { sqlite3_finalize(stmt) }

        var result: [FocusEntity] = []
        while sqlite3_step(stmt) == SQLITE_ROW {
            guard let idC = sqlite3_column_text(stmt, 0),
                  let typeC = sqlite3_column_text(stmt, 1),
                  let nameC = sqlite3_column_text(stmt, 2),
                  let matchC = sqlite3_column_text(stmt, 3)
            else { continue }

            let id = UUID(uuidString: String(cString: idC)) ?? UUID()
            let type = FocusEntityType(rawValue: String(cString: typeC)) ?? .app
            let name = String(cString: nameC)
            let match = String(cString: matchC)
            let enabled = sqlite3_column_int(stmt, 4) != 0
            let createdAt = Date(timeIntervalSince1970: TimeInterval(sqlite3_column_int64(stmt, 5)))
            let updatedAt = Date(timeIntervalSince1970: TimeInterval(sqlite3_column_int64(stmt, 6)))

            result.append(
                FocusEntity(
                    id: id,
                    type: type,
                    displayName: name,
                    matchValue: match,
                    isEnabled: enabled,
                    createdAt: createdAt,
                    updatedAt: updatedAt
                )
            )
        }
        return result
    }

    func upsert(_ entity: FocusEntity) throws {
        // Enforce max entities for free tier.
        let currentCount = (try? list().count) ?? 0
        if !PremiumGating.canAddFocusEntity(currentCount: currentCount, licenseState: licenseStateProvider()) {
            throw FocusEntityStoreError.limitReached(maxAllowed: PremiumGating.entitlements(for: licenseStateProvider()).maxFocusEntities)
        }

        let now = Int(Date().timeIntervalSince1970)
        let enabled = entity.isEnabled ? 1 : 0
        try db.execute("""
        INSERT INTO focus_entities (id, type, display_name, match_value, is_enabled, created_at, updated_at)
        VALUES ('\(entity.id.uuidString)', '\(entity.type.rawValue)', '\(escape(entity.displayName))', '\(escape(entity.matchValue))', \(enabled), \(Int(entity.createdAt.timeIntervalSince1970)), \(now))
        ON CONFLICT(id) DO UPDATE SET
          type = excluded.type,
          display_name = excluded.display_name,
          match_value = excluded.match_value,
          is_enabled = excluded.is_enabled,
          updated_at = excluded.updated_at;
        """)
    }

    func delete(id: UUID) throws {
        try db.execute("DELETE FROM focus_entities WHERE id = '\(id.uuidString)';")
    }

    private func escape(_ value: String) -> String {
        value.replacingOccurrences(of: "'", with: "''")
    }
}

enum FocusEntityStoreError: Error, LocalizedError {
    case limitReached(maxAllowed: Int)

    var errorDescription: String? {
        switch self {
        case .limitReached(let maxAllowed):
            return "Focus entity limit reached (max \(maxAllowed))"
        }
    }
}



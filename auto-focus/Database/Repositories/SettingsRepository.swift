import Foundation
import GRDB

final class SettingsRepository {
    private let dbQueue: DatabaseQueue

    init(dbQueue: DatabaseQueue = DatabaseManager.shared.dbQueue) {
        self.dbQueue = dbQueue
    }

    // MARK: - String

    func getString(forKey key: String) -> String? {
        try? dbQueue.read { db in
            try String.fetchOne(db, sql: "SELECT value FROM setting WHERE key = ?", arguments: [key])
        }
    }

    func setString(_ value: String, forKey key: String) throws {
        try dbQueue.write { db in
            try db.execute(
                sql: "INSERT OR REPLACE INTO setting (key, value) VALUES (?, ?)",
                arguments: [key, value]
            )
        }
    }

    // MARK: - Bool

    func getBool(forKey key: String) -> Bool {
        getString(forKey: key) == "true"
    }

    func setBool(_ value: Bool, forKey key: String) throws {
        try setString(value ? "true" : "false", forKey: key)
    }

    // MARK: - Double

    func getDouble(forKey key: String) -> Double {
        guard let str = getString(forKey: key) else { return 0.0 }
        return Double(str) ?? 0.0
    }

    func setDouble(_ value: Double, forKey key: String) throws {
        try setString(String(value), forKey: key)
    }

    // MARK: - Codable

    func getCodable<T: Codable>(_ type: T.Type, forKey key: String) -> T? {
        guard let str = getString(forKey: key),
              let data = str.data(using: .utf8) else { return nil }
        return try? JSONDecoder().decode(T.self, from: data)
    }

    func setCodable<T: Codable>(_ value: T, forKey key: String) throws {
        let data = try JSONEncoder().encode(value)
        guard let str = String(data: data, encoding: .utf8) else { return }
        try setString(str, forKey: key)
    }

    // MARK: - Remove

    func removeValue(forKey key: String) throws {
        try dbQueue.write { db in
            try db.execute(sql: "DELETE FROM setting WHERE key = ?", arguments: [key])
        }
    }
}

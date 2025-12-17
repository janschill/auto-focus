import Foundation
import SQLite3

final class SQLiteDatabase {
    private var db: OpaquePointer?

    init(path: String) throws {
        let flags = SQLITE_OPEN_CREATE | SQLITE_OPEN_READWRITE | SQLITE_OPEN_FULLMUTEX
        if sqlite3_open_v2(path, &db, flags, nil) != SQLITE_OK {
            throw SQLiteError.openFailed(message: lastErrorMessage)
        }
    }

    deinit {
        if db != nil {
            sqlite3_close(db)
        }
    }

    func execute(_ sql: String) throws {
        var err: UnsafeMutablePointer<Int8>?
        if sqlite3_exec(db, sql, nil, nil, &err) != SQLITE_OK {
            let msg = err.map { String(cString: $0) } ?? lastErrorMessage
            sqlite3_free(err)
            throw SQLiteError.execFailed(message: msg, sql: sql)
        }
    }

    func scalarInt(_ sql: String) throws -> Int {
        let stmt = try prepare(sql)
        defer { sqlite3_finalize(stmt) }
        if sqlite3_step(stmt) == SQLITE_ROW {
            return Int(sqlite3_column_int64(stmt, 0))
        }
        throw SQLiteError.queryFailed(message: lastErrorMessage, sql: sql)
    }

    func prepare(_ sql: String) throws -> OpaquePointer? {
        var stmt: OpaquePointer?
        if sqlite3_prepare_v2(db, sql, -1, &stmt, nil) != SQLITE_OK {
            throw SQLiteError.prepareFailed(message: lastErrorMessage, sql: sql)
        }
        return stmt
    }

    func setUserVersion(_ version: Int) throws {
        try execute("PRAGMA user_version = \(version);")
    }

    func userVersion() throws -> Int {
        try scalarInt("PRAGMA user_version;")
    }

    var lastErrorMessage: String {
        guard let db else { return "No database" }
        if let c = sqlite3_errmsg(db) {
            return String(cString: c)
        }
        return "Unknown SQLite error"
    }
}

enum SQLiteError: Error, CustomStringConvertible {
    case openFailed(message: String)
    case prepareFailed(message: String, sql: String)
    case execFailed(message: String, sql: String)
    case queryFailed(message: String, sql: String)

    var description: String {
        switch self {
        case .openFailed(let message): return "SQLite open failed: \(message)"
        case .prepareFailed(let message, let sql): return "SQLite prepare failed: \(message) | sql=\(sql)"
        case .execFailed(let message, let sql): return "SQLite exec failed: \(message) | sql=\(sql)"
        case .queryFailed(let message, let sql): return "SQLite query failed: \(message) | sql=\(sql)"
        }
    }
}



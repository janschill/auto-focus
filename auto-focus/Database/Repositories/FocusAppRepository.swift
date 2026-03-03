import Combine
import Foundation
import GRDB

final class FocusAppRepository {
    private let dbQueue: DatabaseQueue

    init(dbQueue: DatabaseQueue = DatabaseManager.shared.dbQueue) {
        self.dbQueue = dbQueue
    }

    // MARK: - CRUD

    func insert(_ app: AppInfo) throws {
        try dbQueue.write { db in
            try app.insert(db, onConflict: .ignore)
        }
    }

    func delete(_ app: AppInfo) throws {
        try dbQueue.write { db in
            _ = try app.delete(db)
        }
    }

    func fetchAll() throws -> [AppInfo] {
        try dbQueue.read { db in
            try AppInfo.order(Column("name").collating(.localizedCaseInsensitiveCompare)).fetchAll(db)
        }
    }

    func save(_ apps: [AppInfo]) throws {
        try dbQueue.write { db in
            _ = try AppInfo.deleteAll(db)
            for app in apps {
                try app.insert(db, onConflict: .ignore)
            }
        }
    }

    // MARK: - Observation

    func observeAll() -> DatabasePublishers.Value<[AppInfo]> {
        ValueObservation
            .tracking { db in
                try AppInfo.order(Column("name").collating(.localizedCaseInsensitiveCompare)).fetchAll(db)
            }
            .publisher(in: dbQueue, scheduling: .immediate)
    }
}

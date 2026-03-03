import Combine
import Foundation
import GRDB

final class FocusURLRepository {
    private let dbQueue: DatabaseQueue

    init(dbQueue: DatabaseQueue = DatabaseManager.shared.dbQueue) {
        self.dbQueue = dbQueue
    }

    // MARK: - CRUD

    func insert(_ url: FocusURL) throws {
        try dbQueue.write { db in
            try url.insert(db, onConflict: .ignore)
        }
    }

    func update(_ url: FocusURL) throws {
        try dbQueue.write { db in
            try url.update(db)
        }
    }

    func delete(_ url: FocusURL) throws {
        try dbQueue.write { db in
            _ = try url.delete(db)
        }
    }

    func fetchAll() throws -> [FocusURL] {
        try dbQueue.read { db in
            try FocusURL.order(Column("name").collating(.localizedCaseInsensitiveCompare)).fetchAll(db)
        }
    }

    func save(_ urls: [FocusURL]) throws {
        try dbQueue.write { db in
            _ = try FocusURL.deleteAll(db)
            for url in urls {
                try url.insert(db, onConflict: .ignore)
            }
        }
    }

    // MARK: - Observation

    func observeAll() -> DatabasePublishers.Value<[FocusURL]> {
        ValueObservation
            .tracking { db in
                try FocusURL.order(Column("name").collating(.localizedCaseInsensitiveCompare)).fetchAll(db)
            }
            .publisher(in: dbQueue, scheduling: .immediate)
    }
}

import Foundation
import GRDB

final class AppEventRepository {
    private let dbQueue: DatabaseQueue

    init(dbQueue: DatabaseQueue = DatabaseManager.shared.dbQueue) {
        self.dbQueue = dbQueue
    }

    func insert(_ event: AppEvent) throws {
        var event = event
        try dbQueue.write { db in
            try event.insert(db)
        }
    }

    func fetchRecent(limit: Int = 100) throws -> [AppEvent] {
        try dbQueue.read { db in
            try AppEvent
                .order(Column("timestamp").desc)
                .limit(limit)
                .fetchAll(db)
        }
    }

    func fetchEvents(since date: Date) throws -> [AppEvent] {
        try dbQueue.read { db in
            try AppEvent
                .filter(Column("timestamp") >= date.timeIntervalSinceReferenceDate)
                .order(Column("timestamp").desc)
                .fetchAll(db)
        }
    }
}

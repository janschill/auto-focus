import Combine
import Foundation
import GRDB

final class SessionRepository {
    private let dbQueue: DatabaseQueue

    init(dbQueue: DatabaseQueue = DatabaseManager.shared.dbQueue) {
        self.dbQueue = dbQueue
    }

    // MARK: - CRUD

    func insert(_ session: FocusSession) throws {
        try dbQueue.write { db in
            try session.insert(db, onConflict: .ignore)
        }
    }

    func update(_ session: FocusSession) throws {
        try dbQueue.write { db in
            try session.update(db)
        }
    }

    func delete(_ session: FocusSession) throws {
        try dbQueue.write { db in
            _ = try session.delete(db)
        }
    }

    func deleteAll() throws {
        try dbQueue.write { db in
            _ = try FocusSession.deleteAll(db)
        }
    }

    func fetchAll() throws -> [FocusSession] {
        try dbQueue.read { db in
            try FocusSession.order(Column("startTime").desc).fetchAll(db)
        }
    }

    // MARK: - Queries

    func sessionsToday() throws -> [FocusSession] {
        let startOfDay = Calendar.current.startOfDay(for: Date())
        return try dbQueue.read { db in
            try FocusSession
                .filter(Column("startTime") >= startOfDay.timeIntervalSinceReferenceDate)
                .order(Column("startTime").desc)
                .fetchAll(db)
        }
    }

    func sessionsInLastWeek() throws -> [FocusSession] {
        let oneWeekAgo = Calendar.current.startOfDay(
            for: Calendar.current.date(byAdding: .day, value: -7, to: Date())!
        )
        return try dbQueue.read { db in
            try FocusSession
                .filter(Column("startTime") >= oneWeekAgo.timeIntervalSinceReferenceDate)
                .order(Column("startTime").desc)
                .fetchAll(db)
        }
    }

    func sessionsInLastMonth() throws -> [FocusSession] {
        let oneMonthAgo = Calendar.current.startOfDay(
            for: Calendar.current.date(byAdding: .month, value: -1, to: Date())!
        )
        return try dbQueue.read { db in
            try FocusSession
                .filter(Column("startTime") >= oneMonthAgo.timeIntervalSinceReferenceDate)
                .order(Column("startTime").desc)
                .fetchAll(db)
        }
    }

    // MARK: - Observation

    func observeAll() -> DatabasePublishers.Value<[FocusSession]> {
        ValueObservation
            .tracking { db in
                try FocusSession.order(Column("startTime").desc).fetchAll(db)
            }
            .publisher(in: dbQueue, scheduling: .immediate)
    }
}

import Foundation
import GRDB

struct AppUsageSummary {
    let bundleIdentifier: String
    let appName: String?
    let totalDuration: TimeInterval
}

struct DomainUsageSummary {
    let domain: String
    let totalDuration: TimeInterval
    let visitCount: Int
}

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

    func fetchTopApps(since date: Date, limit: Int = 10) throws -> [AppUsageSummary] {
        try dbQueue.read { db in
            let sql = """
                WITH durations AS (
                    SELECT
                        bundleIdentifier,
                        appName,
                        MIN(LEAD(timestamp) OVER (ORDER BY timestamp) - timestamp, 7200) AS duration
                    FROM appEvent
                    WHERE timestamp >= ?
                )
                SELECT
                    bundleIdentifier,
                    appName,
                    SUM(duration) AS totalDuration
                FROM durations
                WHERE duration > 0
                GROUP BY bundleIdentifier
                ORDER BY totalDuration DESC
                LIMIT ?
                """
            let rows = try Row.fetchAll(db, sql: sql, arguments: [date.timeIntervalSinceReferenceDate, limit])
            return rows.map { row in
                AppUsageSummary(
                    bundleIdentifier: row["bundleIdentifier"],
                    appName: row["appName"],
                    totalDuration: row["totalDuration"]
                )
            }
        }
    }

    func fetchTopDomains(since date: Date, limit: Int = 10) throws -> [DomainUsageSummary] {
        try dbQueue.read { db in
            let sql = """
                WITH durations AS (
                    SELECT
                        domain,
                        MIN(LEAD(timestamp) OVER (ORDER BY timestamp) - timestamp, 7200) AS duration
                    FROM appEvent
                    WHERE timestamp >= ?
                )
                SELECT
                    domain,
                    SUM(duration) AS totalDuration,
                    COUNT(*) AS visitCount
                FROM durations
                WHERE duration > 0 AND domain IS NOT NULL
                GROUP BY domain
                ORDER BY totalDuration DESC
                LIMIT ?
                """
            let rows = try Row.fetchAll(db, sql: sql, arguments: [date.timeIntervalSinceReferenceDate, limit])
            return rows.map { row in
                DomainUsageSummary(
                    domain: row["domain"],
                    totalDuration: row["totalDuration"],
                    visitCount: row["visitCount"]
                )
            }
        }
    }

    func deleteEvents(before date: Date) throws {
        try dbQueue.write { db in
            try AppEvent
                .filter(Column("timestamp") < date.timeIntervalSinceReferenceDate)
                .deleteAll(db)
        }
    }
}

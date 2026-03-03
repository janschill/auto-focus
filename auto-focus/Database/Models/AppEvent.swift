import Foundation
import GRDB

struct AppEvent: Codable, Identifiable, FetchableRecord, PersistableRecord {
    var id: Int64?
    var bundleIdentifier: String
    var appName: String?
    var timestamp: Date
    var eventType: String

    static let databaseTableName = "appEvent"

    init(bundleIdentifier: String, appName: String? = nil, eventType: String = "activate") {
        self.bundleIdentifier = bundleIdentifier
        self.appName = appName
        self.timestamp = Date()
        self.eventType = eventType
    }

    // Custom encoding to store Date as TimeInterval
    func encode(to container: inout PersistenceContainer) {
        container["id"] = id
        container["bundleIdentifier"] = bundleIdentifier
        container["appName"] = appName
        container["timestamp"] = timestamp.timeIntervalSinceReferenceDate
        container["eventType"] = eventType
    }

    // Custom decoding to read Date from TimeInterval
    init(row: Row) throws {
        id = row["id"]
        bundleIdentifier = row["bundleIdentifier"]
        appName = row["appName"]
        timestamp = Date(timeIntervalSinceReferenceDate: row["timestamp"])
        eventType = row["eventType"]
    }

    mutating func didInsert(_ inserted: InsertionSuccess) {
        id = inserted.rowID
    }
}

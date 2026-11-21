import Foundation
import GRDB

struct AppEvent: Codable, Identifiable, FetchableRecord, PersistableRecord {
    var id: Int64?
    var bundleIdentifier: String
    var appName: String?
    var timestamp: Date
    var eventType: String
    var domain: String?
    var url: String?

    static let databaseTableName = "appEvent"

    /// Marks the moment the screen locked or slept, so time away isn't attributed to the last app.
    /// Uses the lock screen's bundle ID, which every consumer already treats as screen-inactive.
    static func awayMarker() -> AppEvent {
        AppEvent(bundleIdentifier: "com.apple.loginwindow", eventType: "away")
    }

    init(bundleIdentifier: String, appName: String? = nil, eventType: String = "activate") {
        self.bundleIdentifier = bundleIdentifier
        self.appName = appName
        self.timestamp = Date()
        self.eventType = eventType
    }

    init(bundleIdentifier: String, appName: String? = nil, url: String, domain: String?) {
        self.bundleIdentifier = bundleIdentifier
        self.appName = appName
        self.timestamp = Date()
        self.eventType = "tab_changed"
        self.url = url
        self.domain = domain
    }

    // Custom encoding to store Date as TimeInterval
    func encode(to container: inout PersistenceContainer) {
        container["id"] = id
        container["bundleIdentifier"] = bundleIdentifier
        container["appName"] = appName
        container["timestamp"] = timestamp.timeIntervalSinceReferenceDate
        container["eventType"] = eventType
        container["domain"] = domain
        container["url"] = url
    }

    // Custom decoding to read Date from TimeInterval
    init(row: Row) throws {
        id = row["id"]
        bundleIdentifier = row["bundleIdentifier"]
        appName = row["appName"]
        timestamp = Date(timeIntervalSinceReferenceDate: row["timestamp"])
        eventType = row["eventType"]
        domain = row["domain"]
        url = row["url"]
    }

    mutating func didInsert(_ inserted: InsertionSuccess) {
        id = inserted.rowID
    }

    static func extractDomain(from urlString: String) -> String? {
        if let url = URL(string: urlString), let host = url.host {
            return host.lowercased()
        }
        if !urlString.contains("://"),
           let url = URL(string: "https://\(urlString)"),
           let host = url.host {
            return host.lowercased()
        }
        return nil
    }
}

//
//  FocusSession.swift
//  auto-focus
//
//  Created by Jan Schill on 27/01/2025.
//

import Foundation
import GRDB

struct FocusSession: Codable, Identifiable, Equatable, FetchableRecord, PersistableRecord {
    let id: UUID
    var startTime: Date
    var endTime: Date

    static let databaseTableName = "focusSession"

    var duration: TimeInterval {
        return endTime.timeIntervalSince(startTime)
    }

    static func == (lhs: FocusSession, rhs: FocusSession) -> Bool {
        return lhs.id == rhs.id
    }

    // Custom encoding — store Date as TimeInterval
    func encode(to container: inout PersistenceContainer) {
        container["id"] = id.uuidString
        container["startTime"] = startTime.timeIntervalSinceReferenceDate
        container["endTime"] = endTime.timeIntervalSinceReferenceDate
    }

    // Custom decoding — read Date from TimeInterval
    init(row: Row) throws {
        id = UUID(uuidString: row["id"])!
        startTime = Date(timeIntervalSinceReferenceDate: row["startTime"])
        endTime = Date(timeIntervalSinceReferenceDate: row["endTime"])
    }
}

extension FocusSession {
    init(startTime: Date, endTime: Date) {
        self.id = UUID()
        self.startTime = startTime
        self.endTime = endTime
    }
}

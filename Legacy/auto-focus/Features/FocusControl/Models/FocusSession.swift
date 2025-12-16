//
//  FocusSession.swift
//  auto-focus
//
//  Created by Jan Schill on 27/01/2025.
//

import Foundation

struct FocusSession: Codable, Identifiable, Equatable {
    let id: UUID
    var startTime: Date
    var endTime: Date

    var duration: TimeInterval {
        return endTime.timeIntervalSince(startTime)
    }
    
    static func == (lhs: FocusSession, rhs: FocusSession) -> Bool {
        return lhs.id == rhs.id
    }
}

extension FocusSession {
    init(startTime: Date, endTime: Date) {
        self.id = UUID()
        self.startTime = startTime
        self.endTime = endTime
    }

}

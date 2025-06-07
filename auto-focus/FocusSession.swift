//
//  FocusSession.swift
//  auto-focus
//
//  Created by Jan Schill on 27/01/2025.
//

import Foundation

struct FocusSession: Codable, Identifiable {
    let id: UUID
    let startTime: Date
    let endTime: Date

    var duration: TimeInterval {
        return endTime.timeIntervalSince(startTime)
    }
}

extension FocusSession {
    init(startTime: Date, endTime: Date) {
        self.id = UUID()
        self.startTime = startTime
        self.endTime = endTime
    }

}

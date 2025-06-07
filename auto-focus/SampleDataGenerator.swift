//
//  SampleDataGenerator.swift
//  auto-focus
//
//  Created for development debugging purposes
//

import Foundation

class SampleDataGenerator {
    static let shared = SampleDataGenerator()

    /// Generates a set of randomized focus sessions for testing purposes
    /// - Parameters:
    ///   - days: Number of days to generate data for (counting back from today)
    ///   - sessionsPerDay: Average number of sessions per day (actual count will vary randomly)
    ///   - avgSessionLength: Average session length in minutes (actual lengths will vary randomly)
    /// - Returns: Array of FocusSession objects
    func generateSampleSessions(days: Int = 30,
                               sessionsPerDay: Int = 5,
                               avgSessionLength: TimeInterval = 25 * 60) -> [FocusSession] {

        var sessions: [FocusSession] = []
        let calendar = Calendar.current
        let now = Date()

        // Generate data for each day
        for dayOffset in 0..<days {
            // Get date for this day (counting backward from today)
            guard let date = calendar.date(byAdding: .day, value: -dayOffset, to: now) else {
                continue
            }

            // Randomly vary the number of sessions for this day
            let variance = Double.random(in: 0.5...1.5)
            let actualSessionCount = max(1, Int(Double(sessionsPerDay) * variance))

            // Generate the sessions for this day
            for _ in 0..<actualSessionCount {
                // Random hour of the day (weight toward working hours)
                let hour = weightedRandomHour()
                let minute = Int.random(in: 0...59)

                // Create session time components
                var startComponents = calendar.dateComponents([.year, .month, .day], from: date)
                startComponents.hour = hour
                startComponents.minute = minute

                guard let startTime = calendar.date(from: startComponents) else {
                    continue
                }

                // Random session length with variation around the average
                let lengthVariance = Double.random(in: 0.6...1.4)
                let sessionLength = avgSessionLength * lengthVariance

                // Create end time
                guard let endTime = calendar.date(byAdding: .second, value: Int(sessionLength), to: startTime) else {
                    continue
                }

                // Create and add the session
                let session = FocusSession(startTime: startTime, endTime: endTime)
                sessions.append(session)
            }
        }

        return sessions
    }

    /// Generate a weighted random hour that favors working hours (9-17)
    private func weightedRandomHour() -> Int {
        let random = Double.random(in: 0...1)

        // 70% chance of being during working hours (9-17)
        if random < 0.7 {
            return Int.random(in: 9...17)
        }
        // 20% chance of being early morning or evening (6-9 or 17-22)
        else if random < 0.9 {
            if Bool.random() {
                return Int.random(in: 6...8)
            } else {
                return Int.random(in: 18...21)
            }
        }
        // 10% chance of being very early or late (0-6 or 22-23)
        else {
            if Bool.random() {
                return Int.random(in: 0...5)
            } else {
                return Int.random(in: 22...23)
            }
        }
    }

}

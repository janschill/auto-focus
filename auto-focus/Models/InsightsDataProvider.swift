// InsightsMetrics.swift
import Foundation

struct DayData: Identifiable {
    let id = UUID()
    let date: Date
    let weekdaySymbol: String
    let totalMinutes: Int
    let isSelected: Bool
    let isToday: Bool
}

struct HourData: Identifiable {
    let id = UUID()
    let hour: Int
    let totalMinutes: Int
}

class InsightsDataProvider {
    var focusManager: FocusManager

    init(focusManager: FocusManager = FocusManager.shared) {
        self.focusManager = focusManager
    }

    enum Timeframe: String, CaseIterable, Identifiable {
        case day = "Today"
        case week = "Last Week"

        var id: String { self.rawValue }
    }

    func sessionsForDate(_ date: Date) -> [FocusSession] {
        let calendar = Calendar.current
        return focusManager.focusSessions.filter { calendar.isDate($0.startTime, inSameDayAs: date) }
    }

    func totalFocusTime(for date: Date) -> TimeInterval {
        return sessionsForDate(date).reduce(0) { $0 + $1.duration }
    }

    func totalFocusTime(timeframe: Timeframe, selectedDate: Date) -> TimeInterval {
        switch timeframe {
        case .day:
            return totalFocusTime(for: selectedDate)
        case .week:
            return totalFocusTimeInWeek(starting: Calendar.current.startOfWeek(for: selectedDate))
        }
    }

    func totalFocusTimeInWeek(starting weekStart: Date) -> TimeInterval {
        let calendar = Calendar.current
        let weekEnd = calendar.date(byAdding: .day, value: 7, to: weekStart) ?? weekStart
        return focusManager.focusSessions.filter {
            $0.startTime >= weekStart && $0.startTime < weekEnd
        }.reduce(0) { $0 + $1.duration }
    }

    func calculateTotalFocusTimeThisMonth() -> TimeInterval {
        let calendar = Calendar.current
        let now = Date()

        // Get the start of the current month
        let components = calendar.dateComponents([.year, .month], from: now)
        guard let startOfMonth = calendar.date(from: components) else {
            return 0
        }

        let sessions = focusManager.focusSessions.filter {
            $0.startTime >= startOfMonth && $0.startTime <= now
        }

        return sessions.reduce(0) { $0 + $1.duration }
    }

    func relevantSessions(timeframe: Timeframe, selectedDate: Date) -> [FocusSession] {
        switch timeframe {
        case .day:
            return sessionsForDate(selectedDate)
        case .week:
            let calendar = Calendar.current
            let start = calendar.startOfWeek(for: selectedDate)
            let end = calendar.date(byAdding: .day, value: 7, to: start) ?? start
            return focusManager.focusSessions.filter { $0.startTime >= start && $0.startTime < end }
        }
    }

    func weekdayData(selectedDate: Date, selectedTimeframe: Timeframe) -> [DayData] {
        let calendar = Calendar.current
        let weekStart = calendar.startOfWeek(for: selectedDate)

        return (0..<7).map { dayOffset in
            let date = calendar.date(byAdding: .day, value: dayOffset, to: weekStart)!
            let sessions = sessionsForDate(date)
            let totalMinutes = Int(sessions.reduce(0) { $0 + $1.duration } / 60)
            let weekday = calendar.component(.weekday, from: date)
            let isSelected = calendar.isDate(date, inSameDayAs: selectedDate) && selectedTimeframe == .day

            return DayData(
                date: date,
                weekdaySymbol: calendar.weekdaySymbols[weekday - 1].prefix(3).uppercased(),
                totalMinutes: totalMinutes,
                isSelected: isSelected,
                isToday: calendar.isDateInToday(date)
            )
        }
    }

    func hourlyData(selectedDate: Date) -> [HourData] {
        let calendar = Calendar.current
        let sessions = sessionsForDate(selectedDate)
        let dayStart = calendar.startOfDay(for: selectedDate)

        return (0..<24).map { hour in
            let hourStart = calendar.date(byAdding: .hour, value: hour, to: dayStart)!
            let hourEnd = calendar.date(byAdding: .hour, value: 1, to: hourStart)!

            // Calculate total time for this hour by summing portions of sessions that overlap
            var totalDuration: TimeInterval = 0

            for session in sessions {
                // Calculate overlap between session and this hour
                let sessionStart = max(session.startTime, hourStart)
                let sessionEnd = min(session.endTime, hourEnd)

                if sessionStart < sessionEnd {
                    totalDuration += sessionEnd.timeIntervalSince(sessionStart)
                }
            }

            let totalMinutes = Int(totalDuration / 60)
            return HourData(hour: hour, totalMinutes: totalMinutes)
        }
    }

    func averageDailyMinutes(weekdayData: [DayData]) -> Int {
        let daysWithSessions = weekdayData.filter { $0.totalMinutes > 0 }
        guard !daysWithSessions.isEmpty else { return 0 }

        let totalMinutes = daysWithSessions.reduce(0) { $0 + $1.totalMinutes }
        return totalMinutes / daysWithSessions.count
    }

    func calculateProductiveTimeRange() -> (startHour: Int, endHour: Int, duration: TimeInterval)? {
        let allSessions = focusManager.focusSessions
        let calendar = Calendar.current

        // Calculate total duration per hour (accounting for sessions spanning multiple hours)
        var hourlyTotals = Array(repeating: TimeInterval(0), count: 24)

        for session in allSessions {
            let sessionStartHour = calendar.component(.hour, from: session.startTime)
            let sessionEndHour = calendar.component(.hour, from: session.endTime)

            if sessionStartHour == sessionEndHour {
                // Session is entirely within one hour
                hourlyTotals[sessionStartHour] += session.duration
            } else {
                // Session spans multiple hours - calculate portion per hour
                let dayStart = calendar.startOfDay(for: session.startTime)

                // First hour: from session start to end of hour
                let firstHourStart = calendar.date(byAdding: .hour, value: sessionStartHour, to: dayStart)!
                let firstHourEnd = calendar.date(byAdding: .hour, value: 1, to: firstHourStart)!
                let firstHourDuration = firstHourEnd.timeIntervalSince(session.startTime)
                hourlyTotals[sessionStartHour] += firstHourDuration

                // Middle hours: full hours
                var currentHour = sessionStartHour + 1
                while currentHour < sessionEndHour {
                    hourlyTotals[currentHour] += 3600 // 1 hour in seconds
                    currentHour += 1
                }

                // Last hour: from start of hour to session end
                if sessionEndHour < 24 {
                    let lastHourStart = calendar.date(byAdding: .hour, value: sessionEndHour, to: dayStart)!
                    let lastHourDuration = session.endTime.timeIntervalSince(lastHourStart)
                    hourlyTotals[sessionEndHour] += lastHourDuration
                }
            }
        }

        // Find the best consecutive 2-hour period
        var maxDuration: TimeInterval = 0
        var maxStartHour = 0

        for startHour in 0..<24 {
            let endHour = startHour + 1
            let combinedDuration: TimeInterval

            if endHour < 24 {
                // Normal case: consecutive hours within same day
                combinedDuration = hourlyTotals[startHour] + hourlyTotals[endHour]
            } else {
                // Wrap-around: last hour (23) + first hour (0) of next day
                combinedDuration = hourlyTotals[23] + hourlyTotals[0]
            }

            if combinedDuration > maxDuration {
                maxDuration = combinedDuration
                maxStartHour = startHour
            }
        }

        if maxDuration > 0 {
            let endHour = maxStartHour + 1
            // Handle wrap-around: if endHour is 24, it means midnight (0), but we'll display it as 24
            return (startHour: maxStartHour, endHour: endHour >= 24 ? 24 : endHour, duration: maxDuration)
        }

        return nil
    }

    func calculateProductiveWeekday() -> (weekday: Int, duration: TimeInterval)? {
        let allSessions = focusManager.focusSessions
        let calendar = Calendar.current

        let weekdayData = Dictionary(grouping: allSessions) { session in
            calendar.component(.weekday, from: session.startTime)
        }

        let weekdayTotals = weekdayData.mapValues { sessions in
            sessions.reduce(0) { $0 + $1.duration }
        }

        if let maxWeekday = weekdayTotals.max(by: { $0.value < $1.value }) {
            return (weekday: maxWeekday.key, duration: maxWeekday.value)
        }
        return nil
    }

    func calculateWeekdayAverages() -> [(day: String, average: TimeInterval)] {
        let calendar = Calendar.current
        let allSessions = focusManager.focusSessions

        let weekdayData = Dictionary(grouping: allSessions) { session in
            calendar.component(.weekday, from: session.startTime)
        }

        return (1...7).map { weekday in
            let symbol = calendar.shortWeekdaySymbols[weekday - 1]
            let sessions = weekdayData[weekday] ?? []
            let sessionsByDay = Dictionary(grouping: sessions) { session in
                calendar.startOfDay(for: session.startTime)
            }
            let dailyTotals = sessionsByDay.values.map { daySessions in
                daySessions.reduce(0) { $0 + $1.duration }
            }
            let average = dailyTotals.isEmpty ? 0 : dailyTotals.reduce(0, +) / Double(dailyTotals.count)

            return (day: symbol, average: average)
        }
    }

    func formatHourRange(_ startHour: Int, _ endHour: Int) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "h a"

        var startComponents = DateComponents()
        startComponents.hour = startHour

        var endComponents = DateComponents()
        // Handle midnight wrap-around: 24 means midnight (0) of next day
        endComponents.hour = endHour >= 24 ? 0 : endHour

        let calendar = Calendar.current
        if let startDate = calendar.date(from: startComponents),
           let endDate = calendar.date(from: endComponents) {
            // If endHour is 24, show it as "12 AM" (midnight)
            if endHour >= 24 {
                return "\(formatter.string(from: startDate))–12 AM"
            }
            return "\(formatter.string(from: startDate))–\(formatter.string(from: endDate))"
        }

        // Fallback: handle midnight case
        if endHour >= 24 {
            return "\(startHour) PM–12 AM"
        }
        return "\(startHour)–\(endHour)"
    }

    func dateString(for date: Date) -> String {
        let calendar = Calendar.current

        // Use shorter format for long dates to prevent truncation
        let formatter = DateFormatter()

        // If it's today, just say "Today"
        if calendar.isDateInToday(date) {
            return "Today"
        }

        // If it's yesterday, say "Yesterday"
        if calendar.isDateInYesterday(date) {
            return "Yesterday"
        }

        // For other dates, use a more compact format
        // Use abbreviated weekday and month to save space
        formatter.dateFormat = "EEE, MMM d"
        return formatter.string(from: date)
    }

}

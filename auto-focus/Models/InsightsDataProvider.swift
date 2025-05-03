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

    init(focusManager: FocusManager) {
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

        return (0..<24).map { hour in
            let hourSessions = sessions.filter {
                calendar.component(.hour, from: $0.startTime) == hour
            }
            let totalMinutes = Int(hourSessions.reduce(0) { $0 + $1.duration } / 60)
            return HourData(hour: hour, totalMinutes: totalMinutes)
        }
    }

    func averageDailyMinutes(weekdayData: [DayData]) -> Int {
        let totalMinutes = weekdayData.reduce(0) { $0 + $1.totalMinutes }
        return totalMinutes / max(1, weekdayData.filter { $0.totalMinutes > 0 }.count)
    }

    func dateString(for date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "EEEE, MMMM d"
        return formatter.string(from: date)
    }

    static func formatDuration(_ minutes: Int) -> String {
        return minutes >= 60 ? "\(minutes / 60)h \(minutes % 60)m" : "\(minutes)m"
    }
}

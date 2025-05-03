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

    func calculateProductiveTimeRange() -> (startHour: Int, endHour: Int, duration: TimeInterval)? {
        let allSessions = focusManager.focusSessions
        let calendar = Calendar.current
        let hourlyData = Dictionary(grouping: allSessions) { session in
            calendar.component(.hour, from: session.startTime)
        }
        
        let hourlyTotals = (0..<24).map { hour in
            let sessions = hourlyData[hour] ?? []
            let totalDuration = sessions.reduce(0) { $0 + $1.duration }
            return (hour: hour, duration: totalDuration)
        }
        
        var maxDuration: TimeInterval = 0
        var maxStartHour = 0
        
        for startHour in 0..<23 {
            let endHour = (startHour + 1) % 24
            let combinedDuration = hourlyTotals[startHour].duration + hourlyTotals[endHour].duration
            
            if combinedDuration > maxDuration {
                maxDuration = combinedDuration
                maxStartHour = startHour
            }
        }
        
        if maxDuration > 0 {
            return (startHour: maxStartHour, endHour: (maxStartHour + 1) % 24, duration: maxDuration)
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
        endComponents.hour = endHour
        
        let calendar = Calendar.current
        if let startDate = calendar.date(from: startComponents),
           let endDate = calendar.date(from: endComponents) {
            return "\(formatter.string(from: startDate))–\(formatter.string(from: endDate))"
        }
        
        return "\(startHour)–\(endHour)"
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

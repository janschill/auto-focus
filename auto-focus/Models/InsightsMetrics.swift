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
    
    // Helper to get sessions for specific date
    func sessionsForDate(_ date: Date) -> [FocusSession] {
        let calendar = Calendar.current
        return focusManager.focusSessions.filter { session in
            calendar.isDate(session.startTime, inSameDayAs: date)
        }
    }
    
    // Get focus time for the selected date
    func totalFocusTime(for date: Date) -> TimeInterval {
        let sessions = sessionsForDate(date)
        return sessions.reduce(0) { $0 + $1.duration }
    }
    
    // Get focus time for the selected timeframe
    func totalFocusTime(timeframe: Timeframe, selectedDate: Date) -> TimeInterval {
        if timeframe == .day {
            return totalFocusTime(for: selectedDate)
        } else {
            return focusManager.weekSessions.reduce(0) { $0 + $1.duration }
        }
    }
    
    // Get relevant sessions for the selected timeframe
    func relevantSessions(timeframe: Timeframe, selectedDate: Date) -> [FocusSession] {
        if timeframe == .day {
            return sessionsForDate(selectedDate)
        } else {
            return focusManager.weekSessions
        }
    }
    
    // Get daily data for the week view
    func weekdayData(selectedDate: Date, selectedTimeframe: Timeframe) -> [DayData] {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        let currentWeekday = calendar.component(.weekday, from: today)
        let daysToMonday = ((currentWeekday - 2) + 7) % 7
        let monday = calendar.date(byAdding: .day, value: -daysToMonday, to: today)!
        
        return (0..<7).map { dayOffset in
            let date = calendar.date(byAdding: .day, value: dayOffset, to: monday)!
            let daySessions = sessionsForDate(date)
            let totalDuration = daySessions.reduce(0) { $0 + $1.duration }
            let weekday = calendar.component(.weekday, from: date)
            let isSelected = calendar.isDate(date, inSameDayAs: selectedDate) && selectedTimeframe == .day
            
            return DayData(
                date: date,
                weekdaySymbol: calendar.weekdaySymbols[weekday - 1].prefix(3).uppercased(), // M, T, W, etc.
                totalMinutes: Int(totalDuration / 60),
                isSelected: isSelected,
                isToday: calendar.isDateInToday(date)
            )
        }
    }
    
    // Get hourly data for day view
    func hourlyData(selectedDate: Date) -> [HourData] {
        let calendar = Calendar.current
        let sessions = sessionsForDate(selectedDate)
        
        return (0..<24).map { hour in
            let hourSessions = sessions.filter { session in
                let sessionHour = calendar.component(.hour, from: session.startTime)
                return sessionHour == hour
            }
            let totalDuration = hourSessions.reduce(0) { $0 + $1.duration }
            
            return HourData(
                hour: hour,
                totalMinutes: Int(totalDuration / 60)
            )
        }
    }
    
    // Calculate average daily minutes
    func averageDailyMinutes(weekdayData: [DayData]) -> Int {
        let totalMinutes = weekdayData.reduce(0) { $0 + $1.totalMinutes }
        return totalMinutes / max(1, weekdayData.filter { $0.totalMinutes > 0 }.count)
    }
    
    // Calculate weekly comparison
//    func weeklyComparison() -> (Int, Bool)? {
//        guard selectedTimeframe == .week else { return nil }
//        
//        // Compare with previous week - this is simplified and would need to be expanded
//        // with actual previous week data
//        let previousWeekTotal = Int.random(in: 400...600) // Placeholder for demo
//        let currentWeekTotal = weekdayData.reduce(0) { $0 + $1.totalMinutes }
//        let percentChange = ((Double(currentWeekTotal) / Double(previousWeekTotal)) - 1.0) * 100
//        
//        return (Int(abs(percentChange)), percentChange < 0)
//        
//        
//        // This would use the actual data from FocusManager
//        let weeklyStats = focusManager.weeklyComparison()
//        return (Int(abs(weeklyStats.percentChange)), !weeklyStats.isIncrease)
//    }
    
    // Get formatted date string
    func dateString(for date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "EEEE, MMMM d"
        return formatter.string(from: date)
    }
    
    // Format duration
    static func formatDuration(_ minutes: Int) -> String {
        if minutes >= 60 {
            let hours = minutes / 60
            let mins = minutes % 60
            return "\(hours)h \(mins)m"
        } else {
            return "\(minutes)m"
        }
    }
}

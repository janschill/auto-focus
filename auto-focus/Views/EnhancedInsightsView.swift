//
//  EnhancedInsightsView.swift
//  auto-focus
//
//  Created by Jan Schill on 23/04/2025.
//

import SwiftUI
import Charts

struct EnhancedInsightsView: View {
    @EnvironmentObject var focusManager: FocusManager
    @State private var selectedTimeframe: Timeframe = .day
    @State private var selectedDate: Date = Date()
    @State private var selectedDayOfWeek: Int? = nil
    
    enum Timeframe: String, CaseIterable, Identifiable {
        case day = "Today, April 23"
        case week = "Last Week"
        
        var id: String { self.rawValue }
    }
    
    private var dateFormatter: DateFormatter {
        let formatter = DateFormatter()
        formatter.dateFormat = "EEEE, MMMM d"
        return formatter
    }
    
    private var displayedDateString: String {
        if selectedTimeframe == .day {
            return dateFormatter.string(from: selectedDate)
        } else {
            return "Last Week"
        }
    }
    
    private var totalFocusTime: TimeInterval {
        let sessions = relevantSessions
        return sessions.reduce(0) { $0 + $1.duration }
    }
    
    private var relevantSessions: [FocusSession] {
        if selectedTimeframe == .day {
            return sessionsForDate(selectedDate)
        } else {
            return focusManager.weekSessions
        }
    }
    
    private func sessionsForDate(_ date: Date) -> [FocusSession] {
        let calendar = Calendar.current
        return focusManager.focusSessions.filter { session in
            calendar.isDate(session.startTime, inSameDayAs: date)
        }
    }
    
    private var weekdayData: [DayData] {
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
                weekdaySymbol: calendar.weekdaySymbols[weekday - 1].prefix(1).uppercased(), // M, T, W, etc.
                totalMinutes: Int(totalDuration / 60),
                isSelected: isSelected,
                isToday: calendar.isDateInToday(date)
            )
        }
    }
    
    private var hourlyData: [HourData] {
        guard selectedTimeframe == .day else { return [] }
        
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
    
    private var averageDailyMinutes: Int {
        let totalMinutes = weekdayData.reduce(0) { $0 + $1.totalMinutes }
        return totalMinutes / max(1, weekdayData.filter { $0.totalMinutes > 0 }.count)
    }
    
    private var weeklyComparison: (Int, Bool)? {
        guard selectedTimeframe == .week else { return nil }
        
        // Compare with previous week - this is simplified and would need to be expanded
        // with actual previous week data
        let previousWeekTotal = Int.random(in: 400...600) // Placeholder for demo
        let currentWeekTotal = weekdayData.reduce(0) { $0 + $1.totalMinutes }
        let percentChange = ((Double(currentWeekTotal) / Double(previousWeekTotal)) - 1.0) * 100
        
        return (Int(abs(percentChange)), percentChange < 0)
    }
    
    private func formatDuration(_ minutes: Int) -> String {
        if minutes >= 60 {
            let hours = minutes / 60
            let mins = minutes % 60
            return "\(hours)h \(mins)m"
        } else {
            return "\(minutes)m"
        }
    }
    
    private func navigateDay(forward: Bool) {
        let calendar = Calendar.current
        if forward {
            selectedDate = calendar.date(byAdding: .day, value: 1, to: selectedDate) ?? selectedDate
        } else {
            selectedDate = calendar.date(byAdding: .day, value: -1, to: selectedDate) ?? selectedDate
        }
    }
    
    private func navigateWeek(forward: Bool) {
        let calendar = Calendar.current
        if forward {
            selectedDate = calendar.date(byAdding: .day, value: 7, to: selectedDate) ?? selectedDate
        } else {
            selectedDate = calendar.date(byAdding: .day, value: -7, to: selectedDate) ?? selectedDate
        }
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Title and navigation area
            HStack {
                Text("Focus Time")
                    .font(.title2)
                    .fontWeight(.bold)
                
                Spacer()
                
                Menu {
                    Button {
                        selectedTimeframe = .day
                        selectedDate = Date()
                    } label: {
                        HStack {
                            Text("Today, April 23")
                            if selectedTimeframe == .day {
                                Image(systemName: "checkmark")
                            }
                        }
                    }
                    
                    Button {
                        selectedTimeframe = .week
                    } label: {
                        HStack {
                            Text("This Week")
                            if selectedTimeframe == .week {
                                Image(systemName: "checkmark")
                            }
                        }
                    }
                } label: {
                    HStack {
                        Text(displayedDateString)
                        Image(systemName: "chevron.down")
                    }
                    .foregroundColor(.primary)
                }
            }
            
            // Total focus time display
            VStack(alignment: .leading, spacing: 4) {
                if selectedTimeframe == .day {
                    // Day total with sessions count
                    Text("\(Int(totalFocusTime / 60))")
                        .font(.system(size: 64, weight: .medium))
                    
                    HStack {
                        Text("Total minutes in focus")
                            .foregroundColor(.secondary)
                        Spacer()
                        Text("\(relevantSessions.count) sessions")
                            .foregroundColor(.secondary)
                    }
                } else {
                    // Week average per day
                    HStack(alignment: .firstTextBaseline) {
                        Text("\(weekdayData.reduce(0) { $0 + $1.totalMinutes } / 7)")
                            .font(.system(size: 64, weight: .medium))
                        Text("per day")
                            .font(.title3)
                            .foregroundColor(.secondary)
                            .padding(.leading, 4)
                    }
                    
                    if let (percentage, isDecrease) = weeklyComparison {
                        HStack {
                            Image(systemName: isDecrease ? "arrow.down" : "arrow.up")
                                .foregroundColor(isDecrease ? .red : .green)
                            Text("\(percentage) % from last week")
                                .foregroundColor(.secondary)
                        }
                    }
                }
            }
            
            // Navigation buttons
            HStack {
                Button(action: {
                    if selectedTimeframe == .day {
                        navigateDay(forward: false)
                    } else {
                        navigateWeek(forward: false)
                    }
                }) {
                    Image(systemName: "chevron.left")
                        .padding(8)
                        .background(Color.secondary.opacity(0.2))
                        .cornerRadius(8)
                }
                
                Button(action: {
                    selectedTimeframe = .day
                    selectedDate = Date()
                }) {
                    Text("Today")
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .background(Color.secondary.opacity(0.2))
                        .cornerRadius(8)
                }
                
                Button(action: {
                    if selectedTimeframe == .day {
                        navigateDay(forward: true)
                    } else {
                        navigateWeek(forward: true)
                    }
                }) {
                    Image(systemName: "chevron.right")
                        .padding(8)
                        .background(Color.secondary.opacity(0.2))
                        .cornerRadius(8)
                }
                
                Spacer()
            }
            
            // Weekly graph
            VStack(alignment: .leading, spacing: 8) {
                GroupBox {
                    VStack(alignment: .leading) {
                        HStack {
                            ForEach(weekdayData, id: \.weekdaySymbol) { dayData in
                                VStack(spacing: 4) {
                                    VStack {
                                        Spacer()
                                        Rectangle()
                                            .fill(dayData.isSelected ? Color.red :
                                                  (dayData.isToday ? Color.blue : Color.secondary.opacity(0.3)))
                                            .frame(height: CGFloat(dayData.totalMinutes) * 0.5)
                                            .frame(maxHeight: 100)
                                    }
                                    .frame(height: 120)
                                    .overlay(
                                        Rectangle()
                                            .stroke(Color.clear, lineWidth: 1)
                                    )
                                    .overlay(
                                        GeometryReader { geo in
                                            Path { path in
                                                path.move(to: CGPoint(x: 0, y: geo.size.height - CGFloat(averageDailyMinutes) * 0.5))
                                                path.addLine(to: CGPoint(x: geo.size.width, y: geo.size.height - CGFloat(averageDailyMinutes) * 0.5))
                                            }
                                            .stroke(Color.green, style: StrokeStyle(lineWidth: 1, dash: [5, 5]))
                                        }
                                    )
                                    
                                    Text(dayData.weekdaySymbol)
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                                .frame(maxWidth: .infinity)
                                .contentShape(Rectangle())
                                .onTapGesture {
                                    if selectedTimeframe == .week {
                                        selectedTimeframe = .day
                                        selectedDate = dayData.date
                                    }
                                }
                            }
                        }
                        
                        // This shows avg label on the right
                        HStack {
                            Spacer()
                            Text("avg")
                                .font(.caption)
                                .foregroundColor(.green)
                        }
                    }
                }
                
                // Hourly graph (only shown for day view)
                if selectedTimeframe == .day {
                    GroupBox {
                        VStack(alignment: .leading) {
                            HStack(alignment: .bottom, spacing: 2) {
                                ForEach(hourlyData) { hourData in
                                    if hourData.totalMinutes > 0 {
                                        Rectangle()
                                            .fill(Color.red)
                                            .frame(height: CGFloat(min(hourData.totalMinutes * 3, 20)))
                                    } else {
                                        Rectangle()
                                            .fill(Color.clear)
                                            .frame(height: 1)
                                    }
                                }
                                .frame(maxWidth: .infinity)
                            }
                            .frame(height: 40)
                            
                            HStack(spacing: 0) {
                                Text("00")
                                    .font(.caption2)
                                    .foregroundColor(.secondary)
                                
                                Spacer()
                                
                                Text("06")
                                    .font(.caption2)
                                    .foregroundColor(.secondary)
                                
                                Spacer()
                                
                                Text("12")
                                    .font(.caption2)
                                    .foregroundColor(.secondary)
                                
                                Spacer()
                                
                                Text("18")
                                    .font(.caption2)
                                    .foregroundColor(.secondary)
                                
                                Spacer()
                                
                                Text("23")
                                    .font(.caption2)
                                    .foregroundColor(.secondary)
                            }
                        }
                    }
                }
                
                // Total focus sessions
                HStack {
                    Text("Total Focus Sessions")
                        .font(.headline)
                    Spacer()
                    
                    Text("\(relevantSessions.count)")
                        .font(.headline)
                }
                .padding(.top, 8)
            }
            
            Spacer()
        }
        .padding()
    }
}

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

// Extension to integrate with the rest of your app
extension EnhancedInsightsView {
    // This function can be used to format time intervals consistently
    static func formatFocusTime(_ totalMinutes: Int) -> String {
        if totalMinutes >= 60 {
            let hours = totalMinutes / 60
            let mins = totalMinutes % 60
            if mins == 0 {
                return "\(hours)h"
            } else {
                return "\(hours)h \(mins)m"
            }
        } else {
            return "\(totalMinutes)m"
        }
    }
    
    // Helper to get the actual date string for display
    static func dateString(for date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "EEEE, MMMM d"
        return formatter.string(from: date)
    }
    
    // Helper to format week ranges for display
    static func weekRangeString(for date: Date) -> String {
        let calendar = Calendar.current
        
        // Find Monday of the current week
        let weekday = calendar.component(.weekday, from: date)
        let daysToMonday = ((weekday - 2) + 7) % 7
        guard let monday = calendar.date(byAdding: .day, value: -daysToMonday, to: date) else {
            return "This Week"
        }
        
        // Find Sunday
        guard let sunday = calendar.date(byAdding: .day, value: 6, to: monday) else {
            return "This Week"
        }
        
        // Format the date range
        let startFormatter = DateFormatter()
        let endFormatter = DateFormatter()
        
        startFormatter.dateFormat = "MMM d"
        endFormatter.dateFormat = "MMM d"
        
        return "\(startFormatter.string(from: monday)) - \(endFormatter.string(from: sunday))"
    }
}

// Extension to add more functionality to FocusManager for insights
extension FocusManager {
    // Get sessions for a specific date
    func sessionsForDate(_ date: Date) -> [FocusSession] {
        let calendar = Calendar.current
        return focusSessions.filter { session in
            calendar.isDate(session.startTime, inSameDayAs: date)
        }
    }
    
    // Get the most productive hour of the day
    func mostProductiveHour() -> Int? {
        let calendar = Calendar.current
        
        // Group all sessions by hour
        var hourlyTotals: [Int: TimeInterval] = [:]
        
        for session in focusSessions {
            let hour = calendar.component(.hour, from: session.startTime)
            hourlyTotals[hour, default: 0] += session.duration
        }
        
        // Find the hour with the maximum total duration
        return hourlyTotals.max(by: { $0.value < $1.value })?.key
    }
    
    // Get the most productive day of the week
    func mostProductiveDay() -> Int? {
        let calendar = Calendar.current
        
        // Group all sessions by weekday
        var dailyTotals: [Int: TimeInterval] = [:]
        
        for session in focusSessions {
            let weekday = calendar.component(.weekday, from: session.startTime)
            dailyTotals[weekday, default: 0] += session.duration
        }
        
        // Find the weekday with the maximum total duration
        return dailyTotals.max(by: { $0.value < $1.value })?.key
    }
    
    // Calculate weekly focus consistency (percentage of days with focus sessions)
    func weeklyConsistency() -> Double {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        
        // Get dates for the last 7 days
        var daysWithSessions = Set<Date>()
        var pastWeekDates = Set<Date>()
        
        for dayOffset in 0..<7 {
            if let date = calendar.date(byAdding: .day, value: -dayOffset, to: today) {
                let normalized = calendar.startOfDay(for: date)
                pastWeekDates.insert(normalized)
                
                // Check if there are any sessions on this day
                let hasSessions = focusSessions.contains { session in
                    calendar.isDate(session.startTime, inSameDayAs: normalized)
                }
                
                if hasSessions {
                    daysWithSessions.insert(normalized)
                }
            }
        }
        
        // Calculate consistency percentage
        return Double(daysWithSessions.count) / Double(pastWeekDates.count)
    }
    
    // Compare current week with previous week
    func weeklyComparison() -> (percentChange: Double, isIncrease: Bool) {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        
        // Current week (last 7 days)
        var currentWeekTotal: TimeInterval = 0
        if let weekAgo = calendar.date(byAdding: .day, value: -7, to: today) {
            currentWeekTotal = focusSessions
                .filter { $0.startTime >= weekAgo && $0.startTime <= today }
                .reduce(0) { $0 + $1.duration }
        }
        
        // Previous week (8-14 days ago)
        var previousWeekTotal: TimeInterval = 0
        if let twoWeeksAgo = calendar.date(byAdding: .day, value: -14, to: today),
           let weekAgo = calendar.date(byAdding: .day, value: -7, to: today) {
            previousWeekTotal = focusSessions
                .filter { $0.startTime >= twoWeeksAgo && $0.startTime < weekAgo }
                .reduce(0) { $0 + $1.duration }
        }
        
        // Calculate percent change
        if previousWeekTotal > 0 {
            let percentChange = ((currentWeekTotal / previousWeekTotal) - 1.0) * 100
            return (abs(percentChange), percentChange >= 0)
        } else if currentWeekTotal > 0 {
            // If previous week was 0, but current week has data
            return (100, true)
        } else {
            // No change
            return (0, true)
        }
    }
}

#Preview {
    EnhancedInsightsView()
        .environmentObject(FocusManager())
}

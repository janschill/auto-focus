import SwiftUI
import Charts

struct InsightsView: View {
    @EnvironmentObject var focusManager: FocusManager
    @EnvironmentObject var licenseManager: LicenseManager
    @State private var selectedTimeframe: Timeframe = .day
    
    enum Timeframe: String, CaseIterable {
        case day = "Today"
        case week = "This Week"
        case month = "This Month"
    }
    
    struct ChartData: Identifiable {
        let id = UUID()
        let label: String
        let value: TimeInterval
        let count: Int
    }
    
    struct FocusMetrics {
        let sessionCount: Int
        let longestSession: TimeInterval
        let averageSession: TimeInterval
        let totalFocusTime: TimeInterval
    }
    
    var filteredSessions: [FocusSession] {
        let calendar = Calendar.current
        let now = Date()
        
        switch selectedTimeframe {
        case .day:
            return focusManager.focusSessions.filter {
                calendar.isDate($0.startTime, inSameDayAs: now)
            }
            
        case .week:
            let weekStart = calendar.date(byAdding: .day, value: -7, to: now)!
            return focusManager.focusSessions.filter {
                $0.startTime >= weekStart && $0.startTime <= now
            }
            
        case .month:
            let monthStart = calendar.date(byAdding: .month, value: -1, to: now)!
            return focusManager.focusSessions.filter {
                $0.startTime >= monthStart && $0.startTime <= now
            }
        }
    }
    
    var chartData: [ChartData] {
        let calendar = Calendar.current
        let now = Date()
        
        switch selectedTimeframe {
        case .day:
            // Show all 24 hours
            return (0..<24).map { hour in
                let hourSessions = filteredSessions.filter {
                    calendar.component(.hour, from: $0.startTime) == hour
                }
                let totalDuration = hourSessions.reduce(0) { $0 + $1.duration }
                return ChartData(
                    label: String(format: "%02d", hour),
                    value: totalDuration,
                    count: hourSessions.count
                )
            }
            
        case .week:
            // Show all 7 days of the week
            return (1...7).map { weekday in
                let weekdaySessions = filteredSessions.filter {
                    calendar.component(.weekday, from: $0.startTime) == weekday
                }
                let totalDuration = weekdaySessions.reduce(0) { $0 + $1.duration }
                let weekdaySymbol = calendar.shortWeekdaySymbols[weekday - 1]
                return ChartData(
                    label: weekdaySymbol,
                    value: totalDuration,
                    count: weekdaySessions.count
                )
            }
            
        case .month:
            // Show all days in the current month
            let monthStart = calendar.date(from: calendar.dateComponents([.year, .month], from: now))!
            let daysInMonth = calendar.range(of: .day, in: .month, for: now)?.count ?? 30
            
            return (1...daysInMonth).map { day in
                let components = calendar.dateComponents([.year, .month], from: now)
                var dayComponents = DateComponents()
                dayComponents.year = components.year
                dayComponents.month = components.month
                dayComponents.day = day
                
                guard let date = calendar.date(from: dayComponents) else {
                    return ChartData(label: "\(day)", value: 0, count: 0)
                }
                
                let daySessions = filteredSessions.filter {
                    calendar.component(.day, from: $0.startTime) == day &&
                    calendar.component(.month, from: $0.startTime) == calendar.component(.month, from: date) &&
                    calendar.component(.year, from: $0.startTime) == calendar.component(.year, from: date)
                }
                
                let totalDuration = daySessions.reduce(0) { $0 + $1.duration }
                return ChartData(
                    label: "\(day)",
                    value: totalDuration,
                    count: daySessions.count
                )
            }
        }
    }
    
    var metrics: FocusMetrics {
        // Calculate metrics based on filtered sessions
        let sessions = filteredSessions
        
        // Only consider sessions that lasted at least 30 seconds
        let validSessions = sessions.filter { $0.duration >= 30 }
        
        let sessionCount = validSessions.count
        let longestSession = validSessions.max(by: { $0.duration < $1.duration })?.duration ?? 0
        let totalFocusTime = validSessions.reduce(0) { $0 + $1.duration }
        let averageSession = sessionCount > 0 ? totalFocusTime / Double(sessionCount) : 0
        
        return FocusMetrics(
            sessionCount: sessionCount,
            longestSession: longestSession,
            averageSession: averageSession,
            totalFocusTime: totalFocusTime
        )
    }
    
    // Analyze all sessions to find most productive hour range
    var productiveTimeRange: (startHour: Int, endHour: Int, duration: TimeInterval)? {
        // Use all sessions, not just filtered ones
        let allSessions = focusManager.focusSessions
        
        // Group by hour and find the most productive consecutive hours
        let calendar = Calendar.current
        let hourlyData = Dictionary(grouping: allSessions) { session in
            calendar.component(.hour, from: session.startTime)
        }
        
        let hourlyTotals = (0..<24).map { hour in
            let sessions = hourlyData[hour] ?? []
            let totalDuration = sessions.reduce(0) { $0 + $1.duration }
            return (hour: hour, duration: totalDuration)
        }
        
        // Find the most productive consecutive 2-hour block
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
    
    // Most productive day of week (using all data)
    var productiveWeekday: (weekday: Int, duration: TimeInterval)? {
        // Use all sessions, not just filtered ones
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
    
    // Calculate distraction metrics - patterns when focus is broken
    var distractionPatterns: [(hour: Int, count: Int)] {
        // Use all sessions to find patterns
        let calendar = Calendar.current
        let sortedSessions = focusManager.focusSessions.sorted(by: { $0.startTime < $1.startTime })
        
        var distractionsByHour: [Int: Int] = [:]
        
        for i in 0..<(sortedSessions.count - 1) {
            let currentSession = sortedSessions[i]
            let nextSession = sortedSessions[i + 1]
            
            // Only count if less than 4 hours apart (might be same work period)
            let timeBetween = nextSession.startTime.timeIntervalSince(currentSession.endTime)
            
            // Only count breaks between 1 minute and 4 hours as distractions
            if timeBetween > 60 && timeBetween < 14400 {
                let hour = calendar.component(.hour, from: currentSession.endTime)
                distractionsByHour[hour, default: 0] += 1
            }
        }
        
        // Convert to array and sort by hour
        return (0..<24).map { hour in
            (hour: hour, count: distractionsByHour[hour] ?? 0)
        }
    }
    
    // Weekly consistency (average focus time per weekday)
    // This doesn't change with the time filter - always shows a full week
    var weekdayAverages: [(day: String, average: TimeInterval)] {
        let calendar = Calendar.current
        let allSessions = focusManager.focusSessions
        
        // Group all sessions by weekday
        let weekdayData = Dictionary(grouping: allSessions) { session in
            calendar.component(.weekday, from: session.startTime)
        }
        
        // Calculate average per weekday
        return (1...7).map { weekday in
            let symbol = calendar.shortWeekdaySymbols[weekday - 1]
            let sessions = weekdayData[weekday] ?? []
            
            // Group by unique days to calculate meaningful average
            let sessionsByDay = Dictionary(grouping: sessions) { session in
                calendar.startOfDay(for: session.startTime)
            }
            
            // Sum up total duration for each day, then average across days
            let dailyTotals = sessionsByDay.values.map { daySessions in
                daySessions.reduce(0) { $0 + $1.duration }
            }
            
            let average = dailyTotals.isEmpty ? 0 : dailyTotals.reduce(0, +) / Double(dailyTotals.count)
            
            return (day: symbol, average: average)
        }
    }
    
    private func formatDuration(_ duration: TimeInterval) -> String {
        let hours = Int(duration) / 3600
        let minutes = Int(duration) / 60 % 60
        
        if hours > 0 {
            return String(format: "%dh %dm", hours, minutes)
        } else {
            return String(format: "%dm", minutes)
        }
    }
    
    private func formatHour(_ hour: Int) -> String {
        let isAM = hour < 12
        let displayHour = hour == 0 ? 12 : (hour > 12 ? hour - 12 : hour)
        return "\(displayHour) \(isAM ? "AM" : "PM")"
    }
    
    var body: some View {
        VStack(spacing: 16) {
            HStack {
                Picker("Timeframe", selection: $selectedTimeframe) {
                    ForEach(Timeframe.allCases, id: \.self) { timeframe in
                        Text(timeframe.rawValue).tag(timeframe)
                    }
                }
                .pickerStyle(.segmented)
                .disabled(!licenseManager.isLicensed && selectedTimeframe != .day)
                
                Spacer()
            }
            .padding(.horizontal)
            
            ScrollView {
                if !licenseManager.isLicensed && selectedTimeframe != .day {
                    // Show premium upgrade prompt for locked timeframes
                    PremiumUpgradeView()
                } else {
                    VStack(spacing: 24) {
                        // Core metrics
                        HStack(spacing: 16) {
                            MetricCard(
                                title: "Focus Sessions",
                                value: "\(metrics.sessionCount)"
                            )
                            
                            MetricCard(
                                title: "Longest Session",
                                value: formatDuration(metrics.longestSession)
                            )
                            
                            MetricCard(
                                title: "Average Session",
                                value: formatDuration(metrics.averageSession)
                            )
                            
                            MetricCard(
                                title: "Total Focus Time",
                                value: formatDuration(metrics.totalFocusTime)
                            )
                        }
                        
                        // Focus time distribution chart
                        GroupBox("Focus Time Distribution") {
                            Chart {
                                ForEach(chartData) { item in
                                    BarMark(
                                        x: .value("Time", item.label),
                                        y: .value("Duration", item.value / 60.0) // Convert to minutes
                                    )
                                    .foregroundStyle(.blue.opacity(0.8))
                                    .annotation(position: .top) {
                                        if item.count > 0 {
                                            Text("\(item.count)")
                                                .font(.system(size: 8))
                                                .foregroundColor(.secondary)
                                        }
                                    }
                                }
                            }
                            .frame(height: 200)
                            .padding()
                        }
                        
                        // Premium advanced analytics
                        if licenseManager.isLicensed {
                            AdvancedAnalyticsView(
                                productiveTimeRange: productiveTimeRange,
                                productiveWeekday: productiveWeekday,
                                weekdayAverages: weekdayAverages,
                                distractionPatterns: distractionPatterns
                            )
                        }
                    }
                    .padding()
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(.top)
        .onChange(of: selectedTimeframe) { newValue in
            // If user is not premium and selects a premium timeframe, switch back to day
            if !licenseManager.isLicensed && newValue != .day {
                // We don't immediately switch back to avoid a confusing UX
                // Instead, we show the upgrade prompt in the content area
            }
        }
    }
}

struct AdvancedAnalyticsView: View {
    let productiveTimeRange: (startHour: Int, endHour: Int, duration: TimeInterval)?
    let productiveWeekday: (weekday: Int, duration: TimeInterval)?
    let weekdayAverages: [(day: String, average: TimeInterval)]
    let distractionPatterns: [(hour: Int, count: Int)]
    
    private func formatHourRange(_ startHour: Int, _ endHour: Int) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "h a"
        
        // Create date components for the hours
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
    
    private func formatDuration(_ duration: TimeInterval) -> String {
        let hours = Int(duration) / 3600
        let minutes = Int(duration) / 60 % 60
        
        if hours > 0 {
            return String(format: "%dh %dm", hours, minutes)
        } else {
            return String(format: "%dm", minutes)
        }
    }
    
    var body: some View {
        VStack(spacing: 20) {
            // Productivity insights
            GroupBox("Productivity Insights") {
                VStack(alignment: .leading, spacing: 16) {
                    HStack(spacing: 24) {
                        VStack(alignment: .leading) {
                            Text("Most Productive Time")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                            if let timeRange = productiveTimeRange {
                                Text(formatHourRange(timeRange.startHour, timeRange.endHour))
                                    .font(.title3)
                                    .fontWeight(.medium)
                            } else {
                                Text("Not enough data")
                                    .font(.callout)
                                    .foregroundColor(.secondary)
                            }
                        }
                        
                        VStack(alignment: .leading) {
                            Text("Most Productive Day")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                            if let weekday = productiveWeekday {
                                let calendar = Calendar.current
                                let weekdaySymbol = calendar.weekdaySymbols[weekday.weekday - 1]
                                Text(weekdaySymbol)
                                    .font(.title3)
                                    .fontWeight(.medium)
                            } else {
                                Text("Not enough data")
                                    .font(.callout)
                                    .foregroundColor(.secondary)
                            }
                        }
                    }
                }
                .padding()
            }
            
            // Weekly consistency (average time per weekday)
            GroupBox("Weekly Consistency") {
                VStack(alignment: .leading, spacing: 12) {
                    Text("Average focus time per weekday")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    
                    HStack(alignment: .bottom, spacing: 6) {
                        ForEach(weekdayAverages, id: \.day) { day in
                            VStack(spacing: 4) {
                                // Show bar for each weekday
                                ZStack(alignment: .bottom) {
                                    Rectangle()
                                        .fill(Color.gray.opacity(0.1))
                                        .frame(width: 30, height: 80)
                                    
                                    Rectangle()
                                        .fill(Color.blue.opacity(0.7))
                                        .frame(width: 30, height: day.average > 0 ? min(80, 80 * day.average / 14400) : 0) // Max height at 4 hours
                                }
                                
                                Text(day.day)
                                    .font(.caption2)
                                    .foregroundColor(.secondary)
                                
                                Text(day.average > 0 ? formatDuration(day.average) : "-")
                                    .font(.system(size: 8))
                                    .foregroundColor(.secondary)
                            }
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 8)
                }
                .padding()
            }
            
            // Distraction patterns
            GroupBox("Distraction Patterns") {
                VStack(alignment: .leading, spacing: 12) {
                    Text("When you're most likely to get distracted")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    
                    Text("The chart shows times when your focus is typically broken.")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    Chart {
                        ForEach(distractionPatterns.filter { $0.count > 0 }, id: \.hour) { item in
                            BarMark(
                                x: .value("Hour", "\(item.hour)"),
                                y: .value("Count", item.count)
                            )
                            .foregroundStyle(.red.opacity(0.7))
                        }
                    }
                    .frame(height: 120)
                    .padding(.top, 8)
                }
                .padding()
            }
        }
    }
}

struct PremiumUpgradeView: View {
    @EnvironmentObject var licenseManager: LicenseManager
    
    var body: some View {
        VStack(spacing: 24) {
            Image(systemName: "chart.line.uptrend.xyaxis")
                .font(.system(size: 48))
                .foregroundColor(.blue.opacity(0.8))
                .padding()
            
            Text("Unlock Advanced Insights")
                .font(.title2)
                .fontWeight(.bold)
            
            Text("Upgrade to Premium to access weekly and monthly focus analytics, productivity patterns, and detailed session insights.")
                .multilineTextAlignment(.center)
                .foregroundColor(.secondary)
                .padding(.horizontal)
            
            Button("Upgrade to Premium") {
                // Use TabView selection binding to switch to Premium tab
                // This would need a more complex implementation with shared state
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            .padding(.top)
        }
        .padding(40)
        .background(Color.secondary.opacity(0.05))
        .cornerRadius(16)
        .padding()
    }
}

struct MetricCard: View {
    let title: String
    let value: String
    
    var body: some View {
        GroupBox {
            VStack(alignment: .leading, spacing: 8) {
                Text(title)
                    .font(.caption)
                    .foregroundColor(.secondary)
                Text(value)
                    .font(.title2)
                    .fontWeight(.semibold)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.vertical, 8)
        }
    }
}

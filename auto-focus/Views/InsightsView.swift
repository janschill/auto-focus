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
    }
    
    var filteredData: [ChartData] {
        let calendar = Calendar.current
        let now = Date()
        
        switch selectedTimeframe {
        case .day:
            return (0..<24).map { hour in
                let hourSessions = focusManager.focusSessions.filter {
                    calendar.isDate($0.startTime, inSameDayAs: now) &&
                    calendar.component(.hour, from: $0.startTime) == hour
                }
                let totalDuration = hourSessions.reduce(0) { $0 + $1.duration }
                return ChartData(
                    label: String(format: "%02d", hour),
                    value: totalDuration
                )
            }
            
        case .week:
            // Premium only - non-premium users will see empty data
            if !licenseManager.isLicensed {
                return []
            }
            
            let today = calendar.startOfDay(for: now)
            let currentWeekday = calendar.component(.weekday, from: today)
            let daysToMonday = ((currentWeekday - 2) + 7) % 7
            let monday = calendar.date(byAdding: .day, value: -daysToMonday, to: today)!
            
            return (0..<7).map { dayOffset in
                let date = calendar.date(byAdding: .day, value: dayOffset, to: monday)!
                let daySessions = focusManager.focusSessions.filter {
                    calendar.isDate($0.startTime, inSameDayAs: date)
                }
                let totalDuration = daySessions.reduce(0) { $0 + $1.duration }
                let weekday = calendar.component(.weekday, from: date)
                let weekdaySymbol = calendar.shortWeekdaySymbols[weekday - 1]
                return ChartData(
                    label: weekdaySymbol,
                    value: totalDuration
                )
            }
            
        case .month:
            // Premium only - non-premium users will see empty data
            if !licenseManager.isLicensed {
                return []
            }
            
            let monthStart = calendar.date(from: calendar.dateComponents([.year, .month], from: now))!
            let numberOfDays = calendar.range(of: .day, in: .month, for: now)?.count ?? 30
            let monthDates = (0..<numberOfDays).compactMap { calendar.date(byAdding: .day, value: $0, to: monthStart) }
            
            return monthDates.map { date in
                let daySessions = focusManager.focusSessions.filter {
                    calendar.isDate($0.startTime, inSameDayAs: date)
                }
                let totalDuration = daySessions.reduce(0) { $0 + $1.duration }
                return ChartData(
                    label: "\(calendar.component(.day, from: date))",
                    value: totalDuration
                )
            }
        }
    }
    
    var totalFocusTime: TimeInterval {
        filteredData.reduce(0) { $0 + $1.value }
    }
    
    var averageSessionDuration: TimeInterval {
        guard !filteredData.isEmpty else { return 0 }
        return totalFocusTime / Double(filteredData.count)
    }
    
    var longestSession: TimeInterval {
        filteredData.map { $0.value }.max() ?? 0
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
                        HStack(spacing: 16) {
                            MetricCard(
                                title: "Total Focus Time",
                                value: formatDuration(totalFocusTime)
                            )
                            
                            MetricCard(
                                title: "Average Session",
                                value: formatDuration(averageSessionDuration)
                            )
                            
                            MetricCard(
                                title: "Longest Session",
                                value: formatDuration(longestSession)
                            )
                        }
                        
                        GroupBox("Focus Time Distribution") {
                            Chart {
                                ForEach(filteredData) { item in
                                    BarMark(
                                        x: .value("Time", item.label),
                                        y: .value("Duration", item.value / 60.0) // Convert to minutes
                                    )
                                    .foregroundStyle(.blue.opacity(0.8))
                                }
                            }
                            .frame(height: 200)
                            .padding()
                        }
                        
                        // Premium advanced analytics
                        if licenseManager.isLicensed {
                            AdvancedAnalyticsView()
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
    @EnvironmentObject var focusManager: FocusManager
    
    var body: some View {
        GroupBox("Focus Pattern Analysis") {
            VStack(alignment: .leading, spacing: 16) {
                Text("Advanced Insights")
                    .font(.headline)
                
                HStack(spacing: 24) {
                    VStack(alignment: .leading) {
                        Text("Most Productive Time")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                        Text("2:00 PM - 4:00 PM")
                            .font(.title3)
                            .fontWeight(.medium)
                    }
                    
                    VStack(alignment: .leading) {
                        Text("Most Productive Day")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                        Text("Tuesday")
                            .font(.title3)
                            .fontWeight(.medium)
                    }
                }
                
                Divider()
                
                Text("Focus Consistency")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .padding(.top, 4)
                
                HStack(spacing: 6) {
                    ForEach(0..<7) { day in
                        VStack(spacing: 4) {
                            // Simulated focus score for each day
                            RoundedRectangle(cornerRadius: 2)
                                .fill(Color.blue.opacity(0.2 + Double.random(in: 0...0.8)))
                                .frame(width: 30, height: 60 * Double.random(in: 0.3...1.0))
                            
                            Text(Calendar.current.veryShortWeekdaySymbols[day])
                                .font(.caption2)
                                .foregroundColor(.secondary)
                        }
                    }
                }
                .padding(.vertical, 8)
            }
            .padding()
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

#Preview {
    InsightsView()
        .environmentObject(FocusManager())
        .environmentObject(LicenseManager())
}

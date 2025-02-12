import SwiftUI
import Charts

struct InsightsView: View {
    @EnvironmentObject var focusManager: FocusManager
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
                
                Spacer()
            }
            .padding(.horizontal)
            
            ScrollView {
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
                }
                .padding()
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(.top)
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

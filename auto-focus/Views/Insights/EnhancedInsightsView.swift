import SwiftUI
import Charts

struct InsightsGraphsContainerView: View {
    @EnvironmentObject var dataProvider: InsightsViewModel
    
    var body: some View {
        GroupBox {
            VStack(alignment: .leading, spacing: 12) {
                WeeklyBarChartView()
                
                if dataProvider.selectedTimeframe == .day {
                    HourlyBarChartView()
                }
            }
        }
    }
}

struct WeeklyBarChartView: View {
    @EnvironmentObject var dataProvider: InsightsViewModel
    var body: some View {
        VStack(alignment: .leading) {
            Chart {
                ForEach(dataProvider.weekdayData, id: \.weekdaySymbol) { dayData in
                    BarMark(
                        x: .value("Day", dayData.weekdaySymbol),
                        y: .value("Minutes", dayData.totalMinutes)
                    )
                    .foregroundStyle(dayData.isSelected ? Color.blue : Color.blue.opacity(0.3))
                }
                
                RuleMark(y: .value("Average", dataProvider.averageDailyMinutes))
                    .foregroundStyle(Color.green)
                    .lineStyle(StrokeStyle(lineWidth: 1, dash: [5, 5]))
                    .annotation(position: .trailing) {
                        Text("avg")
                            .font(.caption)
                            .foregroundColor(.green)
                    }
            }
            .frame(height: 120)
            .chartYScale(domain: 0...(dataProvider.weekdayData.map { Double($0.totalMinutes) }.max() ?? 0) * 1.2)
        }
    }
}

struct HourlyBarChartView: View {
    @EnvironmentObject var dataProvider: InsightsViewModel
    
    var body: some View {
        VStack(alignment: .leading) {
            Chart {
                ForEach(dataProvider.hourlyData) { hourData in
                    if hourData.totalMinutes > 0 {
                        BarMark(
                            x: .value("Hour", hourData.hour),
                            y: .value("Minutes", hourData.totalMinutes)
                        )
                        .foregroundStyle(Color.blue)
                    }
                }
            }
            .chartXAxis {
                AxisMarks(values: [0, 6, 12, 18, 23]) { value in
                    AxisValueLabel {
                        if let hour = value.as(Int.self) {
                            Text(String(format: "%02d", hour))
                                .font(.caption2)
                                .foregroundColor(.secondary)
                        }
                    }
                }
            }
            .frame(height: 60)
        }
    }
}

struct EnhancedInsightsView: View {
    @EnvironmentObject var focusManager: FocusManager
    @StateObject private var dataProvider: InsightsViewModel
    
    init() {
        // Note: We're using StateObject with a custom initializer
        // The actual FocusManager will be injected via EnvironmentObject
        _dataProvider = StateObject(wrappedValue: InsightsViewModel(dataProvider: InsightsDataProvider(focusManager: FocusManager())))
    }
    
    var body: some View {
        VStack {
            GroupBox {
                VStack(alignment: .leading, spacing: 8) {
                    InsightsHeaderView()
                    
                    FocusTimeOverviewView()
                    
                    InsightsGraphsContainerView()
                }
                .padding(8)
            }
            
            HStack {
                Text("Total Focus Sessions")
                    .font(.headline)
                Spacer()
                
                Text("\(dataProvider.relevantSessions.count)")
                    .font(.headline)
            }
            .padding(.top, 8)
            
            Spacer()
        }
        .padding()
        .environmentObject(dataProvider)
        .onAppear {
            dataProvider.updateFocusManager(focusManager)
        }
    }
}

struct InsightsHeaderView: View {
    @EnvironmentObject var dataProvider: InsightsViewModel

    var body: some View {
        HStack {
            Text("Usage")
                .font(.title3)
            
            Spacer()
            
            Menu {
                Text ("Show Usage")
                Button {
                    dataProvider.selectedTimeframe = .day
                    dataProvider.selectedDate = Date()
                } label: {
                    HStack {
                        Text("Today")
                        if dataProvider.selectedTimeframe == .day {
                            Image(systemName: "checkmark")
                        }
                    }
                }
                Button {
                    dataProvider.selectedTimeframe = .week
                } label: {
                    HStack {
                        Text("Last Week")
                        if dataProvider.selectedTimeframe == .week {
                            Image(systemName: "checkmark")
                        }
                    }
                }
            } label: {
                HStack(spacing: 4) {
                    Text(dataProvider.displayedDateString)
                }
                .padding(.horizontal, 8)
            }
            .foregroundColor(.primary)
            .frame(maxWidth: 160)
            
            DateNavigationView()
        }
    }
}


struct DateNavigationView: View {
    @EnvironmentObject var dataProvider: InsightsViewModel
    
    var body: some View {
        HStack(spacing: 4) {
            Button(action: {
                if dataProvider.selectedTimeframe == .day {
                    dataProvider.navigateDay(forward: false)
                } else {
                    dataProvider.navigateWeek(forward: false)
                }
            }) {
                Image(systemName: "chevron.left")
                    .cornerRadius(8).font(.body)
            }
            
            Button(action: {
                dataProvider.goToToday()
            }) {
                Text("Today").font(.body)
                    .cornerRadius(8)
            }
            
            Button(action: {
                if dataProvider.selectedTimeframe == .day {
                    dataProvider.navigateDay(forward: true)
                } else {
                    dataProvider.navigateWeek(forward: true)
                }
            }) {
                Image(systemName: "chevron.right")
                    .cornerRadius(8).font(.body)
            }
            .disabled(dataProvider.selectedTimeframe == .day && Calendar.current.isDateInToday(dataProvider.selectedDate))
        }
    }
}

struct FocusTimeOverviewView: View {
    @EnvironmentObject var dataProvider: InsightsViewModel
    
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            if dataProvider.selectedTimeframe == .day {
                Text("\(Int(dataProvider.totalFocusTime / 60)) m")
                    .font(.system(size: 32, weight: .medium))
                
                HStack {
                    Text("Total time in focus")
                        .foregroundColor(.secondary)
                    
                    Spacer()
                    
                    Text("\(dataProvider.relevantSessions.count) sessions")
                        .foregroundColor(.secondary)
                }
            } else {
                HStack(alignment: .firstTextBaseline) {
                    Text("\(dataProvider.weekdayData.reduce(0) { $0 + $1.totalMinutes } / 7) m")
                        .font(.system(size: 32, weight: .medium))
                    Text("per day")
                        .font(.title3)
                        .foregroundColor(.secondary)
                        .padding(.leading, 4)
                }
            }
        }
    }
}

#Preview {
    EnhancedInsightsView()
        .environmentObject(FocusManager())
        .frame(width: 600, height: 900)
}

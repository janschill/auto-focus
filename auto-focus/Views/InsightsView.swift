import Charts
import SwiftUI

struct InsightsGraphsContainerView: View {
    @ObservedObject var dataProvider: InsightsViewModel

    var body: some View {
        GroupBox {
            VStack(alignment: .leading, spacing: 12) {
                WeeklyBarChartView(dataProvider: dataProvider)

                if dataProvider.selectedTimeframe == .day {
                    HourlyBarChartView(dataProvider: dataProvider)
                }
            }
        }
    }
}

struct WeeklyBarChartView: View {
    @ObservedObject var dataProvider: InsightsViewModel

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
    @ObservedObject var dataProvider: InsightsViewModel

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

struct InsightsHeaderView: View {
    @ObservedObject var dataProvider: InsightsViewModel

    var body: some View {
        HStack {
            let title = dataProvider.selectedTimeframe == .day ? "Usage" : "Daily Average"
            Text(title)
                .font(.title3)
            Spacer()

            Menu(content: {
                Text("Show Usage")
                Button(action: {
                    dataProvider.selectedTimeframe = .day
                    dataProvider.selectedDate = Date()
                }, label: {
                    HStack {
                        Text("Today")
                        if dataProvider.selectedTimeframe == .day {
                            Image(systemName: "checkmark")
                        }
                    }
                })
                Button(action: {
                    dataProvider.selectedTimeframe = .week
                }, label: {
                    HStack {
                        Text("This Week")
                        if dataProvider.selectedTimeframe == .week {
                            Image(systemName: "checkmark")
                        }
                    }
                })
            }, label: {
                HStack(spacing: 4) {
                    Text(dataProvider.displayedDateString)
                        .lineLimit(1)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .padding(.horizontal, 8)
            })
            .foregroundColor(.primary)

            DateNavigationView(dataProvider: dataProvider)
        }
    }
}

struct DateNavigationView: View {
    @ObservedObject var dataProvider: InsightsViewModel

    var body: some View {
        HStack(spacing: 4) {
            Button(action: {
                if dataProvider.selectedTimeframe == .day {
                    dataProvider.navigateDay(forward: false)
                } else {
                    dataProvider.navigateWeek(forward: false)
                }
            }, label: {
                Image(systemName: "chevron.left")
            })

            Button(action: {
                dataProvider.goToToday()
            }, label: {
                Text("Today")
            })

            Button(action: {
                if dataProvider.selectedTimeframe == .day {
                    dataProvider.navigateDay(forward: true)
                } else {
                    dataProvider.navigateWeek(forward: true)
                }
            }, label: {
                Image(systemName: "chevron.right")
            })
            .disabled(Calendar.current.isDateInToday(dataProvider.selectedDate))
        }
    }
}

struct FocusTimeOverviewView: View {
    @ObservedObject var dataProvider: InsightsViewModel

    var body: some View {
        HStack {
            let time = dataProvider.selectedTimeframe == .day ? Int(dataProvider.totalFocusTime / 60) : dataProvider.averageDailyMinutes

            Text(TimeFormatter.duration(time))
                .font(.system(size: 32, weight: .medium))

            if dataProvider.selectedTimeframe == .week {
                Spacer()

                if let change = dataProvider.weekComparisonPercentage {
                    let trendImage = change >= 0 ? "arrow.up" : "arrow.down"
                    let trendText = change >= 0 ? "\(change) %" : "\(-change) %"
                    Image(systemName: trendImage + ".circle.fill")
                        .foregroundColor(.secondary)
                        .fontWeight(.heavy)
                    Text(trendText + " last week")
                        .foregroundColor(.secondary)
                }
            }
        }
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
            .padding(.horizontal, 8)
        }
    }
}

struct ProductivityMetricsView: View {
    @ObservedObject var dataProvider: InsightsViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(spacing: 16) {
                if let timeRange = dataProvider.productiveTimeRange {
                    MetricCard(
                        title: "Most Productive Time",
                        value: dataProvider.formatHourRange(timeRange.startHour, timeRange.endHour)
                    )
                } else {
                    MetricCard(
                        title: "Most Productive Time",
                        value: "Not enough data"
                    )
                }

                if let weekday = dataProvider.productiveWeekday {
                    let calendar = Calendar.current
                    let weekdaySymbol = calendar.weekdaySymbols[weekday.weekday - 1]
                    MetricCard(
                        title: "Most Productive Day",
                        value: weekdaySymbol
                    )
                } else {
                    MetricCard(
                        title: "Most Productive Day",
                        value: "Not enough data"
                    )
                }
            }

            GroupBox("Weekly Consistency") {
                VStack(alignment: .leading, spacing: 12) {
                    let maxValue = dataProvider.weekdayAverages.map { $0.average / 60 }.max() ?? 60

                    let rearrangedData = dataProvider.rearrangeWeekdaysStartingMonday(dataProvider.weekdayAverages)

                    let normalizedData = rearrangedData.map { day -> (day: String, value: Double, empty: Double) in
                        let value = day.average / 60
                        return (day: day.day, value: value / maxValue, empty: (maxValue - value) / maxValue)
                    }
                    ZStack(alignment: .top) {
                        Chart {
                            ForEach(normalizedData, id: \.day) { item in
                                BarMark(
                                    x: .value("Day", item.day),
                                    y: .value("Value", item.value),
                                    stacking: .normalized
                                )
                                .foregroundStyle(Color.blue.opacity(0.7))

                                BarMark(
                                    x: .value("Day", item.day),
                                    y: .value("Empty", item.empty),
                                    stacking: .normalized
                                )
                                .foregroundStyle(Color.gray.opacity(0.1))
                            }
                        }
                        .chartYAxis {
                            AxisMarks(values: [0, 0.25, 0.5, 0.75, 1.0]) { _ in
                                AxisGridLine()
                                AxisTick()
                            }
                        }

                        VStack {
                            Spacer().frame(height: 8)
                            HStack(alignment: .top, spacing: 0) {
                                ForEach(rearrangedData.indices, id: \.self) { index in
                                    let day = rearrangedData[index]
                                    let minutes = Int(day.average / 60)

                                    VStack {
                                        Text("\(TimeFormatter.duration(minutes))")
                                            .font(.caption2)
                                            .foregroundColor(.primary)
                                        Spacer()
                                    }
                                    .frame(maxWidth: .infinity)
                                }
                            }
                            Spacer()
                        }
                    }
                    .frame(height: 120)
                }
                .padding(4)
            }
        }
    }
}

// MARK: - Activity Breakdown

struct ActivityBreakdownView: View {
    @ObservedObject var dataProvider: InsightsViewModel
    @EnvironmentObject var focusManager: FocusManager

    var body: some View {
        let apps = dataProvider.topApps
        let domains = dataProvider.topDomains

        if apps.isEmpty && domains.isEmpty {
            EmptyView()
        } else {
            GroupBox("Activity Breakdown") {
                VStack(alignment: .leading, spacing: 16) {
                    if !apps.isEmpty {
                        appSection(apps: apps)
                    }
                    if !domains.isEmpty {
                        domainSection(domains: domains)
                    }
                }
                .padding(4)
            }
        }
    }

    private func appSection(apps: [AppUsageSummary]) -> some View {
        let maxDuration = apps.first?.totalDuration ?? 1
        let focusBundleIDs = Set(focusManager.focusApps.map(\.bundleIdentifier))

        return VStack(alignment: .leading, spacing: 6) {
            Text("Apps")
                .font(.subheadline)
                .foregroundColor(.secondary)

            ForEach(apps, id: \.bundleIdentifier) { app in
                HStack(spacing: 8) {
                    if focusBundleIDs.contains(app.bundleIdentifier) {
                        Circle()
                            .fill(Color.blue)
                            .frame(width: 6, height: 6)
                    } else {
                        Spacer().frame(width: 6)
                    }

                    Text(app.appName ?? app.bundleIdentifier)
                        .font(.callout)
                        .frame(width: 120, alignment: .leading)
                        .lineLimit(1)

                    GeometryReader { geo in
                        RoundedRectangle(cornerRadius: 3)
                            .fill(Color.blue.opacity(0.5))
                            .frame(width: max(4, geo.size.width * CGFloat(app.totalDuration / maxDuration)))
                    }
                    .frame(height: 14)

                    Text(TimeFormatter.duration(Int(app.totalDuration / 60)))
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .frame(width: 50, alignment: .trailing)
                }
            }
        }
    }

    private func domainSection(domains: [DomainUsageSummary]) -> some View {
        let maxDuration = domains.first?.totalDuration ?? 1
        let focusDomains = focusManager.focusURLs

        return VStack(alignment: .leading, spacing: 6) {
            Text("Websites")
                .font(.subheadline)
                .foregroundColor(.secondary)

            ForEach(domains, id: \.domain) { domain in
                let isFocusDomain = focusDomains.contains { $0.matches(domain.domain) || $0.matches("https://\(domain.domain)") }
                HStack(spacing: 8) {
                    if isFocusDomain {
                        Circle()
                            .fill(Color.blue)
                            .frame(width: 6, height: 6)
                    } else {
                        Spacer().frame(width: 6)
                    }

                    Image(systemName: "globe")
                        .font(.caption)
                        .foregroundColor(.secondary)

                    Text(domain.domain)
                        .font(.callout)
                        .frame(width: 110, alignment: .leading)
                        .lineLimit(1)

                    GeometryReader { geo in
                        RoundedRectangle(cornerRadius: 3)
                            .fill(Color.purple.opacity(0.5))
                            .frame(width: max(4, geo.size.width * CGFloat(domain.totalDuration / maxDuration)))
                    }
                    .frame(height: 14)

                    Text(TimeFormatter.duration(Int(domain.totalDuration / 60)))
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .frame(width: 50, alignment: .trailing)
                }
            }
        }
    }
}

// MARK: - Context Switches

struct ContextSwitchesView: View {
    @ObservedObject var dataProvider: InsightsViewModel

    var body: some View {
        let summary = dataProvider.disruptionSummary
        if summary.totalSwitches > 0 {
            GroupBox("Context Switches") {
                VStack(alignment: .leading, spacing: 12) {
                    HStack(alignment: .firstTextBaseline) {
                        Text("\(summary.totalSwitches)")
                            .font(.system(size: 28, weight: .semibold))
                        Text("context \(summary.totalSwitches == 1 ? "switch" : "switches")")
                            .font(.body)
                            .foregroundColor(.secondary)
                    }

                    if !summary.distractors.isEmpty {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Top distractors")
                                .font(.subheadline)
                                .foregroundColor(.secondary)

                            ForEach(Array(summary.distractors.prefix(5).enumerated()), id: \.offset) { _, item in
                                HStack {
                                    Text(item.name)
                                        .font(.callout)
                                        .lineLimit(1)
                                    Spacer()
                                    Text("\(item.count)x")
                                        .font(.callout)
                                        .foregroundColor(.secondary)
                                }
                            }
                        }
                    }
                }
                .padding(4)
            }
        }
    }
}

// MARK: - Main InsightsView

struct InsightsView: View {
    @EnvironmentObject var focusManager: FocusManager
    @EnvironmentObject var licenseManager: LicenseManager
    @StateObject private var dataProvider: InsightsViewModel
    @Binding var selectedTab: Int

    init(selectedTab: Binding<Int>) {
        _dataProvider = StateObject(wrappedValue: InsightsViewModel(dataProvider: InsightsDataProvider(focusManager: FocusManager.shared)))
        _selectedTab = selectedTab
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 10) {
                GroupBox {
                    VStack {
                        Text("You've focussed for").font(.title2)
                            .fontDesign(.default)
                            .foregroundStyle(.secondary)
                        let totalSeconds = Int(dataProvider.totalFocusTimeThisMonth)
                        let totalMinutes = Int(totalSeconds / 60)

                        Text("\(TimeFormatter.duration(totalMinutes)) this month")
                            .font(.title)
                            .fontWeight(.bold)
                        Text("Here you can find your curated focus insights. From daily to weekly detailed views, your most productive times and more.")
                            .font(.callout)
                            .fontDesign(.default)
                            .fontWeight(.regular)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                    }
                    .padding(.horizontal, 40)
                    .padding(.vertical)
                    .frame(maxWidth: .infinity)
                }

                if licenseManager.hasValidLicense() {
                    GroupBox {
                        VStack(alignment: .leading, spacing: 8) {
                            ProductivityMetricsView(dataProvider: dataProvider)
                        }
                        .padding(8)
                    }

                    GroupBox {
                        VStack(alignment: .leading, spacing: 8) {
                            InsightsHeaderView(dataProvider: dataProvider)
                            FocusTimeOverviewView(dataProvider: dataProvider)
                            InsightsGraphsContainerView(dataProvider: dataProvider)

                            HStack {
                                Text("Number of sessions")
                                    .font(.body)
                                Spacer()
                                Text("\(dataProvider.relevantSessions.count)")
                                    .font(.body)
                            }
                            .padding(.top, 8)
                        }
                        .padding(8)
                    }

                    ActivityBreakdownView(dataProvider: dataProvider)
                    ContextSwitchesView(dataProvider: dataProvider)
                } else {
                    GroupBox {
                        VStack {
                            Text("You are currently on a free plan of Auto-Focus. To unlock more detailed insights, please upgrade to Auto-Focus+.")
                                .font(.callout)
                                .fontDesign(.default)
                                .fontWeight(.regular)
                                .foregroundColor(.secondary)
                                .multilineTextAlignment(.center)

                            LicenseBenefitsView()
                        }
                        .padding(.horizontal, 40)
                        .padding(.vertical)
                        .frame(maxWidth: .infinity)

                        HStack {
                            Image(systemName: "lock.fill")
                                .foregroundColor(.secondary)
                            Text("Upgrade to Auto-Focus+ for detailed insights")
                                .font(.caption)
                                .foregroundColor(.secondary)

                            Spacer()

                            Button("Upgrade") {
                                selectedTab = 4 // Navigate to Auto-Focus+ tab
                            }
                            .controlSize(.small)
                        }
                        .padding(.vertical, 6)
                        .padding(.horizontal, 8)
                        .background(Color.secondary.opacity(0.1))
                        .cornerRadius(6)
                    }
                }
            }
            .padding()
        }
        .onAppear {
            dataProvider.updateFocusManager(focusManager)
        }
    }
}

// MARK: - End of InsightsView

#Preview {
    InsightsView(selectedTab: .constant(2))
        .environmentObject(LicenseManager())
        .frame(width: 600, height: 900)
}

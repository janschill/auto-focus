import Charts
import SwiftUI

// MARK: - Insights Sub-Tab

enum InsightsSubTab: String, CaseIterable, Identifiable {
    case summary = "Summary"
    case activity = "Activity"
    case focusQuality = "Focus Quality"

    var id: String { rawValue }
}

// MARK: - Shared Chart Components

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

// MARK: - Focus Score Ring

struct FocusScoreView: View {
    let score: Int

    private var scoreColor: Color {
        switch score {
        case 0..<30: return .red
        case 30..<60: return .orange
        case 60..<80: return .yellow
        default: return .green
        }
    }

    var body: some View {
        GroupBox {
            HStack(spacing: 20) {
                ZStack {
                    Circle()
                        .stroke(Color.gray.opacity(0.15), lineWidth: 8)
                        .frame(width: 80, height: 80)

                    Circle()
                        .trim(from: 0, to: CGFloat(score) / 100.0)
                        .stroke(scoreColor, style: StrokeStyle(lineWidth: 8, lineCap: .round))
                        .frame(width: 80, height: 80)
                        .rotationEffect(.degrees(-90))

                    Text("\(score)")
                        .font(.system(size: 24, weight: .bold))
                }

                VStack(alignment: .leading, spacing: 4) {
                    Text("Focus Score")
                        .font(.headline)
                    Text("Based on focus ratio, session depth, consistency, and low distraction.")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            .padding(8)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}

// MARK: - Summary Pane

struct InsightsSummaryPane: View {
    @ObservedObject var dataProvider: InsightsViewModel

    var body: some View {
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

            FocusScoreView(score: dataProvider.focusScore)

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

                    GroupBox {
                        VStack(alignment: .leading, spacing: 12) {
                            WeeklyBarChartView(dataProvider: dataProvider)

                            if dataProvider.selectedTimeframe == .day {
                                HourlyBarChartView(dataProvider: dataProvider)
                            }
                        }
                    }

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
        }
    }
}

// MARK: - Activity Pane

struct FocusRatioBarView: View {
    let focusDuration: TimeInterval
    let otherDuration: TimeInterval

    private var total: TimeInterval { focusDuration + otherDuration }
    private var focusPercent: Int {
        total > 0 ? Int((focusDuration / total) * 100) : 0
    }
    private var otherPercent: Int { 100 - focusPercent }

    var body: some View {
        if total > 0 {
            GroupBox {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Focus vs. Other")
                        .font(.subheadline)
                        .foregroundColor(.secondary)

                    GeometryReader { geo in
                        HStack(spacing: 2) {
                            if focusDuration > 0 {
                                RoundedRectangle(cornerRadius: 4)
                                    .fill(Color.blue)
                                    .frame(width: geo.size.width * CGFloat(focusDuration / total))
                            }
                            if otherDuration > 0 {
                                RoundedRectangle(cornerRadius: 4)
                                    .fill(Color.gray.opacity(0.3))
                                    .frame(width: geo.size.width * CGFloat(otherDuration / total))
                            }
                        }
                    }
                    .frame(height: 20)

                    HStack(spacing: 16) {
                        Label("\(focusPercent)% Focus", systemImage: "circle.fill")
                            .font(.caption)
                            .foregroundColor(.blue)
                        Label("\(otherPercent)% Other", systemImage: "circle.fill")
                            .font(.caption)
                            .foregroundColor(.gray)
                    }
                }
                .padding(4)
            }
        }
    }
}

struct ActivityBreakdownView: View {
    @ObservedObject var dataProvider: InsightsViewModel
    @EnvironmentObject var focusManager: FocusManager
    @State private var recentlyAddedDomain: String?

    var body: some View {
        let apps = dataProvider.topApps
        let domains = dataProvider.topDomains
        let focusBundleIDs = Set(focusManager.focusApps.map(\.bundleIdentifier))
        let focusDomains = focusManager.focusURLs

        let focusApps = apps.filter { focusBundleIDs.contains($0.bundleIdentifier) }
        let otherApps = apps.filter { !focusBundleIDs.contains($0.bundleIdentifier) }

        let focusDomainsList = domains.filter { domain in
            focusDomains.contains { $0.matches(domain.domain) || $0.matches("https://\(domain.domain)") }
        }
        let otherDomainsList = domains.filter { domain in
            !focusDomains.contains { $0.matches(domain.domain) || $0.matches("https://\(domain.domain)") }
        }

        if apps.isEmpty && domains.isEmpty {
            EmptyView()
        } else {
            let totalAppDuration = apps.reduce(0) { $0 + $1.totalDuration }
            let totalDomainDuration = domains.reduce(0) { $0 + $1.totalDuration }

            VStack(spacing: 10) {
                if !focusApps.isEmpty || !focusDomainsList.isEmpty {
                    GroupBox("Focus Activity") {
                        VStack(alignment: .leading, spacing: 16) {
                            if !focusApps.isEmpty {
                                appSection(apps: focusApps, totalDuration: totalAppDuration, accentColor: .blue)
                            }
                            if !focusDomainsList.isEmpty {
                                domainSection(domains: focusDomainsList, totalDuration: totalDomainDuration, accentColor: .blue)
                            }
                        }
                        .padding(4)
                    }
                }

                if !otherApps.isEmpty || !otherDomainsList.isEmpty {
                    GroupBox("Other Activity") {
                        VStack(alignment: .leading, spacing: 16) {
                            if !otherApps.isEmpty {
                                appSection(apps: otherApps, totalDuration: totalAppDuration, accentColor: .gray)
                            }
                            if !otherDomainsList.isEmpty {
                                domainSection(domains: otherDomainsList, totalDuration: totalDomainDuration, accentColor: .purple, showAddButton: true)
                            }
                        }
                        .padding(4)
                    }
                }
            }
        }
    }

    private func appSection(apps: [AppUsageSummary], totalDuration: TimeInterval, accentColor: Color) -> some View {
        let maxDuration = apps.first?.totalDuration ?? 1

        return VStack(alignment: .leading, spacing: 6) {
            Text("Apps")
                .font(.subheadline)
                .foregroundColor(.secondary)

            ForEach(apps, id: \.bundleIdentifier) { app in
                let displayName = BundleNameMapper.displayName(bundleIdentifier: app.bundleIdentifier, appName: app.appName)
                let percent = totalDuration > 0 ? Int((app.totalDuration / totalDuration) * 100) : 0

                HStack(spacing: 8) {
                    if let icon = BundleNameMapper.appIcon(for: app.bundleIdentifier) {
                        Image(nsImage: icon)
                            .resizable()
                            .frame(width: 18, height: 18)
                    } else {
                        Image(systemName: "app.fill")
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .frame(width: 18, height: 18)
                    }

                    Text(displayName)
                        .font(.callout)
                        .frame(width: 120, alignment: .leading)
                        .lineLimit(1)

                    GeometryReader { geo in
                        RoundedRectangle(cornerRadius: 3)
                            .fill(accentColor.opacity(0.5))
                            .frame(width: max(4, geo.size.width * CGFloat(app.totalDuration / maxDuration)))
                    }
                    .frame(height: 14)

                    Text(TimeFormatter.humanReadable(app.totalDuration))
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .frame(width: 50, alignment: .trailing)

                    Text("\(percent)%")
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                        .frame(width: 30, alignment: .trailing)
                }
            }
        }
    }

    private func domainSection(domains: [DomainUsageSummary], totalDuration: TimeInterval, accentColor: Color, showAddButton: Bool = false) -> some View {
        let maxDuration = domains.first?.totalDuration ?? 1

        return VStack(alignment: .leading, spacing: 6) {
            Text("Websites")
                .font(.subheadline)
                .foregroundColor(.secondary)

            ForEach(domains, id: \.domain) { domain in
                let percent = totalDuration > 0 ? Int((domain.totalDuration / totalDuration) * 100) : 0

                HStack(spacing: 8) {
                    if showAddButton {
                        if recentlyAddedDomain == domain.domain {
                            Image(systemName: "checkmark.circle.fill")
                                .font(.caption)
                                .foregroundColor(.green)
                                .frame(width: 18)
                        } else {
                            Button {
                                addDomainAsFocusURL(domain.domain)
                            } label: {
                                Image(systemName: "plus.circle")
                                    .font(.caption)
                                    .foregroundColor(.blue)
                            }
                            .buttonStyle(.plain)
                            .frame(width: 18)
                            .help("Add as focus URL")
                        }
                    } else {
                        Image(systemName: "globe")
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .frame(width: 18)
                    }

                    Text(domain.domain)
                        .font(.callout)
                        .frame(width: 120, alignment: .leading)
                        .lineLimit(1)

                    GeometryReader { geo in
                        RoundedRectangle(cornerRadius: 3)
                            .fill(accentColor.opacity(0.5))
                            .frame(width: max(4, geo.size.width * CGFloat(domain.totalDuration / maxDuration)))
                    }
                    .frame(height: 14)

                    VStack(alignment: .trailing, spacing: 0) {
                        Text(TimeFormatter.humanReadable(domain.totalDuration))
                            .font(.caption)
                            .foregroundColor(.secondary)
                        if domain.visitCount > 0 {
                            Text("\(domain.visitCount) visits")
                                .font(.caption2)
                                .foregroundStyle(.tertiary)
                        }
                    }
                    .frame(width: 55, alignment: .trailing)

                    Text("\(percent)%")
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                        .frame(width: 30, alignment: .trailing)
                }
            }
        }
    }

    private func addDomainAsFocusURL(_ domain: String) {
        let name = FocusURL.displayName(from: domain)
        let focusURL = FocusURL(name: name, domain: domain)
        focusManager.addFocusURL(focusURL)
        recentlyAddedDomain = domain
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
            recentlyAddedDomain = nil
        }
    }
}

struct InsightsActivityPane: View {
    @ObservedObject var dataProvider: InsightsViewModel

    var body: some View {
        VStack(spacing: 10) {
            InsightsHeaderView(dataProvider: dataProvider)
                .padding(.horizontal, 4)

            let ratio = dataProvider.focusVsOtherRatio
            FocusRatioBarView(focusDuration: ratio.focusDuration, otherDuration: ratio.otherDuration)

            ActivityBreakdownView(dataProvider: dataProvider)
        }
    }
}

// MARK: - Focus Quality Pane

struct DisruptionChartView: View {
    let data: [HourlyDisruptionData]
    let isHourly: Bool

    var body: some View {
        let hasData = data.contains { $0.switches > 0 }
        if hasData {
            GroupBox {
                VStack(alignment: .leading, spacing: 8) {
                    Text(isHourly ? "Switches by Hour" : "Switches by Day")
                        .font(.subheadline)
                        .foregroundColor(.secondary)

                    Chart {
                        ForEach(data) { item in
                            if item.switches > 0 {
                                BarMark(
                                    x: .value("Time", item.label),
                                    y: .value("Switches", item.switches)
                                )
                                .foregroundStyle(Color.orange.opacity(0.7))
                            }
                        }
                    }
                    .chartXAxis {
                        if isHourly {
                            AxisMarks(values: ["00", "06", "12", "18", "23"]) { value in
                                AxisValueLabel()
                            }
                        } else {
                            AxisMarks { _ in
                                AxisValueLabel()
                            }
                        }
                    }
                    .frame(height: 80)
                }
                .padding(4)
            }
        }
    }
}

struct ContextSwitchesView: View {
    @ObservedObject var dataProvider: InsightsViewModel

    var body: some View {
        let summary = dataProvider.disruptionSummary

        GroupBox("Context Switches") {
            VStack(alignment: .leading, spacing: 12) {
                Text("A context switch happens when you leave a focus app or website and switch to something else. Fewer switches means deeper focus.")
                    .font(.caption)
                    .foregroundColor(.secondary)

                HStack(alignment: .firstTextBaseline, spacing: 8) {
                    Text("\(summary.totalSwitches)")
                        .font(.system(size: 28, weight: .semibold))
                    Text("context \(summary.totalSwitches == 1 ? "switch" : "switches")")
                        .font(.body)
                        .foregroundColor(.secondary)

                    Spacer()

                    let prev = dataProvider.previousPeriodDisruptions
                    if prev.totalSwitches > 0 {
                        let delta = summary.totalSwitches - prev.totalSwitches
                        let pct = Int((Double(delta) / Double(prev.totalSwitches)) * 100)
                        let label = dataProvider.selectedTimeframe == .day ? "vs yesterday" : "vs last week"
                        HStack(spacing: 2) {
                            Image(systemName: delta <= 0 ? "arrow.down.right" : "arrow.up.right")
                                .font(.caption)
                                .foregroundColor(delta <= 0 ? .green : .red)
                            Text("\(abs(pct))% \(label)")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                }

                let chartData = dataProvider.disruptionOverTime
                DisruptionChartView(data: chartData, isHourly: dataProvider.selectedTimeframe == .day)

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

struct FocusQualityMetricsView: View {
    @ObservedObject var dataProvider: InsightsViewModel

    var body: some View {
        VStack(spacing: 10) {
            HStack(spacing: 10) {
                if let longest = dataProvider.longestSession {
                    MetricCard(
                        title: "Longest Focus Stretch",
                        value: TimeFormatter.humanReadable(longest.duration)
                    )
                } else {
                    MetricCard(
                        title: "Longest Focus Stretch",
                        value: "—"
                    )
                }

                MetricCard(
                    title: "Avg Session Length",
                    value: dataProvider.averageSessionLength > 0
                        ? TimeFormatter.humanReadable(dataProvider.averageSessionLength)
                        : "—"
                )
            }

            HStack(spacing: 10) {
                let deep = dataProvider.deepFocusSessions
                MetricCard(
                    title: "Deep Focus (25m+)",
                    value: deep.total > 0 ? "\(deep.deep) of \(deep.total)" : "—"
                )

                MetricCard(
                    title: "Switches / Session",
                    value: dataProvider.relevantSessions.isEmpty
                        ? "—"
                        : String(format: "%.1f", dataProvider.contextSwitchesPerSession)
                )
            }
        }
    }
}

struct InsightsFocusQualityPane: View {
    @ObservedObject var dataProvider: InsightsViewModel

    var body: some View {
        VStack(spacing: 10) {
            InsightsHeaderView(dataProvider: dataProvider)
                .padding(.horizontal, 4)

            FocusQualityMetricsView(dataProvider: dataProvider)
            ContextSwitchesView(dataProvider: dataProvider)
        }
    }
}

// MARK: - Main InsightsView

struct InsightsView: View {
    @EnvironmentObject var focusManager: FocusManager
    @EnvironmentObject var licenseManager: LicenseManager
    @StateObject private var dataProvider: InsightsViewModel
    @Binding var selectedTab: Int
    @State private var selectedSubTab: InsightsSubTab = .summary

    init(selectedTab: Binding<Int>) {
        _dataProvider = StateObject(wrappedValue: InsightsViewModel(dataProvider: InsightsDataProvider(focusManager: FocusManager.shared)))
        _selectedTab = selectedTab
    }

    var body: some View {
        VStack(spacing: 0) {
            if licenseManager.hasValidLicense() {
                Picker("", selection: $selectedSubTab) {
                    ForEach(InsightsSubTab.allCases) { tab in
                        Text(tab.rawValue).tag(tab)
                    }
                }
                .pickerStyle(.segmented)
                .padding(.horizontal)
                .padding(.top, 8)
                .padding(.bottom, 4)
            }

            ScrollView {
                VStack(spacing: 10) {
                    if licenseManager.hasValidLicense() {
                        switch selectedSubTab {
                        case .summary:
                            InsightsSummaryPane(dataProvider: dataProvider)
                        case .activity:
                            InsightsActivityPane(dataProvider: dataProvider)
                        case .focusQuality:
                            InsightsFocusQualityPane(dataProvider: dataProvider)
                        }
                    } else {
                        // Visible header with real data
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
                            }
                            .padding(.horizontal, 40)
                            .padding(.vertical)
                            .frame(maxWidth: .infinity)
                        }

                        // Blurred preview of premium insights
                        ZStack {
                            VStack(spacing: 10) {
                                FocusScoreView(score: dataProvider.focusScore)
                                ProductivityMetricsView(dataProvider: dataProvider)
                            }
                            .blur(radius: 4)
                            .allowsHitTesting(false)

                            VStack(spacing: 12) {
                                Image(systemName: "lock.fill")
                                    .font(.title2)
                                    .foregroundColor(.secondary)
                                Text("Unlock detailed insights")
                                    .font(.headline)
                                Button("Get Auto-Focus+") {
                                    selectedTab = 4
                                }
                                .buttonStyle(.borderedProminent)
                                .controlSize(.regular)
                            }
                            .padding(20)
                            .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 12))
                        }
                    }
                }
                .padding()
            }
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

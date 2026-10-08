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

/// Dashed, light gridline shared by all Insights charts.
private let insightsGridLineStyle = StrokeStyle(lineWidth: 0.5, dash: [2, 3])

struct WeeklyBarChartView: View {
    @ObservedObject var dataProvider: InsightsViewModel

    var body: some View {
        let weekdayData = dataProvider.snapshot.weekdayData
        let averageMinutes = dataProvider.snapshot.averageDailyMinutes
        let maxMinutes = Double(weekdayData.map(\.totalMinutes).max() ?? 0)

        Chart {
            ForEach(weekdayData, id: \.weekdaySymbol) { dayData in
                BarMark(
                    x: .value("Day", dayData.weekdaySymbol.capitalized),
                    y: .value("Minutes", dayData.totalMinutes)
                )
                .foregroundStyle(Color.blue.opacity(dayData.isSelected ? 1 : 0.35).gradient)
                .cornerRadius(3)
            }

            if averageMinutes > 0 {
                RuleMark(y: .value("Average", averageMinutes))
                    .foregroundStyle(Color.green)
                    .lineStyle(StrokeStyle(lineWidth: 1, dash: [4, 3]))
                    .annotation(position: .top, alignment: .trailing) {
                        Text("avg \(TimeFormatter.duration(averageMinutes))")
                            .font(.caption2)
                            .foregroundStyle(.green)
                    }
            }
        }
        .chartYAxis {
            AxisMarks(position: .leading, values: .automatic(desiredCount: 3)) { _ in
                AxisGridLine(stroke: insightsGridLineStyle)
                AxisValueLabel()
            }
        }
        .chartYScale(domain: 0...max(maxMinutes * 1.2, 1))
        .frame(height: 120)
    }
}

struct HourlyBarChartView: View {
    @ObservedObject var dataProvider: InsightsViewModel

    var body: some View {
        Chart(dataProvider.snapshot.hourlyData) { hourData in
            BarMark(
                x: .value("Hour", hourData.hour),
                y: .value("Minutes", hourData.totalMinutes)
            )
            .foregroundStyle(Color.blue.gradient)
            .cornerRadius(2)
        }
        .chartXScale(domain: -0.5...23.5)
        .chartXAxis {
            AxisMarks(values: [0, 6, 12, 18, 23]) { value in
                AxisValueLabel {
                    if let hour = value.as(Int.self) {
                        Text(String(format: "%02d", hour))
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                }
            }
        }
        .chartYAxis {
            AxisMarks(position: .leading, values: .automatic(desiredCount: 2)) { _ in
                AxisGridLine(stroke: insightsGridLineStyle)
            }
        }
        .frame(height: 60)
    }
}

/// Day/Week picker plus previous/next/today navigation for the selected period.
struct InsightsHeaderView: View {
    @ObservedObject var dataProvider: InsightsViewModel

    /// Selecting the day timeframe jumps back to today, matching the previous menu behavior.
    private var timeframeSelection: Binding<InsightsDataProvider.Timeframe> {
        Binding(
            get: { dataProvider.selectedTimeframe },
            set: { timeframe in
                dataProvider.selectedTimeframe = timeframe
                if timeframe == .day {
                    dataProvider.selectedDate = Date()
                }
            }
        )
    }

    private var isAtCurrentPeriod: Bool {
        let calendar = Calendar.current
        if dataProvider.selectedTimeframe == .day {
            return calendar.isDateInToday(dataProvider.selectedDate)
        }
        return calendar.startOfWeek(for: dataProvider.selectedDate) == calendar.startOfWeek(for: Date())
    }

    var body: some View {
        let isDay = dataProvider.selectedTimeframe == .day

        HStack(spacing: 12) {
            Picker("Timeframe", selection: timeframeSelection) {
                Text("Day").tag(InsightsDataProvider.Timeframe.day)
                Text("Week").tag(InsightsDataProvider.Timeframe.week)
            }
            .pickerStyle(.segmented)
            .labelsHidden()
            .frame(width: 140)

            Spacer()

            Text(dataProvider.snapshot.displayedDateString)
                .font(.headline)
                .lineLimit(1)

            Button {
                navigate(forward: false)
            } label: {
                Image(systemName: "chevron.left")
            }
            .help(isDay ? "Previous day" : "Previous week")

            Button("Today") {
                dataProvider.goToToday()
            }
            .disabled(isAtCurrentPeriod)

            Button {
                navigate(forward: true)
            } label: {
                Image(systemName: "chevron.right")
            }
            .disabled(isAtCurrentPeriod)
            .help(isDay ? "Next day" : "Next week")
        }
    }

    private func navigate(forward: Bool) {
        if dataProvider.selectedTimeframe == .day {
            dataProvider.navigateDay(forward: forward)
        } else {
            dataProvider.navigateWeek(forward: forward)
        }
    }
}

struct FocusTimeOverviewView: View {
    @ObservedObject var dataProvider: InsightsViewModel

    var body: some View {
        let snapshot = dataProvider.snapshot
        let isDay = dataProvider.selectedTimeframe == .day
        let minutes = isDay ? Int(snapshot.totalFocusTime / 60) : snapshot.averageDailyMinutes

        HStack(alignment: .center) {
            VStack(alignment: .leading, spacing: 2) {
                Text(isDay ? "Focus Time" : "Daily Average")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                Text(TimeFormatter.duration(minutes))
                    .font(.system(.largeTitle, design: .rounded, weight: .semibold))
                    .monospacedDigit()
            }

            Spacer()

            if !isDay, let change = snapshot.weekComparisonPercentage {
                let tint: Color = change > 0 ? .green : (change < 0 ? .red : .secondary)
                let symbol = change > 0 ? "arrow.up.right" : (change < 0 ? "arrow.down.right" : "equal")

                Label("\(abs(change))% vs last week", systemImage: symbol)
                    .font(.caption.weight(.medium))
                    .foregroundStyle(tint)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(tint.opacity(0.15), in: Capsule())
            }
        }
    }
}

struct ProductivityMetricsView: View {
    @ObservedObject var dataProvider: InsightsViewModel

    var body: some View {
        let maxAverageMinutes = dataProvider.snapshot.weekdayAverages.map { $0.average / 60 }.max() ?? 0

        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 10) {
                StatTile(
                    title: "Most Productive Time",
                    systemImage: "sun.max.fill",
                    tint: .yellow,
                    value: dataProvider.snapshot.productiveTimeRange ?? "—"
                )
                StatTile(
                    title: "Most Productive Day",
                    systemImage: "calendar",
                    tint: .blue,
                    value: dataProvider.snapshot.productiveWeekday ?? "—"
                )
            }

            GroupBox {
                VStack(alignment: .leading, spacing: 12) {
                    Label("Weekly Consistency", systemImage: "chart.bar.fill")
                        .font(.headline)
                        .labelStyle(TintedIconLabelStyle(tint: .blue))

                    Chart {
                        ForEach(dataProvider.snapshot.weekdayAverages, id: \.day) { item in
                            BarMark(
                                x: .value("Day", item.day),
                                y: .value("Minutes", Int(item.average / 60))
                            )
                            .foregroundStyle(Color.blue.gradient)
                            .cornerRadius(3)
                            .annotation(position: .top) {
                                Text(TimeFormatter.duration(Int(item.average / 60)))
                                    .font(.caption2)
                                    .monospacedDigit()
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                    .chartYAxis(.hidden)
                    .chartYScale(domain: 0...max(maxAverageMinutes * 1.25, 1))
                    .frame(height: 120)
                }
                .padding(6)
            }
        }
    }
}

// MARK: - Focus Score Ring

struct FocusScoreView: View {
    let score: Int

    private var scoreColor: Color { Self.color(for: score) }

    /// Traffic-light tint for a focus score: red below 30, then orange, yellow, and green from 80.
    static func color(for score: Int) -> Color {
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
                        .font(.system(.title, design: .rounded, weight: .semibold))
                        .monospacedDigit()
                }

                VStack(alignment: .leading, spacing: 4) {
                    Label("Focus Score", systemImage: "gauge")
                        .font(.headline)
                        .labelStyle(TintedIconLabelStyle(tint: scoreColor))
                    Text("Based on focus ratio, session depth, consistency, and low distraction.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            .padding(8)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}

// MARK: - Summary Pane

/// Hero card showing the total focus time of the current month, optionally next to the focus score ring.
struct MonthlyFocusHeroView: View {
    let totalFocusTimeThisMonth: TimeInterval
    var focusScore: Int?

    var body: some View {
        GroupBox {
            HStack(alignment: .center, spacing: 16) {
                VStack(alignment: .leading, spacing: 4) {
                    Label(Date().formatted(.dateTime.month(.wide)), systemImage: "calendar")
                        .font(.headline)
                        .labelStyle(TintedIconLabelStyle(tint: .blue))
                    Text(TimeFormatter.duration(Int(totalFocusTimeThisMonth / 60)))
                        .font(.system(size: 40, weight: .semibold, design: .rounded))
                        .monospacedDigit()
                    Text("of focused work this month")
                        .font(.callout)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                if let focusScore {
                    FocusScoreRing(score: focusScore)
                }
            }
            .padding(8)
        }
    }
}

/// Circular gauge for the 0–100 focus score with a caption.
struct FocusScoreRing: View {
    let score: Int

    var body: some View {
        let tint = FocusScoreView.color(for: score)

        VStack(spacing: 6) {
            ZStack {
                Circle()
                    .stroke(Color.gray.opacity(0.15), lineWidth: 7)
                Circle()
                    .trim(from: 0, to: CGFloat(score) / 100.0)
                    .stroke(tint.gradient, style: StrokeStyle(lineWidth: 7, lineCap: .round))
                    .rotationEffect(.degrees(-90))
                Text("\(score)")
                    .font(.system(.title2, design: .rounded, weight: .semibold))
                    .monospacedDigit()
            }
            .frame(width: 68, height: 68)

            Text("Focus Score")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .help("Based on focus ratio, session depth, consistency, and low distraction.")
    }
}

struct InsightsSummaryPane: View {
    @ObservedObject var dataProvider: InsightsViewModel

    var body: some View {
        VStack(spacing: 10) {
            MonthlyFocusHeroView(
                totalFocusTimeThisMonth: dataProvider.snapshot.totalFocusTimeThisMonth,
                focusScore: dataProvider.snapshot.focusScore
            )

            ProductivityMetricsView(dataProvider: dataProvider)

            GroupBox {
                VStack(alignment: .leading, spacing: 14) {
                    InsightsHeaderView(dataProvider: dataProvider)
                    FocusTimeOverviewView(dataProvider: dataProvider)

                    WeeklyBarChartView(dataProvider: dataProvider)

                    if dataProvider.selectedTimeframe == .day {
                        HourlyBarChartView(dataProvider: dataProvider)
                    }

                    Divider()

                    HStack {
                        Label("Sessions", systemImage: "number")
                            .labelStyle(TintedIconLabelStyle(tint: .blue))
                        Spacer()
                        Text("\(dataProvider.snapshot.sessionCount)")
                            .monospacedDigit()
                            .foregroundStyle(.secondary)
                    }
                    .font(.callout)
                }
                .padding(6)
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
                VStack(alignment: .leading, spacing: 10) {
                    Label("Focus vs. Other", systemImage: "circle.lefthalf.filled")
                        .font(.headline)
                        .labelStyle(TintedIconLabelStyle(tint: .blue))

                    GeometryReader { geo in
                        HStack(spacing: 2) {
                            if focusDuration > 0 {
                                Capsule()
                                    .fill(Color.blue.gradient)
                                    .frame(width: geo.size.width * CGFloat(focusDuration / total))
                            }
                            if otherDuration > 0 {
                                Capsule()
                                    .fill(Color.gray.opacity(0.3))
                                    .frame(width: geo.size.width * CGFloat(otherDuration / total))
                            }
                        }
                    }
                    .frame(height: 10)

                    HStack(spacing: 16) {
                        legendItem(title: "Focus", percent: focusPercent, duration: focusDuration, color: .blue)
                        legendItem(title: "Other", percent: otherPercent, duration: otherDuration, color: .gray)
                    }
                }
                .padding(6)
            }
        }
    }

    private func legendItem(title: String, percent: Int, duration: TimeInterval, color: Color) -> some View {
        HStack(spacing: 6) {
            Circle()
                .fill(color)
                .frame(width: 8, height: 8)
            Text(title)
                .foregroundStyle(.secondary)
            Text("\(percent)%")
                .fontWeight(.semibold)
                .monospacedDigit()
            Text(TimeFormatter.humanReadable(duration))
                .foregroundStyle(.tertiary)
                .monospacedDigit()
        }
        .font(.caption)
    }
}

/// One row of the activity breakdown: icon, name, relative bar, duration and share.
private struct UsageBarRow<Icon: View>: View {
    let name: String
    let fraction: Double
    let duration: TimeInterval
    let percent: Int
    let accentColor: Color
    @ViewBuilder let icon: () -> Icon

    var body: some View {
        HStack(spacing: 8) {
            icon()
                .frame(width: 18, height: 18)

            Text(name)
                .font(.callout)
                .lineLimit(1)
                .truncationMode(.middle)
                .frame(width: 150, alignment: .leading)

            GeometryReader { geo in
                RoundedRectangle(cornerRadius: 3)
                    .fill(accentColor.opacity(0.5))
                    .frame(width: max(4, geo.size.width * CGFloat(fraction)))
            }
            .frame(height: 10)

            Text(TimeFormatter.humanReadable(duration))
                .font(.caption)
                .monospacedDigit()
                .foregroundStyle(.secondary)
                .frame(width: 55, alignment: .trailing)

            Text("\(percent)%")
                .font(.caption2)
                .monospacedDigit()
                .foregroundStyle(.tertiary)
                .frame(width: 30, alignment: .trailing)
        }
    }
}

struct ActivityBreakdownView: View {
    @ObservedObject var dataProvider: InsightsViewModel
    @State private var recentlyAddedDomain: String?

    var body: some View {
        let activity = dataProvider.snapshot.activity
        let focusApps = activity.focusApps
        let otherApps = activity.otherApps
        let focusDomainsList = activity.focusDomains
        let otherDomainsList = activity.otherDomains
        let totalAppDuration = activity.totalAppDuration
        let totalDomainDuration = activity.totalDomainDuration

        if activity.isEmpty {
            EmptyView()
        } else {
            VStack(spacing: 10) {
                if !focusApps.isEmpty || !focusDomainsList.isEmpty {
                    GroupBox {
                        VStack(alignment: .leading, spacing: 16) {
                            Label("Focus Activity", systemImage: "scope")
                                .font(.headline)
                                .labelStyle(TintedIconLabelStyle(tint: .blue))
                            if !focusApps.isEmpty {
                                appSection(apps: focusApps, totalDuration: totalAppDuration, accentColor: .blue)
                            }
                            if !focusDomainsList.isEmpty {
                                domainSection(domains: focusDomainsList, totalDuration: totalDomainDuration, accentColor: .blue)
                            }
                        }
                        .padding(6)
                    }
                }

                if !otherApps.isEmpty || !otherDomainsList.isEmpty {
                    GroupBox {
                        VStack(alignment: .leading, spacing: 16) {
                            Label("Other Activity", systemImage: "square.stack.3d.up")
                                .font(.headline)
                                .labelStyle(TintedIconLabelStyle(tint: .gray))
                            if !otherApps.isEmpty {
                                appSection(apps: otherApps, totalDuration: totalAppDuration, accentColor: .gray)
                            }
                            if !otherDomainsList.isEmpty {
                                domainSection(domains: otherDomainsList, totalDuration: totalDomainDuration, accentColor: .gray, showAddButton: true)
                            }
                        }
                        .padding(6)
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
                .foregroundStyle(.secondary)

            ForEach(apps, id: \.bundleIdentifier) { app in
                UsageBarRow(
                    name: BundleNameMapper.displayName(bundleIdentifier: app.bundleIdentifier, appName: app.appName),
                    fraction: app.totalDuration / maxDuration,
                    duration: app.totalDuration,
                    percent: totalDuration > 0 ? Int((app.totalDuration / totalDuration) * 100) : 0,
                    accentColor: accentColor
                ) {
                    appIcon(for: app.bundleIdentifier)
                }
            }
        }
    }

    private func domainSection(domains: [DomainUsageSummary], totalDuration: TimeInterval, accentColor: Color, showAddButton: Bool = false) -> some View {
        let maxDuration = domains.first?.totalDuration ?? 1

        return VStack(alignment: .leading, spacing: 6) {
            Text("Websites")
                .font(.subheadline)
                .foregroundStyle(.secondary)

            ForEach(domains, id: \.domain) { domain in
                UsageBarRow(
                    name: domain.domain,
                    fraction: domain.totalDuration / maxDuration,
                    duration: domain.totalDuration,
                    percent: totalDuration > 0 ? Int((domain.totalDuration / totalDuration) * 100) : 0,
                    accentColor: accentColor
                ) {
                    domainLeadingIcon(for: domain.domain, showAddButton: showAddButton)
                }
                .help(domain.visitCount > 0 ? "\(domain.domain) · \(domain.visitCount) visits" : domain.domain)
            }
        }
    }

    @ViewBuilder
    private func appIcon(for bundleIdentifier: String) -> some View {
        if let icon = BundleNameMapper.appIcon(for: bundleIdentifier) {
            Image(nsImage: icon)
                .resizable()
        } else {
            Image(systemName: "app.fill")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    @ViewBuilder
    private func domainLeadingIcon(for domain: String, showAddButton: Bool) -> some View {
        if !showAddButton {
            Image(systemName: "globe")
                .font(.caption)
                .foregroundStyle(.secondary)
        } else if recentlyAddedDomain == domain {
            Image(systemName: "checkmark.circle.fill")
                .font(.caption)
                .foregroundStyle(.green)
        } else {
            Button {
                addDomainAsFocusURL(domain)
            } label: {
                Image(systemName: "plus.circle")
                    .font(.caption)
                    .foregroundStyle(.blue)
            }
            .buttonStyle(.plain)
            .help("Add as focus URL")
        }
    }

    private func addDomainAsFocusURL(_ domain: String) {
        let name = FocusURL.displayName(from: domain)
        let focusURL = FocusURL(name: name, domain: domain)
        dataProvider.addFocusURL(focusURL)
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

            FocusRatioBarView(
                focusDuration: dataProvider.snapshot.focusDuration,
                otherDuration: dataProvider.snapshot.otherDuration
            )

            ActivityBreakdownView(dataProvider: dataProvider)
        }
    }
}

// MARK: - Focus Quality Pane

/// Compact metric tile: tinted SF Symbol + title above a large rounded value.
struct StatTile: View {
    let title: String
    let systemImage: String
    let tint: Color
    let value: String
    var detail: String?

    var body: some View {
        GroupBox {
            VStack(alignment: .leading, spacing: 6) {
                Label(title, systemImage: systemImage)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .labelStyle(TintedIconLabelStyle(tint: tint))

                HStack(alignment: .firstTextBaseline, spacing: 4) {
                    Text(value)
                        .font(.system(.title, design: .rounded, weight: .semibold))
                        .monospacedDigit()
                    if let detail {
                        Text(detail)
                            .font(.callout)
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(6)
        }
    }
}

/// Label style that tints only the icon, leaving the title in the inherited style.
struct TintedIconLabelStyle: LabelStyle {
    let tint: Color

    func makeBody(configuration: Configuration) -> some View {
        HStack(spacing: 6) {
            configuration.icon
                .foregroundStyle(tint)
            configuration.title
        }
    }
}

struct DisruptionChartView: View {
    let data: [HourlyDisruptionData]
    let isHourly: Bool

    var body: some View {
        Chart(data) { item in
            BarMark(
                x: .value("Time", item.label),
                y: .value("Switches", item.switches)
            )
            .foregroundStyle(Color.orange.gradient)
            .cornerRadius(3)
        }
        .chartXAxis {
            if isHourly {
                AxisMarks(values: ["00", "06", "12", "18"]) { _ in
                    AxisValueLabel()
                }
            } else {
                AxisMarks { _ in
                    AxisValueLabel()
                }
            }
        }
        .chartYAxis {
            AxisMarks(position: .leading, values: .automatic(desiredCount: 3)) { _ in
                AxisGridLine(stroke: StrokeStyle(lineWidth: 0.5, dash: [2, 3]))
                AxisValueLabel()
            }
        }
        .frame(height: 110)
    }
}

struct SwitchTrendBadge: View {
    let current: Int
    let previous: Int
    let comparisonLabel: String

    var body: some View {
        let delta = current - previous
        let tint: Color = delta < 0 ? .green : (delta > 0 ? .red : .secondary)
        let symbol = delta < 0 ? "arrow.down.right" : (delta > 0 ? "arrow.up.right" : "equal")
        let text = delta == 0 ? "Same as \(comparisonLabel)" : "\(delta > 0 ? "+" : "−")\(abs(delta)) vs \(comparisonLabel)"

        Label(text, systemImage: symbol)
            .font(.caption.weight(.medium))
            .foregroundStyle(tint)
            .padding(.horizontal, 8)
            .padding(.vertical, 3)
            .background(tint.opacity(0.15), in: Capsule())
    }
}

struct DistractorListView: View {
    let distractors: [Distractor]

    var body: some View {
        let maxCount = distractors.first?.count ?? 1

        VStack(alignment: .leading, spacing: 8) {
            Text("Top Distractors")
                .font(.subheadline)
                .foregroundStyle(.secondary)

            ForEach(distractors, id: \.name) { item in
                HStack(spacing: 8) {
                    icon(for: item)

                    Text(item.name)
                        .font(.callout)
                        .lineLimit(1)
                        .truncationMode(.middle)
                        .frame(width: 160, alignment: .leading)

                    GeometryReader { geo in
                        RoundedRectangle(cornerRadius: 3)
                            .fill(Color.orange.opacity(0.5))
                            .frame(width: max(4, geo.size.width * CGFloat(item.count) / CGFloat(maxCount)))
                    }
                    .frame(height: 10)

                    Text("\(item.count)×")
                        .font(.callout)
                        .monospacedDigit()
                        .foregroundStyle(.secondary)
                        .frame(width: 40, alignment: .trailing)
                }
            }
        }
    }

    @ViewBuilder
    private func icon(for item: Distractor) -> some View {
        if let bundleID = item.bundleIdentifier, let appIcon = BundleNameMapper.appIcon(for: bundleID) {
            Image(nsImage: appIcon)
                .resizable()
                .frame(width: 18, height: 18)
        } else {
            Image(systemName: item.bundleIdentifier == nil ? "globe" : "app.fill")
                .font(.callout)
                .foregroundStyle(.secondary)
                .frame(width: 18, height: 18)
        }
    }
}

struct ContextSwitchesView: View {
    @ObservedObject var dataProvider: InsightsViewModel

    var body: some View {
        let summary = dataProvider.snapshot.disruptionSummary
        let previous = dataProvider.snapshot.previousPeriodDisruptions
        let isDay = dataProvider.selectedTimeframe == .day
        let hasChartData = dataProvider.snapshot.disruptionOverTime.contains { $0.switches > 0 }

        GroupBox {
            VStack(alignment: .leading, spacing: 14) {
                HStack(alignment: .firstTextBaseline) {
                    Label("Context Switches", systemImage: "arrow.triangle.swap")
                        .font(.headline)
                        .labelStyle(TintedIconLabelStyle(tint: .orange))
                    Image(systemName: "info.circle")
                        .foregroundStyle(.tertiary)
                        .help("A context switch happens when you leave a focus app or website and switch to something else. Fewer switches means deeper focus.")
                    Spacer()
                    if summary.totalSwitches > 0 || previous.totalSwitches > 0 {
                        SwitchTrendBadge(
                            current: summary.totalSwitches,
                            previous: previous.totalSwitches,
                            comparisonLabel: isDay ? "yesterday" : "last week"
                        )
                    }
                }

                HStack(alignment: .firstTextBaseline, spacing: 6) {
                    Text("\(summary.totalSwitches)")
                        .font(.system(size: 40, weight: .semibold, design: .rounded))
                        .monospacedDigit()
                    Text(summary.totalSwitches == 1 ? "switch" : "switches")
                        .font(.title3)
                        .foregroundStyle(.secondary)
                }

                if hasChartData {
                    DisruptionChartView(data: dataProvider.snapshot.disruptionOverTime, isHourly: isDay)
                }

                if !summary.distractors.isEmpty {
                    Divider()
                    DistractorListView(distractors: Array(summary.distractors.prefix(5)))
                }
            }
            .padding(6)
        }
    }
}

struct FocusQualityMetricsView: View {
    @ObservedObject var dataProvider: InsightsViewModel

    var body: some View {
        let snapshot = dataProvider.snapshot
        let deep = snapshot.deepFocusSessions

        Grid(horizontalSpacing: 10, verticalSpacing: 10) {
            GridRow {
                StatTile(
                    title: "Longest Stretch",
                    systemImage: "timer",
                    tint: .blue,
                    value: snapshot.longestSession.map { TimeFormatter.humanReadable($0.duration) } ?? "—"
                )
                StatTile(
                    title: "Avg Session",
                    systemImage: "clock",
                    tint: .teal,
                    value: snapshot.averageSessionLength > 0
                        ? TimeFormatter.humanReadable(snapshot.averageSessionLength)
                        : "—"
                )
            }
            GridRow {
                StatTile(
                    title: "Deep Focus (25m+)",
                    systemImage: "brain.head.profile",
                    tint: .purple,
                    value: deep.total > 0 ? "\(deep.deep)" : "—",
                    detail: deep.total > 0 ? "of \(deep.total) sessions" : nil
                )
                StatTile(
                    title: "Switches / Session",
                    systemImage: "arrow.triangle.swap",
                    tint: .orange,
                    value: snapshot.sessionCount == 0
                        ? "—"
                        : String(format: "%.1f", snapshot.contextSwitchesPerSession)
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
            if licenseManager.isLicensed {
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
                    if licenseManager.isLicensed {
                        switch selectedSubTab {
                        case .summary:
                            InsightsSummaryPane(dataProvider: dataProvider)
                        case .activity:
                            InsightsActivityPane(dataProvider: dataProvider)
                        case .focusQuality:
                            InsightsFocusQualityPane(dataProvider: dataProvider)
                        }
                    } else {
                        MonthlyFocusHeroView(totalFocusTimeThisMonth: dataProvider.snapshot.totalFocusTimeThisMonth)

                        // Blurred preview of premium insights
                        ZStack {
                            VStack(spacing: 10) {
                                FocusScoreView(score: dataProvider.snapshot.focusScore)
                                ProductivityMetricsView(dataProvider: dataProvider)
                            }
                            .blur(radius: 4)
                            .allowsHitTesting(false)

                            VStack(spacing: 12) {
                                Image(systemName: "lock.fill")
                                    .font(.title2)
                                    .foregroundStyle(.secondary)
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
            dataProvider.startObserving()
        }
        .onDisappear {
            dataProvider.stopObserving()
        }
    }
}

// MARK: - End of InsightsView

#Preview {
    InsightsView(selectedTab: .constant(2))
        .environmentObject(LicenseManager())
        .frame(width: 600, height: 900)
}

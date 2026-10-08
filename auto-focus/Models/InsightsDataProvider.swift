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

/// Top apps and domains of a period, split into focus and other activity.
struct ActivityBreakdown {
    let focusApps: [AppUsageSummary]
    let otherApps: [AppUsageSummary]
    let focusDomains: [DomainUsageSummary]
    let otherDomains: [DomainUsageSummary]
    let totalAppDuration: TimeInterval
    let totalDomainDuration: TimeInterval

    var isEmpty: Bool {
        focusApps.isEmpty && otherApps.isEmpty && focusDomains.isEmpty && otherDomains.isEmpty
    }
}

/// All insights for one timeframe and date, computed in a single pass so views
/// never touch the database or scan sessions while rendering.
struct InsightsSnapshot {
    let displayedDateString: String
    let totalFocusTime: TimeInterval
    let totalFocusTimeThisMonth: TimeInterval
    let sessionCount: Int
    let weekdayData: [DayData]
    let hourlyData: [HourData]
    let averageDailyMinutes: Int
    let weekComparisonPercentage: Int?
    let activity: ActivityBreakdown
    let focusDuration: TimeInterval
    let otherDuration: TimeInterval
    let disruptionSummary: DisruptionSummary
    let previousPeriodDisruptions: DisruptionSummary
    let disruptionOverTime: [HourlyDisruptionData]
    let longestSession: FocusSession?
    let averageSessionLength: TimeInterval
    let deepFocusSessions: (deep: Int, total: Int)
    let contextSwitchesPerSession: Double
    let focusScore: Int
    /// Formatted most productive two-hour range, nil without data.
    let productiveTimeRange: String?
    /// Full weekday name of the most productive weekday, nil without data.
    let productiveWeekday: String?
    /// Average daily focus time per weekday, starting on Monday.
    let weekdayAverages: [(day: String, average: TimeInterval)]
}

class InsightsDataProvider {
    let focusManager: FocusManager
    private let appEventRepo: AppEventRepository

    private static let topListLimit = 5
    private static let allAppsLimit = 100
    private static let deepFocusThreshold: TimeInterval = 25 * 60

    init(focusManager: FocusManager = FocusManager.shared, appEventRepo: AppEventRepository = AppEventRepository()) {
        self.focusManager = focusManager
        self.appEventRepo = appEventRepo
    }

    enum Timeframe: String, CaseIterable, Identifiable {
        case day = "Today"
        case week = "Last Week"

        var id: String { self.rawValue }
    }

    // MARK: - Snapshot

    /// Computes every insight for the given timeframe and date. Runs the database
    /// queries once each, so call it only when inputs change.
    func makeSnapshot(timeframe: Timeframe, selectedDate: Date) -> InsightsSnapshot {
        let calendar = Calendar.current
        let sessions = relevantSessions(timeframe: timeframe, selectedDate: selectedDate)
        let totalFocus = sessions.reduce(0) { $0 + $1.duration }
        let focusBundleIDs = Set(focusManager.focusApps.map(\.bundleIdentifier))
        let focusURLs = focusManager.focusURLs

        let weekdayData = weekdayData(selectedDate: selectedDate, selectedTimeframe: timeframe)

        let bounds = dateBounds(timeframe: timeframe, selectedDate: selectedDate)
        let allApps = (try? appEventRepo.fetchTopApps(since: bounds.start, until: bounds.end, limit: Self.allAppsLimit)) ?? []
        let topApps = Array(allApps.prefix(Self.topListLimit))
        let topDomains = (try? appEventRepo.fetchTopDomains(since: bounds.start, until: bounds.end, limit: Self.topListLimit)) ?? []
        let totalTracked = allApps.reduce(0) { $0 + $1.totalDuration }
        let ratio = focusVsOtherRatio(apps: allApps, focusBundleIDs: focusBundleIDs)

        let sessionEvents = sessionEvents(timeframe: timeframe, selectedDate: selectedDate, sessions: sessions)
        let disruptions = sessionEvents.map {
            ActivityInsightsService.calculateDisruptions(events: $0, focusBundleIDs: focusBundleIDs, focusDomains: focusURLs)
        } ?? DisruptionSummary(totalSwitches: 0, distractors: [])
        let disruptionOverTime = sessionEvents.map {
            disruptionOverTime(events: $0, timeframe: timeframe, selectedDate: selectedDate, focusBundleIDs: focusBundleIDs, focusURLs: focusURLs)
        } ?? []

        let productiveTimeRange = calculateProductiveTimeRange().map { formatHourRange($0.startHour, $0.endHour) }
        let productiveWeekday = calculateProductiveWeekday().map { calendar.weekdaySymbols[$0.weekday - 1] }

        return InsightsSnapshot(
            displayedDateString: displayedDateString(timeframe: timeframe, selectedDate: selectedDate),
            totalFocusTime: totalFocus,
            totalFocusTimeThisMonth: calculateTotalFocusTimeThisMonth(),
            sessionCount: sessions.count,
            weekdayData: weekdayData,
            hourlyData: hourlyData(selectedDate: selectedDate),
            averageDailyMinutes: averageDailyMinutes(weekdayData: weekdayData),
            weekComparisonPercentage: weekComparisonPercentage(timeframe: timeframe, selectedDate: selectedDate),
            activity: activityBreakdown(apps: topApps, domains: topDomains, focusBundleIDs: focusBundleIDs, focusURLs: focusURLs),
            focusDuration: ratio.focusDuration,
            otherDuration: ratio.otherDuration,
            disruptionSummary: disruptions,
            previousPeriodDisruptions: previousPeriodDisruptions(
                timeframe: timeframe, selectedDate: selectedDate, focusBundleIDs: focusBundleIDs, focusURLs: focusURLs
            ),
            disruptionOverTime: disruptionOverTime,
            longestSession: sessions.max(by: { $0.duration < $1.duration }),
            averageSessionLength: sessions.isEmpty ? 0 : totalFocus / Double(sessions.count),
            deepFocusSessions: (deep: sessions.filter { $0.duration >= Self.deepFocusThreshold }.count, total: sessions.count),
            contextSwitchesPerSession: sessions.isEmpty ? 0 : Double(disruptions.totalSwitches) / Double(sessions.count),
            focusScore: focusScore(
                sessions: sessions, totalTracked: totalTracked, totalSwitches: disruptions.totalSwitches, timeframe: timeframe
            ),
            productiveTimeRange: productiveTimeRange,
            productiveWeekday: productiveWeekday,
            weekdayAverages: rearrangeWeekdaysStartingMonday(calculateWeekdayAverages())
        )
    }

    // MARK: - Sessions

    func sessionsForDate(_ date: Date) -> [FocusSession] {
        let calendar = Calendar.current
        return focusManager.focusSessions.filter { calendar.isDate($0.startTime, inSameDayAs: date) }
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

    private func weekComparisonPercentage(timeframe: Timeframe, selectedDate: Date) -> Int? {
        guard timeframe == .week else { return nil }

        let calendar = Calendar.current
        let thisWeekStart = calendar.startOfWeek(for: selectedDate)
        guard let lastWeekStart = calendar.date(byAdding: .day, value: -7, to: thisWeekStart) else { return nil }

        let thisWeekDuration = totalFocusTimeInWeek(starting: thisWeekStart)
        let lastWeekDuration = totalFocusTimeInWeek(starting: lastWeekStart)

        guard lastWeekDuration > 0 else { return nil }

        let delta = thisWeekDuration - lastWeekDuration
        return Int((delta / lastWeekDuration) * 100)
    }

    // MARK: - Charts

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
        let dayStart = calendar.startOfDay(for: selectedDate)

        return (0..<24).map { hour in
            let hourStart = calendar.date(byAdding: .hour, value: hour, to: dayStart)!
            let hourEnd = calendar.date(byAdding: .hour, value: 1, to: hourStart)!

            // Calculate total time for this hour by summing portions of sessions that overlap
            var totalDuration: TimeInterval = 0

            for session in sessions {
                // Calculate overlap between session and this hour
                let sessionStart = max(session.startTime, hourStart)
                let sessionEnd = min(session.endTime, hourEnd)

                if sessionStart < sessionEnd {
                    totalDuration += sessionEnd.timeIntervalSince(sessionStart)
                }
            }

            let totalMinutes = Int(totalDuration / 60)
            return HourData(hour: hour, totalMinutes: totalMinutes)
        }
    }

    func averageDailyMinutes(weekdayData: [DayData]) -> Int {
        let daysWithSessions = weekdayData.filter { $0.totalMinutes > 0 }
        guard !daysWithSessions.isEmpty else { return 0 }

        let totalMinutes = daysWithSessions.reduce(0) { $0 + $1.totalMinutes }
        return totalMinutes / daysWithSessions.count
    }

    // MARK: - Productivity Patterns

    func calculateProductiveTimeRange() -> (startHour: Int, endHour: Int, duration: TimeInterval)? {
        let allSessions = focusManager.focusSessions
        let calendar = Calendar.current

        // Calculate total duration per hour (accounting for sessions spanning multiple hours)
        var hourlyTotals = Array(repeating: TimeInterval(0), count: 24)

        for session in allSessions {
            // Walk the session in absolute clock-hour chunks so sessions crossing
            // midnight (or any day boundary) land in the correct hour buckets.
            var chunkStart = session.startTime
            while chunkStart < session.endTime {
                guard let hourInterval = calendar.dateInterval(of: .hour, for: chunkStart) else { break }
                let chunkEnd = min(hourInterval.end, session.endTime)
                let hour = calendar.component(.hour, from: chunkStart)
                hourlyTotals[hour] += chunkEnd.timeIntervalSince(chunkStart)
                chunkStart = chunkEnd
            }
        }

        // Find the best consecutive 2-hour period
        var maxDuration: TimeInterval = 0
        var maxStartHour = 0

        for startHour in 0..<24 {
            let endHour = startHour + 1
            let combinedDuration: TimeInterval

            if endHour < 24 {
                // Normal case: consecutive hours within same day
                combinedDuration = hourlyTotals[startHour] + hourlyTotals[endHour]
            } else {
                // Wrap-around: last hour (23) + first hour (0) of next day
                combinedDuration = hourlyTotals[23] + hourlyTotals[0]
            }

            if combinedDuration > maxDuration {
                maxDuration = combinedDuration
                maxStartHour = startHour
            }
        }

        if maxDuration > 0 {
            let endHour = maxStartHour + 1
            // Handle wrap-around: if endHour is 24, it means midnight (0), but we'll display it as 24
            return (startHour: maxStartHour, endHour: endHour >= 24 ? 24 : endHour, duration: maxDuration)
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

    private func rearrangeWeekdaysStartingMonday(_ weekdayData: [(day: String, average: TimeInterval)]) -> [(day: String, average: TimeInterval)] {
        // American calendar: Sunday is at index 0, we need to move it to the end
        var rearranged = weekdayData
        if weekdayData.count == 7 {
            let sunday = rearranged.removeFirst()
            rearranged.append(sunday)
        }
        return rearranged
    }

    // MARK: - Formatting

    func formatHourRange(_ startHour: Int, _ endHour: Int) -> String {
        let formatter = DateFormatter.hourOfDay

        var startComponents = DateComponents()
        startComponents.hour = startHour

        var endComponents = DateComponents()
        // Handle midnight wrap-around: 24 means midnight (0) of next day
        endComponents.hour = endHour >= 24 ? 0 : endHour

        let calendar = Calendar.current
        if let startDate = calendar.date(from: startComponents),
           let endDate = calendar.date(from: endComponents) {
            // If endHour is 24, show it as "12 AM" (midnight)
            if endHour >= 24 {
                return "\(formatter.string(from: startDate))–12 AM"
            }
            return "\(formatter.string(from: startDate))–\(formatter.string(from: endDate))"
        }

        // Fallback: handle midnight case
        if endHour >= 24 {
            return "\(startHour) PM–12 AM"
        }
        return "\(startHour)–\(endHour)"
    }

    func dateString(for date: Date) -> String {
        let calendar = Calendar.current

        // If it's today, just say "Today"
        if calendar.isDateInToday(date) {
            return "Today"
        }

        // If it's yesterday, say "Yesterday"
        if calendar.isDateInYesterday(date) {
            return "Yesterday"
        }

        // For other dates, use a compact format with abbreviated weekday and month
        return DateFormatter.weekdayMonthDay.string(from: date)
    }

    private func displayedDateString(timeframe: Timeframe, selectedDate: Date) -> String {
        if timeframe == .day {
            return dateString(for: selectedDate)
        }

        let calendar = Calendar.current
        let now = Date()
        let startOfWeek = calendar.startOfWeek(for: selectedDate)
        let endOfWeek = calendar.date(byAdding: .day, value: 6, to: startOfWeek)!

        if calendar.isDate(startOfWeek, equalTo: now, toGranularity: .weekOfYear) {
            return "This week"
        } else if let lastWeek = calendar.date(byAdding: .weekOfYear, value: -1, to: now),
                  calendar.isDate(startOfWeek, equalTo: lastWeek, toGranularity: .weekOfYear) {
            return "Last week"
        }
        let formatter = DateFormatter.monthDay
        return "\(formatter.string(from: startOfWeek))–\(formatter.string(from: endOfWeek))"
    }

    // MARK: - Activity Insights

    private func dateBounds(timeframe: Timeframe, selectedDate: Date) -> (start: Date, end: Date) {
        let calendar = Calendar.current
        switch timeframe {
        case .day:
            let start = calendar.startOfDay(for: selectedDate)
            let end = calendar.date(byAdding: .day, value: 1, to: start)!
            return (start, end)
        case .week:
            let start = calendar.startOfWeek(for: selectedDate)
            let end = calendar.date(byAdding: .day, value: 7, to: start)!
            return (start, end)
        }
    }

    private func activityBreakdown(
        apps: [AppUsageSummary],
        domains: [DomainUsageSummary],
        focusBundleIDs: Set<String>,
        focusURLs: [FocusURL]
    ) -> ActivityBreakdown {
        let isFocusDomain: (DomainUsageSummary) -> Bool = { domain in
            focusURLs.contains { $0.matches(domain.domain) || $0.matches("https://\(domain.domain)") }
        }
        return ActivityBreakdown(
            focusApps: apps.filter { focusBundleIDs.contains($0.bundleIdentifier) },
            otherApps: apps.filter { !focusBundleIDs.contains($0.bundleIdentifier) },
            focusDomains: domains.filter(isFocusDomain),
            otherDomains: domains.filter { !isFocusDomain($0) },
            totalAppDuration: apps.reduce(0) { $0 + $1.totalDuration },
            totalDomainDuration: domains.reduce(0) { $0 + $1.totalDuration }
        )
    }

    /// Events of the period that happened during one of the given sessions, or nil if the fetch failed.
    /// Only context switches during an active focus session count as disruptions.
    private func sessionEvents(timeframe: Timeframe, selectedDate: Date, sessions: [FocusSession]) -> [AppEvent]? {
        let bounds = dateBounds(timeframe: timeframe, selectedDate: selectedDate)
        guard let events = try? appEventRepo.fetchEvents(since: bounds.start, until: bounds.end) else {
            return nil
        }
        return filterEventsToSessions(events, sessions: sessions)
    }

    private func disruptionOverTime(
        events: [AppEvent],
        timeframe: Timeframe,
        selectedDate: Date,
        focusBundleIDs: Set<String>,
        focusURLs: [FocusURL]
    ) -> [HourlyDisruptionData] {
        switch timeframe {
        case .day:
            return ActivityInsightsService.calculateHourlyDisruptions(
                events: events, focusBundleIDs: focusBundleIDs, focusDomains: focusURLs
            )
        case .week:
            let weekStart = Calendar.current.startOfWeek(for: selectedDate)
            return ActivityInsightsService.calculateDailyDisruptions(
                events: events, focusBundleIDs: focusBundleIDs, focusDomains: focusURLs, weekStart: weekStart
            )
        }
    }

    private func previousPeriodDisruptions(
        timeframe: Timeframe,
        selectedDate: Date,
        focusBundleIDs: Set<String>,
        focusURLs: [FocusURL]
    ) -> DisruptionSummary {
        let calendar = Calendar.current
        let previousDate: Date
        switch timeframe {
        case .day:
            previousDate = calendar.date(byAdding: .day, value: -1, to: selectedDate) ?? selectedDate
        case .week:
            previousDate = calendar.date(byAdding: .day, value: -7, to: selectedDate) ?? selectedDate
        }
        let sessions = relevantSessions(timeframe: timeframe, selectedDate: previousDate)
        guard let events = sessionEvents(timeframe: timeframe, selectedDate: previousDate, sessions: sessions) else {
            return DisruptionSummary(totalSwitches: 0, distractors: [])
        }
        return ActivityInsightsService.calculateDisruptions(
            events: events, focusBundleIDs: focusBundleIDs, focusDomains: focusURLs
        )
    }

    private func filterEventsToSessions(_ events: [AppEvent], sessions: [FocusSession]) -> [AppEvent] {
        guard !sessions.isEmpty else { return [] }
        return events.filter { event in
            sessions.contains { event.timestamp >= $0.startTime && event.timestamp <= $0.endTime }
        }
    }

    // MARK: - Focus Score

    private func focusScore(
        sessions: [FocusSession],
        totalTracked: TimeInterval,
        totalSwitches: Int,
        timeframe: Timeframe
    ) -> Int {
        guard !sessions.isEmpty else { return 0 }

        let totalFocus = sessions.reduce(0) { $0 + $1.duration }
        let focusRatio = totalTracked > 0 ? min(1.0, totalFocus / totalTracked) : 0

        let avgSession = totalFocus / Double(sessions.count)
        let sessionDepth = min(1.0, avgSession / 3600.0)

        let consistencyDays: Double
        switch timeframe {
        case .day:
            consistencyDays = 1.0
        case .week:
            let calendar = Calendar.current
            let daysWithSessions = Set(sessions.map { calendar.startOfDay(for: $0.startTime) })
            consistencyDays = Double(daysWithSessions.count) / 7.0
        }

        let switchRate = Double(totalSwitches) / Double(sessions.count)
        let lowDistraction = max(0, 1.0 - min(1.0, switchRate / 10.0))

        let score = focusRatio * 0.4 + sessionDepth * 0.3 + consistencyDays * 0.15 + lowDistraction * 0.15
        return min(100, Int(score * 100))
    }

    // MARK: - Focus vs Other Split

    private func focusVsOtherRatio(
        apps: [AppUsageSummary],
        focusBundleIDs: Set<String>
    ) -> (focusDuration: TimeInterval, otherDuration: TimeInterval) {
        var focusDuration: TimeInterval = 0
        var otherDuration: TimeInterval = 0

        for app in apps {
            if focusBundleIDs.contains(app.bundleIdentifier) {
                focusDuration += app.totalDuration
            } else {
                otherDuration += app.totalDuration
            }
        }

        return (focusDuration: focusDuration, otherDuration: otherDuration)
    }
}

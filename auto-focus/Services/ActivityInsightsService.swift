import Foundation

struct DisruptionSummary {
    let totalSwitches: Int
    let distractors: [(name: String, count: Int)]
}

struct HourlyDisruptionData: Identifiable {
    let id = UUID()
    let bucket: Int
    let label: String
    let switches: Int
}

struct ActivityInsightsService {
    static func calculateDisruptions(
        events: [AppEvent],
        focusBundleIDs: Set<String>,
        focusDomains: [FocusURL]
    ) -> DisruptionSummary {
        guard events.count >= 2 else {
            return DisruptionSummary(totalSwitches: 0, distractors: [])
        }

        var distractorCounts: [String: Int] = [:]
        var totalSwitches = 0

        for i in 0..<(events.count - 1) {
            let current = events[i]
            let next = events[i + 1]

            let currentIsFocus = isInFocusContext(event: current, focusBundleIDs: focusBundleIDs, focusDomains: focusDomains)
            let nextIsFocus = isInFocusContext(event: next, focusBundleIDs: focusBundleIDs, focusDomains: focusDomains)

            if currentIsFocus && !nextIsFocus {
                totalSwitches += 1
                let name = distractorName(for: next)
                distractorCounts[name, default: 0] += 1
            }
        }

        let sorted = distractorCounts
            .map { (name: $0.key, count: $0.value) }
            .sorted { $0.count > $1.count }

        return DisruptionSummary(totalSwitches: totalSwitches, distractors: sorted)
    }

    static func calculateHourlyDisruptions(
        events: [AppEvent],
        focusBundleIDs: Set<String>,
        focusDomains: [FocusURL]
    ) -> [HourlyDisruptionData] {
        let calendar = Calendar.current
        var buckets = Array(repeating: 0, count: 24)

        guard events.count >= 2 else {
            return (0..<24).map { HourlyDisruptionData(bucket: $0, label: String(format: "%02d", $0), switches: 0) }
        }

        for i in 0..<(events.count - 1) {
            let current = events[i]
            let next = events[i + 1]

            let currentIsFocus = isInFocusContext(event: current, focusBundleIDs: focusBundleIDs, focusDomains: focusDomains)
            let nextIsFocus = isInFocusContext(event: next, focusBundleIDs: focusBundleIDs, focusDomains: focusDomains)

            if currentIsFocus && !nextIsFocus {
                let hour = calendar.component(.hour, from: next.timestamp)
                buckets[hour] += 1
            }
        }

        return (0..<24).map { hour in
            HourlyDisruptionData(bucket: hour, label: String(format: "%02d", hour), switches: buckets[hour])
        }
    }

    static func calculateDailyDisruptions(
        events: [AppEvent],
        focusBundleIDs: Set<String>,
        focusDomains: [FocusURL],
        weekStart: Date
    ) -> [HourlyDisruptionData] {
        let calendar = Calendar.current
        var buckets = Array(repeating: 0, count: 7)

        guard events.count >= 2 else {
            return (0..<7).map { offset in
                let date = calendar.date(byAdding: .day, value: offset, to: weekStart)!
                let weekday = calendar.component(.weekday, from: date)
                let symbol = String(calendar.shortWeekdaySymbols[weekday - 1].prefix(3))
                return HourlyDisruptionData(bucket: offset, label: symbol, switches: 0)
            }
        }

        for i in 0..<(events.count - 1) {
            let current = events[i]
            let next = events[i + 1]

            let currentIsFocus = isInFocusContext(event: current, focusBundleIDs: focusBundleIDs, focusDomains: focusDomains)
            let nextIsFocus = isInFocusContext(event: next, focusBundleIDs: focusBundleIDs, focusDomains: focusDomains)

            if currentIsFocus && !nextIsFocus {
                let dayStart = calendar.startOfDay(for: next.timestamp)
                let dayOffset = calendar.dateComponents([.day], from: calendar.startOfDay(for: weekStart), to: dayStart).day ?? 0
                if dayOffset >= 0 && dayOffset < 7 {
                    buckets[dayOffset] += 1
                }
            }
        }

        return (0..<7).map { offset in
            let date = calendar.date(byAdding: .day, value: offset, to: weekStart)!
            let weekday = calendar.component(.weekday, from: date)
            let symbol = String(calendar.shortWeekdaySymbols[weekday - 1].prefix(3))
            return HourlyDisruptionData(bucket: offset, label: symbol, switches: buckets[offset])
        }
    }

    private static func isInFocusContext(
        event: AppEvent,
        focusBundleIDs: Set<String>,
        focusDomains: [FocusURL]
    ) -> Bool {
        if focusBundleIDs.contains(event.bundleIdentifier) {
            return true
        }

        if let domain = event.domain {
            return focusDomains.contains { focusURL in
                focusURL.matches(domain) || focusURL.matches("https://\(domain)")
            }
        }

        return false
    }

    private static func distractorName(for event: AppEvent) -> String {
        if let domain = event.domain {
            return domain
        }
        return BundleNameMapper.displayName(bundleIdentifier: event.bundleIdentifier, appName: event.appName)
    }
}

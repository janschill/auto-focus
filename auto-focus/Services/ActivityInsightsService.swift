import Foundation

struct DisruptionSummary {
    let totalSwitches: Int
    let distractors: [(name: String, count: Int)]
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
        return event.appName ?? event.bundleIdentifier
    }
}

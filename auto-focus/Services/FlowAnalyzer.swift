import Foundation

/// The apps and sites the user counts as focus work.
struct FocusContext: Equatable {
    let bundleIDs: Set<String>
    let urls: [FocusURL]

    /// Whether the app (or, for a browser tab, the domain) of the event is focus work.
    func contains(_ event: AppEvent) -> Bool {
        if bundleIDs.contains(event.bundleIdentifier) {
            return true
        }
        guard let domain = event.domain else { return false }
        return urls.contains { $0.matches(domain) || $0.matches("https://\(domain)") }
    }
}

/// How fragmented attention was over a stretch of time.
enum FlowState: String {
    /// Nearly all time in focus work with only a few switches.
    case flow
    /// Mostly focus work, interrupted more often.
    case focused
    /// Rapid switching between apps, whether they are focus apps or not.
    case scattered
    /// Calm, but mostly outside focus work (meetings, reading, away).
    case neutral
}

/// A stretch of time spent in a single context.
struct AttentionSpan: Equatable {
    let start: Date
    let end: Date
    let isFocus: Bool

    var duration: TimeInterval { end.timeIntervalSince(start) }
}

/// The flow state of the trailing window and how many app switches it contained.
struct FlowReading: Equatable {
    let state: FlowState
    let switches: Int
}

/// Time per flow state and the longest unbroken focus stretch over a period.
struct FlowSummary: Equatable {
    var flowTime: TimeInterval = 0
    var focusedTime: TimeInterval = 0
    var scatteredTime: TimeInterval = 0
    var longestFocusStretch: TimeInterval = 0
}

/// Classifies attention from the app event log in fixed windows.
///
/// Thresholds come from a replay of one user's real usage: across ~2,100 ten-minute work windows
/// the median was 12 app switches (p75: 21).
enum FlowAnalyzer {
    static let windowLength: TimeInterval = 10 * 60
    /// A window needs this much recorded time to be classified.
    static let minActiveTimePerWindow: TimeInterval = 5 * 60
    static let flowMaxSwitches = 6
    static let flowMinFocusShare = 0.8
    static let focusedMinFocusShare = 0.5
    static let scatteredMinSwitches = 20
    /// A span with no new event for longer than this is dropped as unknown: in event logs without away
    /// markers these are mostly walk-aways, and crediting them would invent flow.
    static let maxSpanWithoutActivity: TimeInterval = 30 * 60
    /// Non-focus visits shorter than this (Dock, menu bar clicks) don't break a focus stretch.
    static let blipDuration: TimeInterval = 3

    static func classify(switches: Int, focusShare: Double) -> FlowState {
        if switches >= scatteredMinSwitches {
            return .scattered
        }
        if focusShare >= flowMinFocusShare && switches <= flowMaxSwitches {
            return .flow
        }
        if focusShare >= focusedMinFocusShare {
            return .focused
        }
        return .neutral
    }

    /// Turns chronologically ordered events into context spans ending at `end`.
    /// A browser activation keeps the last domain seen in that browser until a new tab event arrives.
    /// Spans longer than `maxSpanWithoutActivity` are dropped, except the ongoing last span when
    /// `keepOngoingSpan` is set (the caller knows the user is present).
    static func spans(
        events: [AppEvent],
        context: FocusContext,
        until end: Date,
        keepOngoingSpan: Bool = false
    ) -> [AttentionSpan] {
        var lastDomainByBrowser: [String: String] = [:]
        var result: [AttentionSpan] = []

        for (index, event) in events.enumerated() {
            var resolved = event
            if event.eventType == "tab_changed" {
                if let domain = event.domain {
                    lastDomainByBrowser[event.bundleIdentifier] = domain
                }
            } else if AppConfiguration.isSupportedBrowser(event.bundleIdentifier) {
                resolved.domain = lastDomainByBrowser[event.bundleIdentifier]
            }

            guard !AppConfiguration.isScreenInactiveApp(event.bundleIdentifier) else { continue }

            let isLast = index + 1 == events.count
            let spanEnd = min(isLast ? end : events[index + 1].timestamp, end)
            let duration = spanEnd.timeIntervalSince(event.timestamp)
            guard duration > 0, duration <= maxSpanWithoutActivity || (isLast && keepOngoingSpan) else { continue }
            result.append(AttentionSpan(start: event.timestamp, end: spanEnd, isFocus: context.contains(resolved)))
        }
        return result
    }

    /// Classifies each window between `start` and `end` and sums the recorded time per state.
    static func summary(events: [AppEvent], context: FocusContext, from start: Date, to end: Date) -> FlowSummary {
        let allSpans = spans(events: events, context: context, until: end)
        let switchTimes = activationTimes(events)
        var summary = FlowSummary(longestFocusStretch: longestFocusStretch(allSpans, from: start, to: end))

        var windowStart = start
        while windowStart < end {
            let windowEnd = min(windowStart.addingTimeInterval(windowLength), end)
            let window = measure(spans: allSpans, switchTimes: switchTimes, from: windowStart, to: windowEnd)
            if window.activeTime >= minActiveTimePerWindow {
                switch window.state {
                case .flow: summary.flowTime += window.activeTime
                case .focused: summary.focusedTime += window.activeTime
                case .scattered: summary.scatteredTime += window.activeTime
                case .neutral: break
                }
            }
            windowStart = windowEnd
        }
        return summary
    }

    /// Reading of the trailing window ending at `now`. Include the last event before the window
    /// so the context at its start is known.
    /// When the user isn't present (idle), the state is neutral whatever the log says.
    static func currentReading(events: [AppEvent], context: FocusContext, now: Date, userIsPresent: Bool) -> FlowReading {
        let pastEvents = events.filter { $0.timestamp <= now }
        let window = measure(
            spans: spans(events: pastEvents, context: context, until: now, keepOngoingSpan: userIsPresent),
            switchTimes: activationTimes(pastEvents),
            from: now.addingTimeInterval(-windowLength),
            to: now
        )
        let state = userIsPresent && window.activeTime >= minActiveTimePerWindow ? window.state : .neutral
        return FlowReading(state: state, switches: window.switches)
    }

    // MARK: - Private

    private struct WindowMeasurement {
        let activeTime: TimeInterval
        let switches: Int
        let state: FlowState
    }

    /// App switches: activations of real apps, not tab changes or away markers.
    private static func activationTimes(_ events: [AppEvent]) -> [Date] {
        events
            .filter { $0.eventType == "activate" && !AppConfiguration.isScreenInactiveApp($0.bundleIdentifier) }
            .map(\.timestamp)
    }

    private static func measure(spans: [AttentionSpan], switchTimes: [Date], from start: Date, to end: Date) -> WindowMeasurement {
        var activeTime: TimeInterval = 0
        var focusTime: TimeInterval = 0
        for span in spans {
            let overlap = min(span.end, end).timeIntervalSince(max(span.start, start))
            guard overlap > 0 else { continue }
            activeTime += overlap
            if span.isFocus {
                focusTime += overlap
            }
        }
        let switches = switchTimes.filter { $0 >= start && $0 < end }.count
        let share = activeTime > 0 ? focusTime / activeTime : 0
        return WindowMeasurement(
            activeTime: activeTime,
            switches: switches,
            state: classify(switches: switches, focusShare: share)
        )
    }

    /// Longest run of contiguous focus spans; blips pass through, any other non-focus span or gap ends the run.
    private static func longestFocusStretch(_ spans: [AttentionSpan], from start: Date, to end: Date) -> TimeInterval {
        var longest: TimeInterval = 0
        var current: TimeInterval = 0
        var previousEnd: Date?

        for span in spans {
            let clippedStart = max(span.start, start)
            let clippedEnd = min(span.end, end)
            guard clippedEnd > clippedStart else { continue }
            let duration = clippedEnd.timeIntervalSince(clippedStart)
            let isContiguous = previousEnd == clippedStart

            if span.isFocus {
                current = isContiguous ? current + duration : duration
            } else if !(isContiguous && duration < blipDuration) {
                current = 0
            }
            longest = max(longest, current)
            previousEnd = clippedEnd
        }
        return longest
    }
}

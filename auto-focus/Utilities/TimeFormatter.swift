import Foundation
import SwiftUI

struct TimeFormatter {
    /// Compact timer display: `mm:ss` — for active countdowns / live timers.
    static func duration(_ timeInterval: TimeInterval) -> String {
        let minutes = Int(timeInterval) / 60
        let seconds = Int(timeInterval) % 60
        return String(format: "%02d:%02d", minutes, seconds)
    }

    static func duration(_ minutes: Int) -> String {
        return minutes >= 60 ? "\(minutes / 60)h \(minutes % 60)m" : "\(minutes)m"
    }

    /// Human-readable duration from seconds: `3h 21m`, `45m`, `< 1m`.
    /// Use for stats, summaries, and anywhere the user isn't watching a live timer.
    static func humanReadable(_ timeInterval: TimeInterval) -> String {
        let totalMinutes = Int(timeInterval) / 60
        if totalMinutes >= 60 {
            let hours = totalMinutes / 60
            let minutes = totalMinutes % 60
            return minutes > 0 ? "\(hours)h \(minutes)m" : "\(hours)h"
        }
        if totalMinutes > 0 {
            return "\(totalMinutes)m"
        }
        return "< 1m"
    }

    static func minutes(_ timeInterval: TimeInterval) -> String {
        let minutes = Int(timeInterval) / 60
        return "\(minutes)m"
    }
}

extension DateFormatter {
    static let filenameSafe: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd-HHmm"
        return formatter
    }()
}

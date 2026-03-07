import SwiftUI

struct MenuBarView: View {
    @EnvironmentObject var focusManager: FocusManager
    @ObservedObject private var versionCheckManager = VersionCheckManager.shared

    var version: String {
    #if DEBUG
            return "DEBUG"
    #else
            return Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0.0"
    #endif
    }

    // Calculate total focus time today
    var totalFocusTimeToday: TimeInterval {
        return focusManager.todaysSessions.reduce(0) { $0 + $1.duration }
    }

    // Calculate average daily focus time (last 7 days)
    var averageDailyFocus: TimeInterval {
        let lastWeekSessions = focusManager.weekSessions
        let daysWithSessions = Set(lastWeekSessions.map { Calendar.current.startOfDay(for: $0.startTime) }).count
        guard daysWithSessions > 0 else { return 0 }
        let totalTime = lastWeekSessions.reduce(0) { $0 + $1.duration }
        return totalTime / Double(daysWithSessions)
    }

    // Calculate focus streak (consecutive days with focus sessions)
    var focusStreak: Int {
        let calendar = Calendar.current
        var streak = 0
        var currentDate = Date()

        while true {
            let dayStart = calendar.startOfDay(for: currentDate)
            let dayEnd = calendar.date(byAdding: .day, value: 1, to: dayStart)!

            let hasSessions = focusManager.focusSessions.contains { session in
                session.startTime >= dayStart && session.startTime < dayEnd
            }

            if hasSessions {
                streak += 1
                currentDate = calendar.date(byAdding: .day, value: -1, to: currentDate)!
            } else {
                break
            }
        }

        return streak
    }

    // Get best session duration
    var bestSessionDuration: TimeInterval {
        return focusManager.weekSessions.map { $0.duration }.max() ?? 0
    }

    // Progress to DND activation
    var progressToDND: Double {
        guard focusManager.isInOverallFocus && !focusManager.isInFocusMode else { return 0 }
        return min(focusManager.timeSpent / (focusManager.focusThreshold * 60), 1.0)
    }

    // Get current app name
    var currentAppName: String? {
        return focusManager.currentAppInfo?.name
    }

    // Get primary status with icon
    var primaryStatus: (icon: String, text: String, color: Color) {
        if focusManager.isPaused {
            return ("pause.circle.fill", "Paused", .orange)
        } else if focusManager.isInBufferPeriod {
            let remaining = Int(focusManager.bufferTimeRemaining)
            return ("clock.fill", "Buffer: \(remaining)s", .yellow)
        } else if focusManager.isInFocusMode {
            let appName = currentAppName ?? "Focus"
            let duration = TimeFormatter.duration(focusManager.timeSpent)
            return ("circle.fill", "\(appName) (\(duration))", .green)
        } else if focusManager.isInOverallFocus {
            let appName = currentAppName ?? "App"
            let duration = TimeFormatter.duration(focusManager.timeSpent)
            return ("circle.fill", "\(appName) (\(duration))", .blue)
        } else {
            return ("circle", "Out of Focus", .secondary)
        }
    }

    // Get next action hint
    var nextActionHint: String? {
        if focusManager.isInOverallFocus && !focusManager.isInFocusMode {
            let remainingMinutes = Int((focusManager.focusThreshold * 60 - focusManager.timeSpent) / 60)
            if remainingMinutes > 0 {
                return "\(remainingMinutes) more minute\(remainingMinutes == 1 ? "" : "s") to enter focus mode"
            } else {
                let remainingSeconds = Int(focusManager.focusThreshold * 60 - focusManager.timeSpent)
                return "\(remainingSeconds) seconds to enter focus mode"
            }
        } else if focusManager.isInFocusMode && focusManager.timeSpent > 5400 { // 90 minutes
            return "Take a break? You've been focused for \(TimeFormatter.duration(focusManager.timeSpent))"
        }
        return nil
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Primary Status Line
            HStack(spacing: 6) {
                Image(systemName: primaryStatus.icon)
                    .foregroundStyle(primaryStatus.color)
                    .font(.system(size: 14))
                Text(primaryStatus.text)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(primaryStatus.color)
                Spacer()
            }

            // Smart Progress Indicator (only show when building up to focus mode)
            if focusManager.isInOverallFocus && !focusManager.isInFocusMode {
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text("Progress to DND")
                            .font(.system(size: 11))
                            .foregroundStyle(.secondary)
                        Spacer()
                        Text("\(Int(progressToDND * 100))%")
                            .font(.system(size: 11, weight: .medium))
                        let remaining = Int((focusManager.focusThreshold * 60 - focusManager.timeSpent) / 60)
                        Text("(\(remaining)m left)")
                            .font(.system(size: 11))
                            .foregroundStyle(.secondary)
                    }

                    GeometryReader { geometry in
                        ZStack(alignment: .leading) {
                            RoundedRectangle(cornerRadius: 2)
                                .fill(Color.gray.opacity(0.2))
                                .frame(height: 4)

                            RoundedRectangle(cornerRadius: 2)
                                .fill(Color.blue)
                                .frame(width: geometry.size.width * progressToDND, height: 4)
                        }
                    }
                    .frame(height: 4)
                }
                .padding(.vertical, 4)
            }

            Divider()

            // Today's Focus Summary
            if totalFocusTimeToday > 0 {
                VStack(alignment: .leading, spacing: 6) {
                    HStack {
                        Text("Today")
                            .font(.system(size: 12, weight: .medium))
                        Spacer()
                        Text(TimeFormatter.duration(totalFocusTimeToday))
                            .font(.system(size: 12, weight: .semibold))

                        // Show comparison to average
                        if averageDailyFocus > 0 {
                            let percentChange = ((totalFocusTimeToday - averageDailyFocus) / averageDailyFocus) * 100
                            let changeSymbol = percentChange >= 0 ? "↑" : "↓"
                            let changeColor = percentChange >= 0 ? Color.green : Color.red

                            Text("(\(changeSymbol) \(Int(abs(percentChange)))% vs avg)")
                                .font(.system(size: 11))
                                .foregroundStyle(changeColor)
                        }
                    }
                }

                Divider()
            }

            // Quick Stats Section
            VStack(alignment: .leading, spacing: 6) {
                if focusStreak > 0 {
                    HStack {
                        Image(systemName: "flame.fill")
                            .foregroundStyle(.orange)
                            .font(.system(size: 11))
                        Text("Streak")
                            .font(.system(size: 12))
                            .foregroundStyle(.secondary)
                        Spacer()
                        Text("\(focusStreak) day\(focusStreak == 1 ? "" : "s")")
                            .font(.system(size: 12, weight: .medium))
                    }
                }

                HStack {
                    Image(systemName: "chart.bar.fill")
                        .foregroundStyle(.blue)
                        .font(.system(size: 11))
                    Text("This week")
                        .font(.system(size: 12))
                        .foregroundStyle(.secondary)
                    Spacer()
                    Text(TimeFormatter.duration(focusManager.weekSessions.reduce(0) { $0 + $1.duration }))
                        .font(.system(size: 12, weight: .medium))
                }

                if bestSessionDuration > 0 {
                    HStack {
                        Image(systemName: "star.fill")
                            .foregroundStyle(.yellow)
                            .font(.system(size: 11))
                        Text("Best session")
                            .font(.system(size: 12))
                            .foregroundStyle(.secondary)
                        Spacer()
                        Text(TimeFormatter.duration(bestSessionDuration))
                            .font(.system(size: 12, weight: .medium))
                    }
                }
            }

            // Next Action Hint
            if let hint = nextActionHint {
                Divider()

                HStack(spacing: 6) {
                    Image(systemName: "lightbulb.fill")
                        .foregroundStyle(.yellow)
                        .font(.system(size: 11))
                    Text(hint)
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                }
            }

            // App limit status for free users
            if focusManager.isPremiumRequired {
                Divider()

                HStack {
                    Image(systemName: "star.fill")
                        .foregroundStyle(.yellow)
                        .font(.system(size: 11))
                    Text("App limit reached - Premium needed")
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                }
            }

            // Update notification
            if versionCheckManager.isUpdateAvailable {
                Divider()

                HStack {
                    Image(systemName: "arrow.up.circle.fill")
                        .foregroundStyle(.blue)
                        .font(.system(size: 11))
                    Text("Update v\(versionCheckManager.latestVersion) available")
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)

                    Spacer()

                    Button("Download") {
                        versionCheckManager.openDownloadPage()
                    }
                    .controlSize(.mini)
                    .buttonStyle(.borderedProminent)
                }
            }

            Divider()

            // Controls section
            HStack {
                if #available(macOS 14.0, *) {
                    SettingsLink(label: {
                        Text("Settings...")
                            .foregroundStyle(.primary)
                    })
                    .keyboardShortcut(",", modifiers: .command)
                } else {
                    Button("Settings...") {
                        openSettings()
                    }
                    .keyboardShortcut(",", modifiers: .command)
                }

                Spacer()

                Button(action: {
                    focusManager.togglePause()
                }) {
                    HStack(spacing: 4) {
                        Image(systemName: focusManager.isPaused ? "play.fill" : "pause.fill")
                        Text(focusManager.isPaused ? "Start" : "Stop")
                    }
                }
                .help(focusManager.isPaused ? "Resume focus tracking" : "Stop focus tracking")

                Spacer()

                Button("Quit") {
                    NSApplication.shared.terminate(nil)
                }
                .keyboardShortcut("q", modifiers: .command)
            }
        }
        .padding(12)
        .frame(width: 290) // Slightly wider to accommodate new info
        .onAppear {
            versionCheckManager.checkForUpdates()
        }
    }

    private func openSettings() {
        // Send the standard settings command
        NSApp.sendAction(Selector(("showSettingsWindow:")), to: nil, from: nil)
    }
}

struct StatusRow: View {
    let title: String
    let value: String

    var body: some View {
        HStack {
            Text(title)
                .foregroundStyle(.secondary)
            Spacer()
            Text(value)
        }
        .font(.system(size: 13))
    }
}

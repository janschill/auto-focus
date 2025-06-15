import SwiftUI

struct MenuBarView: View {
    @EnvironmentObject var focusManager: FocusManager

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
    
    // Get current smart status
    var smartStatus: String {
        if focusManager.isPaused {
            return "Paused"
        } else if focusManager.isInBufferPeriod {
            let remaining = Int(focusManager.bufferTimeRemaining)
            return "Buffer: \(remaining)s"
        } else if focusManager.isInFocusMode {
            return "In Focus"
        } else if focusManager.isInOverallFocus {
            return "Focusing"
        } else {
            return "Out of Focus"
        }
    }
    
    var smartStatusColor: Color {
        if focusManager.isPaused {
            return .orange
        } else if focusManager.isInBufferPeriod {
            return .yellow
        } else if focusManager.isInFocusMode {
            return .green
        } else if focusManager.isInOverallFocus {
            return .blue
        } else {
            return .secondary
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Header with enhanced status
            HStack {
                Text("Auto-Focus")
                    .font(.system(size: 13, weight: .semibold))
                Text("BETA")
                Spacer()

                Text(smartStatus)
                    .foregroundStyle(smartStatusColor)
                    .font(.system(size: 12, weight: .medium))
            }

            Divider()

            // Enhanced session metrics
            VStack(alignment: .leading, spacing: 8) {
                if focusManager.timeSpent > 0 {
                    StatusRow(
                        title: "Current session",
                        value: TimeFormatter.duration(focusManager.timeSpent)
                    )
                }
                
                if totalFocusTimeToday > 0 {
                    StatusRow(
                        title: "Total focus today",
                        value: TimeFormatter.duration(totalFocusTimeToday)
                    )
                }

                StatusRow(
                    title: "Sessions today",
                    value: "\(focusManager.todaysSessions.count)"
                )
                
                StatusRow(
                    title: "Sessions this week",
                    value: "\(focusManager.weekSessions.count)"
                )

                if let lastSession = focusManager.todaysSessions.last {
                    StatusRow(
                        title: "Last session",
                        value: TimeFormatter.duration(lastSession.duration)
                    )
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
            } else if !focusManager.canAddMoreApps && !focusManager.isPremiumRequired {
                Divider()
                
                StatusRow(
                    title: "Focus apps",
                    value: "\(focusManager.focusApps.count)/\(focusManager.isPremiumRequired ? "∞" : "5")"
                )
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

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
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Auto-Focus")
                    .font(.system(size: 13, weight: .semibold))
//                Text(version)
                Text("BETA")
                Spacer()
                
                if focusManager.isPaused {
                    Text("Paused")
                        .foregroundStyle(.orange)
                } else {
                    Text("\(focusManager.isInFocusMode ? "In Focus" : "Out of Focus")")
                        .foregroundStyle(.secondary)
                }
            }
            
            Divider()
            
            VStack(alignment: .leading, spacing: 8) {
                if focusManager.timeSpent > 0 {
                    StatusRow(
                        title: "Time in focus",
                        value: timeString(from: focusManager.timeSpent)
                    )
                }
                
                StatusRow(
                    title: "Sessions today",
                    value: "\(focusManager.todaysSessions.count)"
                )
                
                if let lastSession = focusManager.todaysSessions.last {
                    StatusRow(
                        title: "Last session duration",
                        value: formatDuration(lastSession.duration)
                    )
                }
            }
            
            Divider()
            
            HStack {
                if #available(macOS 14.0, *) {
                    SettingsLink {
                        Text("Settings...")
                            .foregroundStyle(.primary)
                    }
                    .onTapGesture {
                        openSettings()
                    }
                    .keyboardShortcut(",", modifiers: .command)
                } else {
                    Button("Settings...") {
                        NSApp.sendAction(Selector(("showSettingsWindow:")), to: nil, from: nil)
                        openSettings()
                    }
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
        .frame(width: 280)
    }
    
    private func timeString(from timeInterval: TimeInterval) -> String {
        let minutes = Int(timeInterval) / 60
        let seconds = Int(timeInterval) % 60
        return String(format: "%02d:%02d", minutes, seconds)
    }
    
    private func formatDuration(_ duration: TimeInterval) -> String {
        let minutes = Int(duration) / 60
        return "\(minutes)m"
    }
    
    private func openSettings() {
        NSApp.setActivationPolicy(.regular)
        NSApp.activate(ignoringOtherApps: true)
        
        DispatchQueue.main.async {
            NSApp.windows.first?.orderFrontRegardless()
        }
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

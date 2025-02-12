//
//  MenuBarView.swift
//  auto-focus
//
//  Created by Jan Schill on 25/01/2025.
//

import SwiftUI

struct MenuBarView: View {
    @EnvironmentObject var focusManager: FocusManager
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Auto-Focus")
                    .font(.system(size: 13, weight: .semibold))
                Text(Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0.0")
                Spacer()
                Text("\(focusManager.isInFocusMode ? "On" : "Off")")
                    .foregroundStyle(.secondary)
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
                    .keyboardShortcut(",", modifiers: .command)
                } else {
                    Button("Settings...") {
                        NSApp.sendAction(Selector(("showSettingsWindow:")), to: nil, from: nil)
                    }
                }
                
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

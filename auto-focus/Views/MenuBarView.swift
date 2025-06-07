import SwiftUI

struct MenuBarView: View {
    @EnvironmentObject var focusManager: FocusManager
    @StateObject private var viewModel: MenuBarViewModel

    init() {
        _viewModel = StateObject(wrappedValue: MenuBarViewModel(focusManager: FocusManager.shared))
    }

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

                if viewModel.isPaused {
                    Text("Paused")
                        .foregroundStyle(.orange)
                } else {
                    Text("\(viewModel.isInFocusMode ? "In Focus" : "Out of Focus")")
                        .foregroundStyle(.secondary)
                }
            }

            Divider()

            VStack(alignment: .leading, spacing: 8) {
                if viewModel.timeSpent > 0 {
                    StatusRow(
                        title: "Time in focus",
                        value: TimeFormatter.duration(viewModel.timeSpent)
                    )
                }

                StatusRow(
                    title: "Sessions today",
                    value: "\(viewModel.todaysSessions.count)"
                )

                if let lastSession = viewModel.todaysSessions.last {
                    StatusRow(
                        title: "Last session duration",
                        value: TimeFormatter.duration(lastSession.duration)
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
                    viewModel.togglePause()
                }) {
                    HStack(spacing: 4) {
                        Image(systemName: viewModel.isPaused ? "play.fill" : "pause.fill")
                        Text(viewModel.isPaused ? "Start" : "Stop")
                    }
                }
                .help(viewModel.isPaused ? "Resume focus tracking" : "Stop focus tracking")

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

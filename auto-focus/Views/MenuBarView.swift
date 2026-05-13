import SwiftUI

struct MenuBarView: View {
    @EnvironmentObject var focusManager: FocusManager
    @EnvironmentObject var updaterController: UpdaterController
    @State private var showAddedSiteConfirmation = false
    @State private var showAddedAppConfirmation = false

    var version: String {
    #if DEBUG
            return "DEBUG"
    #else
            return Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0.0"
    #endif
    }

    var isBetaBuild: Bool {
        return version.contains("-beta")
    }

    var totalFocusTimeToday: TimeInterval {
        return focusManager.todaysSessions.reduce(0) { $0 + $1.duration }
    }

    var currentAppName: String? {
        return focusManager.currentAppInfo?.name
    }

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

    /// Whether the previous (non-Auto-Focus) app can be offered as a new focus app.
    private var canOfferAddApp: Bool {
        guard let bundleId = focusManager.previousNonSelfAppBundleId,
              !focusManager.isPreviousAppAlreadyFocusApp,
              !AppConfiguration.isSupportedBrowser(bundleId),
              focusManager.canAddMoreApps else { return false }
        return true
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Primary Status
            HStack(spacing: 6) {
                Image(systemName: primaryStatus.icon)
                    .foregroundStyle(primaryStatus.color)
                    .font(.system(size: 14))
                Text(primaryStatus.text)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(primaryStatus.color)
                Spacer()
            }

            Divider()

            // Today (single line, no comparison)
            if totalFocusTimeToday > 0 {
                HStack {
                    Text("Today")
                        .font(.system(size: 12, weight: .medium))
                    Spacer()
                    Text(TimeFormatter.humanReadable(totalFocusTimeToday))
                        .font(.system(size: 12, weight: .semibold))
                }

                Divider()
            }

            // Quick-add current app
            if canOfferAddApp, let appName = focusManager.previousNonSelfAppName {
                HStack {
                    if showAddedAppConfirmation {
                        Label("Added!", systemImage: "checkmark.circle.fill")
                            .font(.system(size: 12))
                            .foregroundStyle(.green)
                    } else {
                        Button {
                            addCurrentApp()
                        } label: {
                            HStack(spacing: 4) {
                                Image(systemName: "plus.circle")
                                Text("Add \(appName)")
                            }
                            .font(.system(size: 12))
                        }
                    }
                    Spacer()
                }
            }

            // Quick-add current site
            if let tab = focusManager.currentBrowserTab,
               !tab.isFocusURL,
               tab.url != "about:blank" {
                HStack {
                    if showAddedSiteConfirmation {
                        Label("Added!", systemImage: "checkmark.circle.fill")
                            .font(.system(size: 12))
                            .foregroundStyle(.green)
                    } else {
                        Button {
                            addCurrentSite(url: tab.url)
                        } label: {
                            HStack(spacing: 4) {
                                Image(systemName: "plus.circle")
                                Text("Add Current Site")
                            }
                            .font(.system(size: 12))
                        }
                    }
                    Spacer()
                }
            }

            Divider()

            // Beta indicator
            if isBetaBuild {
                HStack(spacing: 4) {
                    Text("BETA")
                        .font(.system(size: 9, weight: .bold))
                        .foregroundColor(.white)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Color.orange, in: Capsule())
                    Text(version)
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                }
            }

            // Controls
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

                Button("Check for Updates…") {
                    updaterController.checkForUpdates()
                }

                Spacer()

                Button("Quit") {
                    NSApplication.shared.terminate(nil)
                }
                .keyboardShortcut("q", modifiers: .command)
            }
        }
        .padding(12)
        .frame(width: 290)
    }

    private func openSettings() {
        NSApp.sendAction(Selector(("showSettingsWindow:")), to: nil, from: nil)
    }

    private func addCurrentApp() {
        guard let bundleId = focusManager.previousNonSelfAppBundleId,
              let name = focusManager.previousNonSelfAppName else { return }
        focusManager.addFocusAppByBundleId(bundleId, name: name)
        showAddedAppConfirmation = true
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
            showAddedAppConfirmation = false
        }
    }

    private func addCurrentSite(url: String) {
        guard let urlObj = URL(string: url), let host = urlObj.host else { return }
        let domain = host.hasPrefix("www.") ? String(host.dropFirst(4)) : host
        let focusURL = FocusURL(name: domain.capitalized, domain: domain)
        focusManager.addFocusURL(focusURL)
        showAddedSiteConfirmation = true
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
            showAddedSiteConfirmation = false
        }
    }
}

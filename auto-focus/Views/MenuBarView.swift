import SwiftUI

struct MenuBarView: View {
    @EnvironmentObject var focusManager: FocusManager
    @ObservedObject private var versionCheckManager = VersionCheckManager.shared
    @State private var showAddedSiteConfirmation = false
    @State private var showAddedAppConfirmation = false

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            MenuStatusHeader(status: status)

            if totalFocusTimeToday > 0 {
                MenuSeparator()
                todayRow
            }

            if hasQuickAddRows {
                MenuSeparator()
                quickAddRows
            }

            MenuSeparator()
            actionRows

            if isBetaBuild {
                MenuSeparator()
                Text("Auto-Focus \(version)")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 2)
            }
        }
        .padding(6)
        .frame(width: 290)
        .onAppear {
            versionCheckManager.checkForUpdates()
        }
    }

    // MARK: - Sections

    private var todayRow: some View {
        HStack {
            Text("Today")
                .foregroundStyle(.secondary)
            Spacer()
            Text(TimeFormatter.humanReadable(totalFocusTimeToday))
                .monospacedDigit()
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
    }

    @ViewBuilder
    private var quickAddRows: some View {
        if canOfferAddApp, let appName = focusManager.previousNonSelfAppName {
            if showAddedAppConfirmation {
                MenuConfirmationRow(title: "Added “\(appName)” to Focus Apps")
            } else {
                Button(action: addCurrentApp) {
                    MenuRowLabel(title: "Add “\(appName)” to Focus Apps", systemImage: "plus")
                }
                .buttonStyle(MenuRowButtonStyle())
            }
        }

        if let domain = addableSiteDomain {
            if showAddedSiteConfirmation {
                MenuConfirmationRow(title: "Added \(domain) to Focus Sites")
            } else {
                Button {
                    addCurrentSite(domain: domain)
                } label: {
                    MenuRowLabel(title: "Add \(domain) to Focus Sites", systemImage: "plus")
                }
                .buttonStyle(MenuRowButtonStyle())
            }
        }
    }

    @ViewBuilder
    private var actionRows: some View {
        if versionCheckManager.isUpdateAvailable {
            Button {
                versionCheckManager.openDownloadPage()
            } label: {
                MenuRowLabel(title: "Update to v\(versionCheckManager.latestVersion)…", showsBadge: true)
            }
            .buttonStyle(MenuRowButtonStyle())
        }

        Button {
            focusManager.togglePause()
        } label: {
            MenuRowLabel(
                title: focusManager.isPaused ? "Resume Tracking" : "Pause Tracking",
                systemImage: focusManager.isPaused ? "play.fill" : "pause.fill"
            )
        }
        .buttonStyle(MenuRowButtonStyle())

        SettingsLink {
            MenuRowLabel(title: "Settings…", shortcut: "⌘,")
        }
        .buttonStyle(MenuRowButtonStyle())
        .keyboardShortcut(",", modifiers: .command)

        Button {
            NSApplication.shared.terminate(nil)
        } label: {
            MenuRowLabel(title: "Quit Auto-Focus", shortcut: "⌘Q")
        }
        .buttonStyle(MenuRowButtonStyle())
        .keyboardShortcut("q", modifiers: .command)
    }

    // MARK: - Status

    private var status: MenuStatus {
        let context = focusManager.focusContextName
        let elapsed = TimeFormatter.humanReadable(focusManager.timeSpent)

        if focusManager.isPaused {
            return MenuStatus(
                symbol: "pause.fill",
                tint: nil,
                title: "Tracking paused",
                detail: "No sessions will start until you resume"
            )
        }

        if focusManager.isInBufferPeriod {
            let remaining = Int(focusManager.bufferTimeRemaining.rounded(.up))
            let detail: String
            if focusManager.isInFocusMode {
                let target = context.map { "\(elapsed) in \($0)" } ?? elapsed
                detail = "Return within \(remaining)s to keep \(target)"
            } else {
                detail = "Return to \(context ?? "your focus app") to keep counting"
            }
            let duration = focusManager.bufferDuration
            return MenuStatus(
                symbol: "hourglass",
                tint: .orange,
                title: "Focus on hold",
                detail: detail,
                progress: duration > 0 ? focusManager.bufferTimeRemaining / duration : nil
            )
        }

        if focusManager.isInFocusMode {
            return MenuStatus(
                symbol: "moon.fill",
                tint: .indigo,
                title: "Focused · \(elapsed)",
                detail: [context, "Do Not Disturb is on"].compactMap { $0 }.joined(separator: " · ")
            )
        }

        if focusManager.isInOverallFocus || focusManager.timeSpent > 0 {
            let threshold = focusManager.focusThreshold * AppConfiguration.timeMultiplier
            let progressText = "\(elapsed) of \(TimeFormatter.humanReadable(threshold))"
            return MenuStatus(
                symbol: "chart.line.uptrend.xyaxis",
                tint: .blue,
                title: "Getting into focus",
                detail: [context, progressText].compactMap { $0 }.joined(separator: " · "),
                progress: threshold > 0 ? min(focusManager.timeSpent / threshold, 1) : nil
            )
        }

        return MenuStatus(
            symbol: "moon",
            tint: nil,
            title: "Not focusing",
            detail: "Open a focus app or site to start"
        )
    }

    // MARK: - Derived State

    private var version: String {
        #if DEBUG
        return "DEBUG"
        #else
        return Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0.0"
        #endif
    }

    private var isBetaBuild: Bool {
        version.contains("-beta")
    }

    private var totalFocusTimeToday: TimeInterval {
        focusManager.todaysSessions.reduce(0) { $0 + $1.duration }
    }

    /// Whether the previous (non-Auto-Focus) app can be offered as a new focus app.
    private var canOfferAddApp: Bool {
        guard let bundleId = focusManager.previousNonSelfAppBundleId,
              !focusManager.isPreviousAppAlreadyFocusApp,
              !AppConfiguration.isSupportedBrowser(bundleId),
              focusManager.canAddMoreApps else { return false }
        return true
    }

    /// Domain of the current browser tab when it can be offered as a new focus site.
    private var addableSiteDomain: String? {
        guard let tab = focusManager.currentBrowserTab,
              !tab.isFocusURL,
              tab.url != "about:blank" else { return nil }
        let domain = FocusURL.focusTarget(from: tab.url)
        return domain.isEmpty ? nil : domain
    }

    private var hasQuickAddRows: Bool {
        (canOfferAddApp && focusManager.previousNonSelfAppName != nil) || addableSiteDomain != nil
    }

    // MARK: - Actions

    private func addCurrentApp() {
        guard let bundleId = focusManager.previousNonSelfAppBundleId,
              let name = focusManager.previousNonSelfAppName else { return }
        focusManager.addFocusAppByBundleId(bundleId, name: name)
        showAddedAppConfirmation = true
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
            showAddedAppConfirmation = false
        }
    }

    private func addCurrentSite(domain: String) {
        let focusURL = FocusURL(name: FocusURL.displayName(from: domain), domain: domain)
        focusManager.addFocusURL(focusURL)
        showAddedSiteConfirmation = true
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
            showAddedSiteConfirmation = false
        }
    }
}

// MARK: - Components

/// What the popover header shows for the current focus state.
private struct MenuStatus {
    let symbol: String
    /// State colour for the glyph and progress bar; `nil` renders a neutral glyph.
    let tint: Color?
    let title: String
    let detail: String
    var progress: Double?
}

private struct MenuStatusHeader: View {
    let status: MenuStatus

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 10) {
                glyph
                VStack(alignment: .leading, spacing: 1) {
                    Text(status.title)
                        .font(.body.weight(.semibold))
                        .monospacedDigit()
                    Text(status.detail)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .monospacedDigit()
                        .lineLimit(2)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }

            if let progress = status.progress {
                ProgressView(value: progress)
                    .progressViewStyle(.linear)
                    .tint(status.tint ?? .secondary)
                    .animation(.linear(duration: 0.5), value: progress)
            }
        }
        .padding(.horizontal, 8)
        .padding(.top, 6)
        .padding(.bottom, 4)
    }

    @ViewBuilder
    private var glyph: some View {
        let image = Image(systemName: status.symbol)
            .font(.system(size: 13, weight: .semibold))
            .frame(width: 28, height: 28)

        if let tint = status.tint {
            image
                .foregroundStyle(.white)
                .background(tint, in: Circle())
        } else {
            image
                .foregroundStyle(.secondary)
                .background(.quaternary, in: Circle())
        }
    }
}

private struct MenuSeparator: View {
    var body: some View {
        Divider()
            .padding(.horizontal, 8)
            .padding(.vertical, 5)
    }
}

/// Label for a menu-style row: a fixed icon column so titles line up, and an optional trailing
/// keyboard shortcut hint or badge.
private struct MenuRowLabel: View {
    let title: String
    var systemImage: String?
    var shortcut: String?
    var showsBadge = false

    var body: some View {
        HStack(spacing: 6) {
            ZStack {
                if let systemImage {
                    Image(systemName: systemImage)
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundStyle(.secondary)
                }
            }
            .frame(width: 16)

            Text(title)
                .lineLimit(1)
                .truncationMode(.middle)

            Spacer(minLength: 8)

            if let shortcut {
                Text(shortcut)
                    .foregroundStyle(.tertiary)
            }
            if showsBadge {
                Circle()
                    .fill(Color.accentColor)
                    .frame(width: 6, height: 6)
            }
        }
    }
}

private struct MenuConfirmationRow: View {
    let title: String

    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: "checkmark")
                .font(.system(size: 10, weight: .semibold))
                .foregroundStyle(.green)
                .frame(width: 16)
            Text(title)
                .foregroundStyle(.secondary)
                .lineLimit(1)
                .truncationMode(.middle)
        }
        .padding(.horizontal, 8)
        .frame(height: 24)
    }
}

/// Full-width menu row with the rounded hover highlight macOS uses in menu bar extras.
private struct MenuRowButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        MenuRowButton(configuration: configuration)
    }

    private struct MenuRowButton: View {
        let configuration: ButtonStyleConfiguration
        @State private var isHovering = false

        var body: some View {
            configuration.label
                .padding(.horizontal, 8)
                .frame(maxWidth: .infinity, minHeight: 24, alignment: .leading)
                .contentShape(Rectangle())
                .background(
                    RoundedRectangle(cornerRadius: 6, style: .continuous)
                        .fill(Color.primary.opacity(highlightOpacity))
                )
                .onHover { isHovering = $0 }
        }

        private var highlightOpacity: Double {
            if configuration.isPressed { return 0.14 }
            return isHovering ? 0.08 : 0
        }
    }
}

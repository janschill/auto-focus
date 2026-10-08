import LaunchAtLogin
import SwiftUI

struct AppRowView: View {
    let app: AppInfo

    var body: some View {
        HStack {
            if let appIcon = SafeImageLoader.loadAppIcon(for: app.bundleIdentifier) {
                Image(nsImage: appIcon)
                    .resizable()
                    .frame(width: 24, height: 24)
            } else {
                // Fallback to SF Symbol if app icon can't be loaded safely
                Image(systemName: "app.fill")
                    .frame(width: 24, height: 24)
                    .foregroundStyle(.blue)
            }
            Text(app.name)
        }
        .tag(app.id)
    }
}

struct AppsListView: View {
    @EnvironmentObject var focusManager: FocusManager
    @EnvironmentObject var licenseManager: LicenseManager
    @Binding var selectedTab: Int?

    var body: some View {
        VStack(spacing: 0) {
            List(selection: $focusManager.selectedAppId) {
                if focusManager.focusApps.isEmpty {
                    Text("No focus apps added yet")
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity, alignment: .center)
                        .padding()
                } else {
                    ForEach(focusManager.focusApps) { app in
                        AppRowView(app: app)
                    }
                }
            }
            .listStyle(.bordered)
            .frame(minHeight: 200)

            if !licenseManager.isLicensed, selectedTab != nil {
                HStack {
                    Image(systemName: "lock.fill")
                        .foregroundStyle(.secondary)
                    Text("Upgrade to Auto-Focus+ for unlimited apps")
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    Spacer()

                    Button("Upgrade") {
                        selectedTab = 4 // Navigate to Auto-Focus+ tab
                    }
                    .controlSize(.small)
                }
                .padding(.vertical, 8)
                .padding(.horizontal, 12)
                .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 8))
                .padding(.top, 8)
            }
        }
    }
}

struct GeneralSettingsView: View {
    @EnvironmentObject var licenseManager: LicenseManager
    @EnvironmentObject var focusManager: FocusManager
    @ObservedObject private var versionCheckManager = VersionCheckManager.shared

    var body: some View {
        Group {
            Section {
                LabeledContent("License type") {
                    if licenseManager.isLicensed {
                        Label("Auto-Focus+", systemImage: "star.circle.fill")
                            .labelStyle(TintedIconLabelStyle(tint: .yellow))
                            .foregroundStyle(.secondary)
                    } else {
                        Text("Free")
                            .foregroundStyle(.secondary)
                    }
                }

                LabeledContent("Version") {
                    versionContent
                }

                Toggle("Launch at Login", isOn: Binding(
                    get: { LaunchAtLogin.isEnabled },
                    set: { LaunchAtLogin.isEnabled = $0 }
                ))
                .toggleStyle(.switch)
            } header: {
                Text("General")
            }

            Section {
                LabeledContent("Timer Display") {
                    Picker("Timer Display", selection: $focusManager.timerDisplayMode) {
                        ForEach(TimerDisplayMode.allCases, id: \.self) { mode in
                            Text(mode.displayName).tag(mode)
                        }
                    }
                    .pickerStyle(.segmented)
                    .labelsHidden()
                    .fixedSize()
                }
            } header: {
                Text("Menu Bar")
            } footer: {
                Text("How the session timer appears in the menu bar. Choose Hidden to reduce distractions.")
                    .font(.callout)
                    .foregroundStyle(.secondary)
            }

            Section {
                LabeledContent("Shortcut Installation") {
                    HStack(spacing: 8) {
                        if focusManager.isShortcutInstalled {
                            Label("Installed", systemImage: "checkmark.circle.fill")
                                .labelStyle(TintedIconLabelStyle(tint: .green))
                                .foregroundStyle(.secondary)
                        } else {
                            Label("Not installed", systemImage: "exclamationmark.triangle.fill")
                                .labelStyle(TintedIconLabelStyle(tint: .orange))
                                .foregroundStyle(.secondary)
                        }

                        Button("Add Shortcut") {
                            ResourceManager.installShortcut()
                            focusManager.refreshShortcutStatus()
                        }
                        .controlSize(.small)
                        .disabled(focusManager.isShortcutInstalled)
                    }
                }

                ShortcutsPermissionRow(permissionService: focusManager.automationPermissionService)
            } header: {
                Text("Do Not Disturb")
            } footer: {
                Text("Auto-Focus installs a custom Shortcut to toggle the Do Not Disturb focus mode, which is necessary to block notifications. It also needs Automation permission for Shortcuts Events — macOS will prompt you once. If you denied it previously, open System Settings to re-enable it.")
                    .font(.callout)
                    .foregroundStyle(.secondary)
            }
        }
    }

    @ViewBuilder
    private var versionContent: some View {
        HStack(spacing: 8) {
            Text(appVersion)
                .foregroundStyle(.secondary)

            if isBetaBuild {
                Text("BETA")
                    .font(.caption2.weight(.bold))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(Color.orange, in: Capsule())
            }

            if versionCheckManager.isUpdateAvailable {
                Label("Update available", systemImage: "arrow.up.circle.fill")
                    .labelStyle(TintedIconLabelStyle(tint: .blue))
                    .font(.callout)
                    .foregroundStyle(.secondary)
            }

            if versionCheckManager.isChecking {
                ProgressView()
                    .controlSize(.small)
            }

            if versionCheckManager.isUpdateAvailable {
                Button("Download v\(versionCheckManager.latestVersion)") {
                    versionCheckManager.openDownloadPage()
                }
                .controlSize(.small)
                .buttonStyle(.borderedProminent)
            } else if !versionCheckManager.isChecking {
                Button("Check for Updates…") {
                    versionCheckManager.checkForUpdates()
                }
                .controlSize(.small)
                .buttonStyle(.bordered)
            }
        }
    }

    private var appVersion: String {
        return Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "Unknown"
    }

    private var isBetaBuild: Bool {
        return appVersion.contains("-beta")
    }
}

struct ThresholdsView: View {
    @EnvironmentObject var focusManager: FocusManager

    var body: some View {
        Section {
            LabeledContent {
                HStack(spacing: 8) {
                    Slider(
                        value: $focusManager.focusThreshold,
                        in: 1...12,
                        step: 1
                    )
                    .frame(width: 180)
                    Text("\(Int(focusManager.focusThreshold)) m")
                        .monospacedDigit()
                        .foregroundStyle(.secondary)
                        .frame(width: 40, alignment: .trailing)
                }
            } label: {
                Text("Focus Activation")
                Text("Time it takes to start a focus session. When the time is reached, notifications are disabled.")
            }

            LabeledContent {
                HStack(spacing: 8) {
                    Slider(
                        value: $focusManager.focusLossBuffer,
                        in: 0...30,
                        step: 2
                    )
                    .frame(width: 180)
                    Text("\(Int(focusManager.focusLossBuffer)) s")
                        .monospacedDigit()
                        .foregroundStyle(.secondary)
                        .frame(width: 40, alignment: .trailing)
                }
            } label: {
                Text("Focus Loss Buffer")
                Text("Buffer time so you don't lose your focus session immediately after leaving your focus apps.")
            }
        } header: {
            Text("Thresholds")
        }
    }
}

struct FocusApplicationsView: View {
    @EnvironmentObject var focusManager: FocusManager
    @EnvironmentObject var licenseManager: LicenseManager
    @Binding var selectedTab: Int

    var body: some View {
        Section {
            if focusManager.focusApps.isEmpty {
                Text("No focus apps added yet")
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .center)
            } else {
                ForEach(focusManager.focusApps) { app in
                    AppRowView(app: app)
                        .selectableFormRow(isSelected: focusManager.selectedAppId == app.id) {
                            focusManager.selectedAppId = focusManager.selectedAppId == app.id ? nil : app.id
                        }
                        .contextMenu {
                            Button("Remove", role: .destructive) {
                                focusManager.selectedAppId = app.id
                                focusManager.removeSelectedApp()
                            }
                        }
                }
            }

            HStack(spacing: 4) {
                Button {
                    DispatchQueue.main.async {
                        focusManager.selectFocusApplication()
                    }
                } label: {
                    Image(systemName: "plus")
                        .frame(width: 12, height: 12)
                }
                .help("Add focus app")
                .disabled(!focusManager.canAddMoreApps)

                Button {
                    DispatchQueue.main.async {
                        focusManager.removeSelectedApp()
                    }
                } label: {
                    Image(systemName: "minus")
                        .frame(width: 12, height: 12)
                }
                .help("Remove selected app")
                .disabled(focusManager.selectedAppId == nil)

                Spacer()
            }
            .buttonStyle(.bordered)
            .controlSize(.small)

            if !licenseManager.isLicensed {
                HStack {
                    Label("Upgrade to Auto-Focus+ for unlimited apps", systemImage: "lock.fill")
                        .font(.callout)
                        .foregroundStyle(.secondary)

                    Spacer()

                    Button("Upgrade") {
                        selectedTab = 4 // Navigate to Auto-Focus+ tab
                    }
                    .controlSize(.small)
                }
            }
        } header: {
            Text("Focus Applications")
        } footer: {
            Text("Being in any of these apps will automatically activate focus mode.")
                .font(.callout)
                .foregroundStyle(.secondary)
        }
    }
}

struct ConfigurationView: View {
    @EnvironmentObject var focusManager: FocusManager
    @EnvironmentObject var licenseManager: LicenseManager
    @Binding var selectedTab: Int

    var body: some View {
        Form {
            GeneralSettingsView()
            ThresholdsView()
            FocusApplicationsView(selectedTab: $selectedTab)
        }
        .formStyle(.grouped)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .onAppear {
            focusManager.refreshShortcutStatus()
            focusManager.automationPermissionService.refresh(bundleId: AppConfiguration.shortcutsEventsBundleIdentifier)
            VersionCheckManager.shared.checkForUpdates()
        }
    }
}

#Preview {
    ConfigurationView(selectedTab: .constant(0))
        .environmentObject(LicenseManager())
        .environmentObject(FocusManager.shared)
        .frame(width: 600, height: 900)
}

private struct ShortcutsPermissionRow: View {
    @ObservedObject var permissionService: AutomationPermissionService

    private var status: BrowserPermissionStatus {
        permissionService.status(for: AppConfiguration.shortcutsEventsBundleIdentifier)
    }

    var body: some View {
        LabeledContent("Shortcuts Permission") {
            HStack(spacing: 8) {
                statusBadge

                if status == .denied {
                    Button("Fix in System Settings…") {
                        permissionService.openSystemSettings()
                    }
                    .controlSize(.small)
                } else if status != .granted {
                    Button("Request Permission") {
                        permissionService.requestPermission(bundleId: AppConfiguration.shortcutsEventsBundleIdentifier)
                    }
                    .controlSize(.small)
                }
            }
        }
    }

    @ViewBuilder
    private var statusBadge: some View {
        switch status {
        case .granted:
            badge("Granted", systemImage: "checkmark.circle.fill", tint: .green)
        case .denied:
            badge("Denied", systemImage: "xmark.octagon.fill", tint: .red)
        case .notDetermined:
            badge("Not determined", systemImage: "questionmark.circle.fill", tint: .orange)
        case .unknown:
            badge("Not checked", systemImage: "circle", tint: .secondary)
        case .notInstalled:
            badge("Not installed", systemImage: "slash.circle", tint: .secondary)
        }
    }

    private func badge(_ title: String, systemImage: String, tint: Color) -> some View {
        Label(title, systemImage: systemImage)
            .labelStyle(TintedIconLabelStyle(tint: tint))
            .font(.callout)
            .foregroundStyle(.secondary)
    }
}

/// Highlights a row inside a grouped `Form`, where `listRowBackground` and `List` selection have no effect.
private struct SelectableFormRowModifier: ViewModifier {
    let isSelected: Bool
    let onSelect: () -> Void

    func body(content: Content) -> some View {
        content
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 6)
            .padding(.vertical, 3)
            .foregroundStyle(isSelected ? Color.white : Color.primary)
            .background(
                RoundedRectangle(cornerRadius: 5)
                    .fill(isSelected ? Color.accentColor : Color.clear)
            )
            .padding(.horizontal, -6)
            .contentShape(Rectangle())
            .onTapGesture(perform: onSelect)
    }
}

extension View {
    /// Makes a grouped-form row tappable with a native-looking selection highlight.
    func selectableFormRow(isSelected: Bool, onSelect: @escaping () -> Void) -> some View {
        modifier(SelectableFormRowModifier(isSelected: isSelected, onSelect: onSelect))
    }
}

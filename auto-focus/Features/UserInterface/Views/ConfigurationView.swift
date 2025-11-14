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
                    .foregroundColor(.blue)
            }
            VStack(alignment: .leading) {
                Text(app.name)
                    .font(.headline)
            }
        }
        .tag(app.id)
    }
}

struct AppsListView: View {
    @EnvironmentObject var focusManager: FocusManager
    @EnvironmentObject var licenseManager: LicenseManager

    var body: some View {
        List(selection: $focusManager.selectedAppId) {
            ForEach(focusManager.focusApps) { app in
                AppRowView(app: app)
            }
        }
        .listStyle(.bordered)

        if !licenseManager.isLicensed {
            HStack {
                Image(systemName: "lock.fill")
                    .foregroundColor(.secondary)
                Text("Upgrade to Auto-Focus+ for unlimited apps")
                    .font(.caption)
                    .foregroundColor(.secondary)

                Spacer()

                Button("Upgrade") {
                    // Instead of changing tabs, show an alert or notification
                    // This removes the circular binding dependency
                    print("Upgrade to premium for export/import features")
                }
                .controlSize(.small)
            }
            .padding(.vertical, 6)
            .padding(.horizontal, 8)
            .background(Color.secondary.opacity(0.1))
            .cornerRadius(6)
        }
    }
}

private struct HeaderView: View {
    var body: some View {
        GroupBox {
            VStack {
                Text("General").font(.title)
                    .fontDesign(.default)
                    .fontWeight(.bold)
                    .bold()
                Text("Manage your overall setup and preferences for Auto-Focus, such as launch at login, buffer times, focus apps, and more.")
                    .font(.callout)
                    .fontDesign(.default)
                    .fontWeight(.regular)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
            }
            .padding(.horizontal, 40)
            .padding(.vertical)
        }
        .frame(maxWidth: .infinity)
    }
}

struct GeneralSettingsView: View {
    @EnvironmentObject var licenseManager: LicenseManager
    @EnvironmentObject var focusManager: FocusManager
    @StateObject private var versionCheckManager = VersionCheckManager()

    var body: some View {
        GroupBox {
            VStack {
                HStack {
                    Text("License type")
                        .frame(width: 150, alignment: .leading)
                    Spacer()
                    if licenseManager.isLicensed {
                        Image(systemName: licenseStatusIcon)
                            .symbolRenderingMode(.multicolor)
                        Text(licenseStatusText)
                            .foregroundStyle(licenseStatusColor)
                    } else {
                        Text("Free")
                    }

                }

                Divider().padding(.vertical, 5).contrast(0.5)

                HStack {
                    Text("Version")
                        .frame(width: 150, alignment: .leading)
                    Spacer()
                    
                    VStack(alignment: .trailing, spacing: 2) {
                        HStack(spacing: 8) {
                            Text(appVersion)
                                .foregroundColor(.secondary)
                            
                            if versionCheckManager.isUpdateAvailable {
                                HStack(spacing: 4) {
                                    Image(systemName: "arrow.up.circle.fill")
                                        .foregroundColor(.blue)
                                        .font(.system(size: 12))
                                    Text("Update available")
                                        .font(.caption)
                                        .foregroundColor(.blue)
                                }
                            }
                            
                            if versionCheckManager.isChecking {
                                ProgressView()
                                    .scaleEffect(0.5)
                                    .frame(width: 12, height: 12)
                            }
                        }
                        
                        if versionCheckManager.isUpdateAvailable {
                            Button("Download v\(versionCheckManager.latestVersion)") {
                                versionCheckManager.openDownloadPage()
                            }
                            .controlSize(.mini)
                            .buttonStyle(.borderedProminent)
                        } else if !versionCheckManager.isChecking {
                            Button("Check for Updates") {
                                versionCheckManager.checkForUpdates()
                            }
                            .controlSize(.mini)
                        }
                    }
                }

                Divider().padding(.vertical, 5).contrast(0.5)

                HStack {
                    Text("Launch at Login")
                        .frame(width: 150, alignment: .leading)
                    Spacer()
                    // Convert to Switch
                    Toggle("", isOn: Binding(
                        get: { LaunchAtLogin.isEnabled },
                        set: { LaunchAtLogin.isEnabled = $0 }
                    ))
                    .toggleStyle(SwitchToggleStyle())
                    .labelsHidden()
                    .scaleEffect(0.8)
                    .padding(.trailing, 5)
                }

                Divider().padding(.vertical, 5).contrast(0.5)

                HStack {
                    Text("Timer Display")
                        .frame(width: 150, alignment: .leading)
                    Spacer(minLength: 10)
                    Picker("", selection: $focusManager.timerDisplayMode) {
                        ForEach(TimerDisplayMode.allCases, id: \.self) { mode in
                            Text(mode.displayName).tag(mode)
                        }
                    }
                    .pickerStyle(.segmented)
                    .fixedSize()
                    .padding(.trailing, 5)
                }

                HStack {
                    Text("Controls how the current session timer appears in the menu bar. Choose 'Hidden' to reduce distractions.")
                        .font(.callout)
                        .fontDesign(.default)
                        .fontWeight(.regular)
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity, alignment: .leading)

                Divider().padding(.vertical, 5).contrast(0.5)

                HStack {
                    Text("Shortcut Installation")
                        .frame(width: 150, alignment: .leading)

                    Spacer()

                    if focusManager.isShortcutInstalled {
                        Text("✓ Installed")
                            .foregroundColor(.green)
                    } else {
                        Text("⚠️ Not installed")
                            .foregroundColor(.red)
                    }

                    Button("Add Shortcut") {
                        installShortcut()
                        focusManager.refreshShortcutStatus()
                    }
                    .disabled(focusManager.isShortcutInstalled)
                }

                HStack {
                    Text("Auto-Focus will install a custom Shortcut that will be used to toggle the Do Not Disturb focus mode. This Shortcut is necessary to block notifications.")
                        .font(.callout)
                        .fontDesign(.default)
                        .fontWeight(.regular)
                        .foregroundColor(.secondary)

                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .padding(.horizontal, 5)
            .padding(.vertical)
        }
        .frame(maxWidth: .infinity)
        .onAppear {
            focusManager.refreshShortcutStatus()
            versionCheckManager.checkForUpdates()
        }
    }

    private var isBetaLicense: Bool {
        return licenseManager.licenseOwner == "Beta User"
    }

    private var licenseStatusIcon: String {
        if isBetaLicense {
            return "hourglass"
        } else {
            return "star.circle.fill"
        }
    }

    private var licenseStatusText: String {
        if isBetaLicense {
            return "Beta"
        } else {
            return "Auto-Focus+"
        }
    }

    private var licenseStatusColor: Color {
        if isBetaLicense {
            return .indigo
        } else {
            return .green
        }
    }
    
    private var appVersion: String {
        return Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "Unknown"
    }
}

struct ThresholdsView: View {
    @EnvironmentObject var focusManager: FocusManager

    var body: some View {
        GroupBox(label: Text("Thresholds").font(.headline)) {
            VStack {
                HStack {
                    Text("Focus Activation")
                        .frame(width: 250, alignment: .leading)

                    Spacer()

                    Slider(
                        value: $focusManager.focusThreshold,
                        in: 1...12,
                        step: 1
                    )
                    Text("\(Int(focusManager.focusThreshold)) m")
                        .frame(width: 40)

                }

                HStack {
                    Text("This is the time it takes to start a focus session. When the time is reached notifications are disabled.")
                        .font(.callout)
                        .fontDesign(.default)
                        .fontWeight(.regular)
                        .foregroundColor(.secondary)

                }.frame(maxWidth: .infinity, alignment: .leading)

                Divider().padding(.vertical, 5).contrast(0.5)

                HStack {
                    Text("Focus Loss Buffer")
                        .frame(width: 250, alignment: .leading)

                    Spacer()

                    Slider(
                        value: $focusManager.focusLossBuffer,
                        in: 0...30,
                        step: 2
                    )
                    Text("\(Int(focusManager.focusLossBuffer)) s")
                        .frame(width: 40)

                }

                HStack {
                    Text("Give yourself a buffer time to not lose your focussed session immediately after you leave your focus apps.")
                        .font(.callout)
                        .fontDesign(.default)
                        .fontWeight(.regular)
                        .foregroundColor(.secondary)

                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .padding(.horizontal, 5)
            .padding(.vertical)
        }
        .frame(maxWidth: .infinity)

    }
}

struct FocusApplicationsView: View {
    @EnvironmentObject var focusManager: FocusManager
    @EnvironmentObject var licenseManager: LicenseManager

    var body: some View {
        GroupBox(label: Text("Focus Applications").font(.headline)) {
            VStack(alignment: .leading) {
                Text("Being in any of these apps will automatically activate focus mode.")
                    .font(.callout)
                    .fontDesign(.default)
                    .fontWeight(.regular)
                    .foregroundColor(.secondary)

                AppsListView()
                    .frame(minHeight: 200)

                HStack {
                    Button {
                        DispatchQueue.main.async {
                            focusManager.selectFocusApplication()
                        }
                    } label: {
                        Image(systemName: "plus")
                    }
                    .disabled(!focusManager.canAddMoreApps)

                    Button {
                        DispatchQueue.main.async {
                            focusManager.removeSelectedApp()
                        }
                    } label: {
                        Image(systemName: "minus")
                    }
                    .disabled(focusManager.selectedAppId == nil)

                    Spacer()
                }
            }
            .padding(.horizontal, 5)
            .padding(.vertical)
        }
        .frame(maxWidth: .infinity)
    }
}

struct ConfigurationView: View {
    @EnvironmentObject var focusManager: FocusManager
    @EnvironmentObject var licenseManager: LicenseManager

    var body: some View {
        ScrollView {
            VStack(spacing: 10) {
                HeaderView()
                GeneralSettingsView()
                ThresholdsView()
                FocusApplicationsView()
            }
            .padding()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

#Preview {
    ConfigurationView()
        .environmentObject(LicenseManager())
        .environmentObject(FocusManager.shared)
        .frame(width: 600, height: 900)
}

private func installShortcut() {
    guard let shortcutUrl = ResourceManager.copyShortcutToTemporary() else {
        print("Could not prepare shortcut for installation")
        return
    }

    NSWorkspace.shared.open(shortcutUrl)
}

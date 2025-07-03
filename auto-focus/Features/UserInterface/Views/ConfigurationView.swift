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

                HStack {
                    Button {
                        DispatchQueue.main.async {
                            focusManager.selectFocusApplication()
                        }
                    } label: {
                        Image(systemName: "plus")
                    }
                    .disabled(!licenseManager.isLicensed)

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
        VStack(spacing: 10) {
            HeaderView()
            GeneralSettingsView()
            ThresholdsView()
            FocusApplicationsView()
            SlackIntegrationSectionView()
        }
        .padding()
    }
}

struct SlackIntegrationSectionView: View {
    @EnvironmentObject var focusManager: FocusManager
    
    private var slackManager: SlackIntegrationManager {
        return focusManager.slackIntegration
    }
    
    var body: some View {
        GroupBox(label: Text("Slack Integration").font(.headline)) {
            VStack(alignment: .leading, spacing: 12) {
                Text("Automatically update your Slack status and enable Do Not Disturb during focus sessions.")
                    .font(.callout)
                    .foregroundColor(.secondary)
                
                HStack {
                    Text("Status:")
                        .frame(width: 100, alignment: .leading)
                    
                    Text(slackManager.getConnectionStatusText())
                        .foregroundColor(slackManager.isConnected ? .green : .secondary)
                    
                    Spacer()
                    
                    if slackManager.isConnected {
                        Button("Configure") {
                            openSlackConfiguration()
                        }
                    } else {
                        Button("Connect Slack") {
                            slackManager.connectWorkspace()
                        }
                        .disabled(slackManager.oauthManager.isAuthenticating)
                    }
                }
                
                if slackManager.oauthManager.isAuthenticating {
                    HStack {
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle(tint: .blue))
                            .scaleEffect(0.8)
                        Text("Connecting to Slack...")
                            .font(.callout)
                            .foregroundColor(.blue)
                    }
                }
                
                if let error = slackManager.oauthManager.authError {
                    HStack {
                        Image(systemName: "exclamationmark.triangle")
                            .foregroundColor(.orange)
                        Text(error.localizedDescription)
                            .font(.callout)
                            .foregroundColor(.orange)
                    }
                }
            }
            .padding(.horizontal, 5)
            .padding(.vertical)
        }
        .frame(maxWidth: .infinity)
    }
    
    private func openSlackConfiguration() {
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 600, height: 700),
            styleMask: [.titled, .closable, .resizable],
            backing: .buffered,
            defer: false
        )
        
        window.title = "Slack Configuration"
        window.contentView = NSHostingView(rootView: SlackConfigurationView(slackManager: slackManager))
        window.center()
        window.makeKeyAndOrderFront(nil)
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

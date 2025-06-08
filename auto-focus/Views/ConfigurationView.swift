import LaunchAtLogin
import SwiftUI

struct AppRowView: View {
    let app: AppInfo

    var body: some View {
        HStack {
            if let appUrl = NSWorkspace.shared.urlForApplication(withBundleIdentifier: app.bundleIdentifier),
               let appIcon = Optional(NSWorkspace.shared.icon(forFile: appUrl.path)) {
                Image(nsImage: appIcon)
                    .resizable()
                    .frame(width: 24, height: 24)
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
    @Binding var selectedTab: Int

    var body: some View {
        List(selection: $focusManager.selectedAppId) {
            ForEach(focusManager.focusApps) { app in
                AppRowView(app: app)
            }
        }
        .listStyle(.bordered)

        if focusManager.isPremiumRequired {
            HStack {
                Image(systemName: "lock.fill")
                    .foregroundColor(.secondary)
                Text("Upgrade to Auto-Focus+ for unlimited apps")
                    .font(.caption)
                    .foregroundColor(.secondary)

                Spacer()

                Button("Upgrade") {
                    selectedTab = 2
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
                        Image(systemName: "hourglass")
                            .symbolRenderingMode(.multicolor)
                        Text("Beta")
                            .foregroundStyle(.indigo)
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
    @Binding var selectedTab: Int

    var body: some View {
        GroupBox(label: Text("Focus Applications").font(.headline)) {
            VStack(alignment: .leading) {
                Text("Being in any of these apps will automatically activate focus mode.")
                    .font(.callout)
                    .fontDesign(.default)
                    .fontWeight(.regular)
                    .foregroundColor(.secondary)

                AppsListView(selectedTab: $selectedTab)

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
    @Binding var selectedTab: Int

    var body: some View {
        VStack(spacing: 10) {
            HeaderView()
            GeneralSettingsView()
            ThresholdsView()
            FocusApplicationsView(selectedTab: $selectedTab)
        }
        .padding()
    }
}

#Preview {
    ConfigurationView(selectedTab: .constant(0))
        .environmentObject(LicenseManager())
        .frame(width: 600, height: 900)
}

private func installShortcut() {
    guard let shortcutUrl = ResourceManager.copyShortcutToTemporary() else {
        print("Could not prepare shortcut for installation")
        return
    }

    NSWorkspace.shared.open(shortcutUrl)
}

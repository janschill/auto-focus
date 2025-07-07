import LaunchAtLogin
import SwiftUI


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
                    Text("System Do Not Disturb")
                        .frame(width: 150, alignment: .leading)
                    Spacer()
                    Toggle("", isOn: Binding(
                        get: { focusManager.isSystemDNDEnabled },
                        set: { focusManager.isSystemDNDEnabled = $0 }
                    ))
                    .toggleStyle(SwitchToggleStyle())
                    .labelsHidden()
                    .scaleEffect(0.8)
                    .padding(.trailing, 5)
                }

                HStack {
                    Text("Enable macOS Focus Mode to block system notifications during focus sessions.")
                        .font(.callout)
                        .fontDesign(.default)
                        .fontWeight(.regular)
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity, alignment: .leading)

                if focusManager.isSystemDNDEnabled {
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


struct ConfigurationView: View {
    @EnvironmentObject var focusManager: FocusManager
    @EnvironmentObject var licenseManager: LicenseManager

    var body: some View {
        VStack(spacing: 10) {
            HeaderView()
            GeneralSettingsView()
            ThresholdsView()
            Spacer()
        }
        .padding()
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

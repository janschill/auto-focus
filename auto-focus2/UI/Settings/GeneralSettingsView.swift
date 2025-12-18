import SwiftUI

struct GeneralSettingsView: View {
    @ObservedObject var viewModel: SettingsViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            header(title: "General", subtitle: "Overall preferences like launch on login and thresholds.")

            GroupBox("System status") {
                VStack(alignment: .leading, spacing: 10) {
                    statusRow(
                        title: "Automation: System Events",
                        state: viewModel.prerequisites.systemEventsAutomation
                    )
                    statusRow(
                        title: "Automation: Shortcuts Events",
                        state: viewModel.prerequisites.shortcutsAutomation
                    )
                    Divider()
                    shortcutRow(installed: viewModel.prerequisites.shortcutInstalled, name: viewModel.prerequisites.shortcutName)

                    HStack(spacing: 10) {
                        Button(viewModel.isCheckingPrerequisites ? "Requesting…" : "Request permissions") {
                            Task {
                                await viewModel.requestAutomationPermissions()
                            }
                        }
                        .disabled(viewModel.isCheckingPrerequisites)

                        Button("Check again") {
                            viewModel.refreshPrerequisitesSilently()
                        }

                        Spacer()

                        Button("Open System Settings") {
                            if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy") {
                                NSWorkspace.shared.open(url)
                            }
                        }
                    }

                    Text("If Automation is not allowed, enable it in System Settings → Privacy & Security → Automation, and toggle AutoFocus2 for the target apps.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .padding(.vertical, 4)
            }

            Form {
                Section("Launch") {
                    LaunchOnLoginRow(isEnabled: $viewModel.launchOnLoginEnabled) { enabled in
                        viewModel.toggleLaunchOnLogin(enabled)
                    }
                }

                Section("Thresholds") {
                    VStack(alignment: .leading, spacing: 10) {
                        HStack {
                            Text("Focus activation")
                            Spacer()
                            Text("\(viewModel.activationMinutes) min")
                                .foregroundStyle(.secondary)
                        }
                        Slider(value: Binding(
                            get: { Double(viewModel.activationMinutes) },
                            set: { viewModel.activationMinutes = Int($0.rounded()) }
                        ), in: 1...180, step: 1)

                        HStack {
                            Text("Focus loss buffer")
                            Spacer()
                            Text("\(viewModel.bufferSeconds) s")
                                .foregroundStyle(.secondary)
                        }
                        Slider(value: Binding(
                            get: { Double(viewModel.bufferSeconds) },
                            set: { viewModel.bufferSeconds = Int($0.rounded()) }
                        ), in: 0...600, step: 1)

                        HStack {
                            Spacer()
                            Button("Save thresholds") { viewModel.saveTimers() }
                        }

                        Text("When you stay in a focus app or domain for the activation time, notifications are disabled. If you leave during an active session, the buffer gives you a grace period.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }

            if let err = viewModel.lastError {
                Text(err)
                    .foregroundStyle(.red)
                    .font(.caption)
            }

            Spacer()
        }
        .padding(16)
        .onAppear {
            // Silent check; request prompt is explicit via the button above.
            viewModel.refreshPrerequisitesSilently()
        }
    }

    private func header(title: String, subtitle: String) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title).font(.largeTitle.weight(.semibold))
            Text(subtitle).foregroundStyle(.secondary)
        }
    }

    private func statusRow(title: String, state: PermissionState) -> some View {
        HStack {
            Image(systemName: icon(for: state))
                .foregroundStyle(color(for: state))
            Text(title)
            Spacer()
            Text(label(for: state))
                .foregroundStyle(.secondary)
        }
        .font(.subheadline)
    }

    private func shortcutRow(installed: Bool?, name: String) -> some View {
        HStack {
            Image(systemName: installed == true ? "checkmark.circle.fill" : "exclamationmark.triangle.fill")
                .foregroundStyle(installed == true ? .green : .orange)
            Text("Shortcut: \(name)")
            Spacer()
            Text(installed == nil ? "Unknown" : (installed == true ? "Installed" : "Missing"))
                .foregroundStyle(.secondary)
        }
        .font(.subheadline)
    }

    private func icon(for state: PermissionState) -> String {
        switch state {
        case .granted: return "checkmark.circle.fill"
        case .notGranted: return "xmark.circle.fill"
        case .unknown: return "questionmark.circle"
        }
    }

    private func color(for state: PermissionState) -> Color {
        switch state {
        case .granted: return .green
        case .notGranted: return .red
        case .unknown: return .secondary
        }
    }

    private func label(for state: PermissionState) -> String {
        switch state {
        case .granted: return "Allowed"
        case .notGranted: return "Not allowed"
        case .unknown: return "Unknown"
        }
    }
}



import AppKit
import SwiftUI

struct OnboardingView: View {
    @State private var state = OnboardingState()
    @State private var settingsModel: SettingsViewModel?
    @State private var showTestShortcutConfirm: Bool = false
    @State private var shortcutTestMessage: String?

    @EnvironmentObject private var appModel: AppModel

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Welcome to AutoFocus2")
                .font(.title2)

            Text("This will guide you through permissions, optional licensing, and adding your first focus apps and domains.")
                .foregroundStyle(.secondary)

            Divider()

            HStack(alignment: .top, spacing: 16) {
                VStack(alignment: .leading, spacing: 10) {
                    stepRow(.permissions, title: "Permissions")
                    stepRow(.license, title: "License (optional)")
                    stepRow(.apps, title: "Focus apps")
                    stepRow(.domains, title: "Focus domains")
                    stepRow(.done, title: "Done")
                    Spacer()
                }
                .frame(width: 180)

                Divider()

                VStack(alignment: .leading, spacing: 12) {
                    content
                    Spacer()

                    HStack {
                        Button("Back") { state = OnboardingFlow.reduce(state, event: .back) }
                            .disabled(state.step == .permissions)

                        Button(state.step == .done ? "Close" : "Next") {
                            if state.step == .done {
                                NSApplication.shared.keyWindow?.close()
                            } else {
                                state = OnboardingFlow.reduce(state, event: .next)
                            }
                        }
                        .keyboardShortcut(.defaultAction)
                        .disabled(!canProceedFromCurrentStep)

                        Spacer()
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .padding(16)
        .frame(minWidth: 760, minHeight: 520)
        .onAppear {
            if settingsModel == nil, let root = appModel.compositionRoot {
                settingsModel = SettingsViewModel(root: root)
            }
            settingsModel?.refreshPrerequisitesSilently()
            if let model = settingsModel, model.prerequisites.requirementsSatisfied {
                state = OnboardingFlow.reduce(state, event: .permissionsGranted(true))
            }
        }
        .alert("Test Shortcut", isPresented: $showTestShortcutConfirm) {
            Button("Cancel", role: .cancel) {}
            Button("Run Test") {
                Task {
                    do {
                        shortcutTestMessage = nil
                        try await settingsModel?.testShortcutRoundTrip()
                        shortcutTestMessage = "Success. The shortcut ran twice (toggle + toggle back)."
                    } catch {
                        shortcutTestMessage = "Failed: \(error.localizedDescription)"
                    }
                }
            }
        } message: {
            Text("This will run your shortcut twice so the net effect should be no change. You may see Do Not Disturb briefly toggle.")
        }
    }

    private func stepRow(_ step: OnboardingStep, title: String) -> some View {
        let isCurrent = state.step == step
        return HStack(spacing: 8) {
            Image(systemName: isCurrent ? "circle.inset.filled" : "circle")
                .foregroundStyle(isCurrent ? .blue : .secondary)
            Text(title)
                .font(isCurrent ? .headline : .body)
            Spacer()
        }
        .contentShape(Rectangle())
    }

    @ViewBuilder
    private var content: some View {
        switch state.step {
        case .permissions:
            VStack(alignment: .leading, spacing: 10) {
                Text("Permissions")
                    .font(.headline)
                Text("AutoFocus2 needs permission to run your Shortcut (System Events → Shortcuts Events). For browser domain tracking, Safari/Chrome scripting permissions may be required.")
                    .foregroundStyle(.secondary)

                if let model = settingsModel {
                    GroupBox("Status") {
                        VStack(alignment: .leading, spacing: 8) {
                            statusRow("Automation: System Events", model.prerequisites.systemEventsAutomation)
                            statusRow("Automation: Shortcuts Events", model.prerequisites.shortcutsAutomation)
                            Divider()
                            shortcutRow(installed: model.prerequisites.shortcutInstalled, name: model.prerequisites.shortcutName)
                        }
                        .padding(.vertical, 4)
                    }

                    HStack(spacing: 10) {
                        Button(model.isCheckingPrerequisites ? "Enabling…" : "Enable permissions") {
                            Task {
                                await model.requestAutomationPermissions()
                                state = OnboardingFlow.reduce(state, event: .permissionsGranted(model.prerequisites.requirementsSatisfied))
                            }
                        }
                        .disabled(model.isCheckingPrerequisites)

                        Button("Check again") {
                            model.refreshPrerequisitesSilently()
                            state = OnboardingFlow.reduce(state, event: .permissionsGranted(model.prerequisites.requirementsSatisfied))
                        }

                        if model.prerequisites.requirementsSatisfied, model.prerequisites.shortcutInstalled == true {
                            Button("Test Shortcut") {
                                showTestShortcutConfirm = true
                            }
                        }

                        Spacer()

                        Button("Open System Settings") {
                            // Best-effort: open Privacy & Security.
                            if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy") {
                                NSWorkspace.shared.open(url)
                            }
                        }
                    }
                    .padding(.top, 4)

                    if let msg = shortcutTestMessage {
                        Text(msg)
                            .font(.caption)
                            .foregroundStyle(msg.hasPrefix("Failed") ? .red : .secondary)
                    }
                } else {
                    Text("Not initialized")
                        .foregroundStyle(.secondary)
                }

                Text("Tip: you can also revisit this later in Settings.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

        case .license:
            VStack(alignment: .leading, spacing: 10) {
                Text("License (optional)")
                    .font(.headline)
                Text("If you have an AutoFocus+ key, enter it now to unlock higher limits and export.")
                    .foregroundStyle(.secondary)

                if let model = settingsModel {
                    LicenseView(
                        licenseService: model.licenseService,
                        licenseKey: Binding(
                            get: { model.licenseKey },
                            set: { model.licenseKey = $0 }
                        )
                    )
                } else {
                    Text("Not initialized")
                        .foregroundStyle(.secondary)
                }
            }

        case .apps:
            VStack(alignment: .leading, spacing: 10) {
                Text("Add focus apps")
                    .font(.headline)
                Text("Pick apps from your Applications folder. Being in any of these apps counts toward focus mode.")
                    .foregroundStyle(.secondary)

                if let model = settingsModel {
                    Button {
                        model.presentAppPickerAndAdd()
                        state = OnboardingFlow.reduce(state, event: .appsAdded(!model.focusApps.isEmpty))
                    } label: {
                        Label("Add App…", systemImage: "plus")
                    }

                    List(model.focusApps) { entity in
                        HStack {
                            Text(entity.displayName)
                            Spacer()
                            Text(entity.matchValue)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                    .frame(height: 220)

                    if !model.focusApps.isEmpty {
                        Text("Great — you can add more later in Settings.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                } else {
                    Text("Not initialized")
                        .foregroundStyle(.secondary)
                }
            }

        case .domains:
            VStack(alignment: .leading, spacing: 10) {
                Text("Add focus domains")
                    .font(.headline)
                Text("Add domains like github.com. When a supported browser is frontmost, the active tab’s domain can count toward focus mode.")
                    .foregroundStyle(.secondary)

                if let model = settingsModel {
                    HStack(spacing: 10) {
                        TextField(
                            "example.com",
                            text: Binding(
                                get: { model.newDomainValue },
                                set: { model.newDomainValue = $0 }
                            )
                        )
                            .textFieldStyle(.roundedBorder)
                            .frame(maxWidth: 320)
                        Button {
                            model.addDomain()
                            state = OnboardingFlow.reduce(state, event: .domainsAdded(!model.focusDomains.isEmpty))
                        } label: {
                            Label("Add", systemImage: "plus")
                        }
                    }

                    List(model.focusDomains) { entity in
                        HStack {
                            Text(entity.displayName)
                            Spacer()
                            Text(entity.matchValue)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                    .frame(height: 220)
                } else {
                    Text("Not initialized")
                        .foregroundStyle(.secondary)
                }
            }

        case .done:
            VStack(alignment: .leading, spacing: 10) {
                Text("All set")
                    .font(.headline)
                Text("AutoFocus2 will now monitor your focus apps and domains. You can tweak thresholds and manage lists in Settings anytime.")
                    .foregroundStyle(.secondary)
            }
        }
    }

    private func statusRow(_ title: String, _ state: PermissionState) -> some View {
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

    private var canProceedFromCurrentStep: Bool {
        switch state.step {
        case .permissions:
            return state.hasPermissions
        case .license, .apps, .domains, .done:
            return true
        }
    }
}



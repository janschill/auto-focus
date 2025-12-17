import AppKit
import SwiftUI

struct OnboardingView: View {
    @State private var state = OnboardingState()

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Onboarding")
                .font(.title2)

            Text("This is a minimal flow scaffold. We’ll replace the toggles with real permission/shortcut checks.")
                .foregroundStyle(.secondary)

            Divider()

            Text("Step: \(state.step.rawValue)")
                .font(.headline)

            switch state.step {
            case .permissions:
                Toggle("I have granted required permissions", isOn: Binding(
                    get: { state.hasPermissions },
                    set: { state = OnboardingFlow.reduce(state, event: .permissionsGranted($0)) }
                ))
                Text("Required: Automation permissions for System Events/Shortcuts. Browser scripting permissions if using domain tracking.")
                    .font(.caption)
                    .foregroundStyle(.secondary)

            case .shortcut:
                Toggle("Shortcut is installed/configured", isOn: Binding(
                    get: { state.hasShortcutConfigured },
                    set: { state = OnboardingFlow.reduce(state, event: .shortcutConfigured($0)) }
                ))
                Text("Install the provided Shortcut (e.g. “Toggle Do Not Disturb”).")
                    .font(.caption)
                    .foregroundStyle(.secondary)

            case .license:
                Text("License is optional. You can skip this step.")
                    .foregroundStyle(.secondary)

            case .configuration:
                Toggle("I have configured focus entities and timers", isOn: Binding(
                    get: { state.hasCompletedConfiguration },
                    set: { state = OnboardingFlow.reduce(state, event: .configurationCompleted($0)) }
                ))

            case .done:
                Text("All set.")
                    .font(.headline)
            }

            Spacer()

            HStack {
                Button("Back") { state = OnboardingFlow.reduce(state, event: .back) }
                    .disabled(state.step == .permissions)
                Button("Next") { state = OnboardingFlow.reduce(state, event: .next) }
                    .disabled(state.step == .done)
                Spacer()
                Button("Close") { NSApplication.shared.keyWindow?.close() }
            }
        }
        .padding(16)
        .frame(minWidth: 520, minHeight: 420)
    }
}



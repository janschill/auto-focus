import AppKit
import SwiftUI

@main
struct AutoFocus2App: App {
    @StateObject private var appModel = AppModel()

    var body: some Scene {
        MenuBarExtra("AutoFocus2", systemImage: "scope") {
            VStack(alignment: .leading, spacing: 10) {
                Text("AutoFocus2")
                    .font(.headline)

                Divider()

                if let error = appModel.initError {
                    Text("Init failed: \(error)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                } else if appModel.compositionRoot == nil {
                    Button("Initialize") { appModel.start() }
                } else {
                    Button("Onboarding") { appModel.showsOnboarding = true }
                    Button("Settings") { appModel.showsSettings = true }
                        .keyboardShortcut(",", modifiers: .command)
                }

                Button("Quit") {
                    NSApplication.shared.terminate(nil)
                }
            }
            .padding(12)
            .frame(minWidth: 260)
            .sheet(isPresented: $appModel.showsSettings) {
                if let root = appModel.compositionRoot {
                    SettingsView(viewModel: SettingsViewModel(root: root))
                } else {
                    Text("Not initialized")
                        .padding()
                }
            }
            .sheet(isPresented: $appModel.showsOnboarding) {
                OnboardingView()
            }
        }
    }
}



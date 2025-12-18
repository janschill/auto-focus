import AppKit
import SwiftUI

@main
struct AutoFocus2App: App {
    @StateObject private var appModel = AppModel()

    var body: some Scene {
        MenuBarExtra("AutoFocus2", systemImage: "scope") {
            Group {
                if let error = appModel.initError {
                    VStack(alignment: .leading, spacing: 10) {
                        Text("AutoFocus2")
                            .font(.headline)
                        Text("Init failed: \(error)")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Divider()
                        Button("Retry") { appModel.start() }
                        Button("Quit") { NSApplication.shared.terminate(nil) }
                    }
                    .padding(12)
                    .frame(minWidth: 280)
                } else if appModel.compositionRoot == nil || appModel.orchestrator == nil {
                    VStack(alignment: .leading, spacing: 10) {
                        Text("AutoFocus2")
                            .font(.headline)
                        Text("Not initialized.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Divider()
                        Button("Initialize") { appModel.start() }
                        Button("Quit") { NSApplication.shared.terminate(nil) }
                    }
                    .padding(12)
                    .frame(minWidth: 280)
                } else {
                    MenuBarView(
                        orchestrator: appModel.orchestrator!,
                        onShowOnboarding: { appModel.showsOnboarding = true },
                        onShowSettings: { appModel.showsSettings = true }
                    )
                }
            }
        }

        WindowGroup("Settings", id: "settings") {
            SettingsWindow()
                .environmentObject(appModel)
        }

        WindowGroup("Onboarding", id: "onboarding") {
            OnboardingWindow()
                .environmentObject(appModel)
        }
    }
}



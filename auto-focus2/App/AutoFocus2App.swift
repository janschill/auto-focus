import AppKit
import SwiftUI

@main
struct AutoFocus2App: App {
    var body: some Scene {
        MenuBarExtra("AutoFocus2", systemImage: "scope") {
            VStack(alignment: .leading, spacing: 8) {
                Text("AutoFocus2")
                    .font(.headline)
                Text("Scaffold running. Focus engine not yet wired.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)

                Divider()

                Button("Open Settings") {
                    // TODO: Wire navigation once SettingsView exists.
                }
                .keyboardShortcut(",", modifiers: .command)

                Button("Quit") {
                    NSApplication.shared.terminate(nil)
                }
            }
            .padding(12)
            .frame(minWidth: 260)
        }
    }
}



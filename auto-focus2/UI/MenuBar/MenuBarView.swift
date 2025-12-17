import AppKit
import SwiftUI

struct MenuBarView: View {
    @ObservedObject var orchestrator: FocusOrchestrator
    let onShowOnboarding: () -> Void
    let onShowSettings: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("AutoFocus2")
                .font(.headline)

            VStack(alignment: .leading, spacing: 6) {
                Text(statusText)
                    .font(.subheadline)
                if let err = orchestrator.lastError {
                    Text(err)
                        .font(.caption)
                        .foregroundStyle(.red)
                } else if orchestrator.lastDomainResult.isAvailable == false,
                          let reason = orchestrator.lastDomainResult.reason,
                          reason != .unsupportedBrowser {
                    Text("Domain tracking unavailable: \(reason.rawValue)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            Divider()

            Button("Onboarding") { onShowOnboarding() }
            Button("Settings") { onShowSettings() }
                .keyboardShortcut(",", modifiers: .command)

            Divider()

            Button("Quit") {
                NSApplication.shared.terminate(nil)
            }
        }
        .padding(12)
        .frame(minWidth: 280)
    }

    private var statusText: String {
        switch orchestrator.state.phase {
        case .idle:
            return "Idle"
        case .counting(let secondsAccumulated):
            return "Counting: \(secondsAccumulated)s"
        case .inFocusMode:
            return "Focus mode: ON"
        case .buffering(_, let bufferEndsAt):
            let remaining = max(0, Int(bufferEndsAt.timeIntervalSince1970 - Date().timeIntervalSince1970))
            return "Buffer: \(remaining)s remaining"
        }
    }
}



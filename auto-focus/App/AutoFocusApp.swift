import Combine
import Sparkle
import SwiftUI

@main
struct AutoFocusApp: App {
    private let focusManager = FocusManager.shared
    @StateObject private var licenseManager = LicenseManager()
    @StateObject private var updaterController = UpdaterController()
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    var body: some Scene {
        Settings {
            SettingsContentView(focusManager: focusManager)
                .environmentObject(focusManager)
                .environmentObject(licenseManager)
                .environmentObject(updaterController)
        }
        .windowResizability(.contentSize)
        .windowToolbarStyle(.unifiedCompact)

        MenuBarExtra {
            MenuBarView()
                .environmentObject(focusManager)
                .environmentObject(updaterController)
        } label: {
            MenuBarStatusLabel()
                .environmentObject(focusManager)
        }
        .menuBarExtraStyle(.window)
    }
}

private struct SettingsContentView: View {
    let focusManager: FocusManager
    @State private var hasCompletedOnboarding: Bool

    init(focusManager: FocusManager) {
        self.focusManager = focusManager
        _hasCompletedOnboarding = State(initialValue: focusManager.hasCompletedOnboarding)
    }

    var body: some View {
        Group {
            if hasCompletedOnboarding {
                SettingsView()
            } else {
                OnboardingView()
            }
        }
        .onReceive(focusManager.$hasCompletedOnboarding.removeDuplicates()) { hasCompletedOnboarding in
            self.hasCompletedOnboarding = hasCompletedOnboarding
        }
    }
}

private struct MenuBarStatusLabel: View {
    @EnvironmentObject var focusManager: FocusManager

    var body: some View {
        HStack(spacing: 4) {
            if focusManager.isPaused {
                Image(systemName: "pause.circle")
            } else if focusManager.isInOverallFocus {
                switch focusManager.timerDisplayMode {
                case .hidden:
                    EmptyView()
                case .full:
                    Text(TimeFormatter.duration(focusManager.timeSpent))
                        .font(.system(size: 10, weight: .medium))
                case .simplified:
                    Text(TimeFormatter.minutes(focusManager.timeSpent))
                        .font(.system(size: 10, weight: .medium))
                }
            }
            if focusManager.isInFocusMode {
                Image(systemName: "brain.head.profile.fill")
            } else {
                Image(systemName: "brain.head.profile")
            }
            if focusManager.isInBufferPeriod {
                Text(TimeFormatter.duration(focusManager.bufferTimeRemaining))
                    .font(.system(size: 10, weight: .medium))
            }
        }
    }
}

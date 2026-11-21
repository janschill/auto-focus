import SwiftUI

@main
struct AutoFocusApp: App {
    @StateObject private var focusManager = FocusManager.shared
    @StateObject private var licenseManager = LicenseManager.shared
    @StateObject private var flowMonitor: FlowMonitor = {
        let monitor = FlowMonitor(focusContext: { FocusManager.shared.focusContext })
        monitor.start()
        return monitor
    }()
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    var body: some Scene {
        Settings {
            if focusManager.hasCompletedOnboarding {
                SettingsView()
                    .environmentObject(focusManager)
                    .environmentObject(licenseManager)
            } else {
                OnboardingView()
                    .environmentObject(focusManager)
                    .environmentObject(licenseManager)
            }
        }
        .windowResizability(.contentSize)
        .windowToolbarStyle(.unifiedCompact)

        MenuBarExtra {
            MenuBarView()
                .environmentObject(focusManager)
                .environmentObject(flowMonitor)
        } label: {
            HStack(spacing: 4) {
                Image(systemName: menuBarSymbol)
                if let timerText = menuBarTimerText {
                    Text(timerText)
                        .font(.system(size: 10, weight: .medium))
                        .monospacedDigit()
                }
                if !focusManager.isPaused && flowMonitor.reading.state.showsInMenuBar {
                    Image(systemName: flowMonitor.reading.state.systemImage)
                }
            }
        }
        .menuBarExtraStyle(.window)
    }

    private var menuBarSymbol: String {
        if focusManager.isPaused { return "pause.circle" }
        return focusManager.isInFocusMode ? "brain.head.profile.fill" : "brain.head.profile"
    }

    /// The buffer countdown always shows; the session timer follows the user's display preference.
    private var menuBarTimerText: String? {
        guard !focusManager.isPaused else { return nil }
        if focusManager.isInBufferPeriod {
            return TimeFormatter.duration(focusManager.bufferTimeRemaining)
        }
        guard focusManager.isInOverallFocus else { return nil }
        switch focusManager.timerDisplayMode {
        case .hidden:
            return nil
        case .full:
            return TimeFormatter.duration(focusManager.timeSpent)
        case .simplified:
            return TimeFormatter.minutes(focusManager.timeSpent)
        }
    }
}

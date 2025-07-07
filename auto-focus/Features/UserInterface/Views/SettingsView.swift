import SwiftUI

struct SettingsView: View {
    @EnvironmentObject var focusManager: FocusManager
    @EnvironmentObject var licenseManager: LicenseManager
    @Environment(\.dismiss) var dismiss
    @State private var selectedTab = 0

    var body: some View {
        TabView(selection: $selectedTab) {
            ConfigurationView()
                .tabItem {
                    Label("General", systemImage: "gear")
                }
                .tag(0)
                .environmentObject(licenseManager)

            FocusAppsView()
                .tabItem {
                    Label("Focus Apps", systemImage: "app.badge")
                }
                .tag(1)
                .environmentObject(focusManager)
                .environmentObject(licenseManager)

            BrowserConfigView()
                .tabItem {
                    Label("Browser", systemImage: "globe")
                }
                .tag(2)
                .environmentObject(focusManager)
                .environmentObject(licenseManager)

            SlackView()
                .tabItem {
                    Label("Slack", systemImage: "bubble.left.and.bubble.right")
                }
                .tag(3)
                .environmentObject(focusManager)

            InsightsView(selectedTab: .constant(4))
                .tabItem {
                    Label("Insights", systemImage: "chart.bar")
                }
                .tag(4)
                .environmentObject(licenseManager)

            DataView(selectedTab: .constant(5))
                .tabItem {
                    Label("Data", systemImage: "externaldrive")
                }
                .tag(5)
                .environmentObject(focusManager)
                .environmentObject(licenseManager)

            LicenseView()
                .tabItem {
                    Label("Auto-Focus+", systemImage: "star.circle.fill")
                }
                .tag(6)
                .environmentObject(licenseManager)

            if focusManager.canShowDebugOptions {
                DebugMenuView()
                    .tabItem {
                        Label("Debug", systemImage: "ladybug")
                    }
                    .tag(7)
                    .environmentObject(focusManager)
                    .environmentObject(licenseManager)
            }
        }
        .frame(width: 600, height: 800)
        .onAppear {
            #if !DEBUG
            // When settings appear, show in dock and activate
            NSApp.setActivationPolicy(.regular)
            NSApp.activate(ignoringOtherApps: true)

            // Additional step to bring window to front
            DispatchQueue.main.async {
                NSApp.windows.first?.orderFrontRegardless()
            }
            #endif
        }
        .onDisappear {
            #if !DEBUG
            // When settings disappear, hide from dock
            NSApp.setActivationPolicy(.accessory)
            NSApp.deactivate()
            #endif
        }
    }
}

import SwiftUI

struct SettingsView: View {
    @EnvironmentObject var focusManager: FocusManager
    @EnvironmentObject var licenseManager: LicenseManager
    @Environment(\.dismiss) var dismiss
    @State private var selectedTab = 0

    var body: some View {
        TabView(selection: $selectedTab) {
            ConfigurationView(selectedTab: $selectedTab)
                .tabItem {
                    Label("Configuration", systemImage: "gear")
                }
                .tag(0)
                .environmentObject(licenseManager)

            BrowserConfigView()
                .tabItem {
                    Label("Browser", systemImage: "globe")
                }
                .tag(1)
                .environmentObject(focusManager)
                .environmentObject(licenseManager)

            InsightsView(selectedTab: $selectedTab)
                .tabItem {
                    Label("Insights", systemImage: "chart.bar")
                }
                .tag(2)
                .environmentObject(licenseManager)

            DataView(selectedTab: $selectedTab)
                .tabItem {
                    Label("Data", systemImage: "externaldrive")
                }
                .tag(3)
                .environmentObject(focusManager)
                .environmentObject(licenseManager)

            LicenseView()
                .tabItem {
                    Label("Auto-Focus+", systemImage: "star.circle.fill")
                }
                .tag(4)
                .environmentObject(licenseManager)

            if focusManager.canShowDebugOptions {
                DebugMenuView()
                    .tabItem {
                        Label("Debug", systemImage: "ladybug")
                    }
                    .tag(5)
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

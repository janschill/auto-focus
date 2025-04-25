//
//  SettingsView.swift
//  auto-focus
//
//  Created by Jan Schill on 25/01/2025.
//

import SwiftUI

struct SettingsView: View {
    @EnvironmentObject var focusManager: FocusManager
    @EnvironmentObject var licenseManager: LicenseManager
    @Environment(\.dismiss) var dismiss
    
    var body: some View {
        TabView {
            ConfigurationView()
                .tabItem {
                    Label("Configuration", systemImage: "gear")
                }
                .environmentObject(licenseManager)
            
            InsightsView()
                .tabItem {
                    Label("Insights", systemImage: "chart.bar")
                }
            
            EnhancedInsightsView()
                .tabItem {
                    Label("EnhancedInsights", systemImage: "chart.line.text.clipboard")
                }
            
            LicenseView()
                .tabItem {
                    Label("License", systemImage: "star.fill")
                }
                .environmentObject(licenseManager)
        }
        .frame(width: 600, height: 800)
        .onAppear {
            // When settings appear, show in dock and activate
            NSApp.setActivationPolicy(.regular)
            NSApp.activate(ignoringOtherApps: true)
            
            // Additional step to bring window to front
            DispatchQueue.main.async {
                NSApp.windows.first?.orderFrontRegardless()
            }
        }
        .onDisappear {
            // When settings disappear, hide from dock
            NSApp.setActivationPolicy(.accessory)
            NSApp.deactivate()
        }
    }
}

#Preview {
    SettingsView()
}

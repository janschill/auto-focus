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
    @State private var selectedTab = 0
    
    var body: some View {
        TabView(selection: $selectedTab) {
            ConfigurationView(selectedTab: $selectedTab)
                .tabItem {
                    Label("Configuration", systemImage: "gear")
                }
                .tag(0)
                .environmentObject(licenseManager)
            
            InsightsView(selectedTab: $selectedTab)
                .tabItem {
                    Label("Insights", systemImage: "chart.bar")
                }
                .tag(1)
                .environmentObject(licenseManager)
            
            LicenseView()
                .tabItem {
                    Label("Auto-Focus+", systemImage: "star.fill")
                }
                .tag(2)
                .environmentObject(licenseManager)
            
            if focusManager.canShowDebugOptions {
                DebugMenuView()
                    .tabItem {
                        Label("Debug", systemImage: "ladybug")
                    }
                    .tag(3)
                    .environmentObject(focusManager)
            }
        }
        .frame(width: 600, height: 800)
//        .onAppear {
//            // When settings appear, show in dock and activate
//            NSApp.setActivationPolicy(.regular)
//            NSApp.activate(ignoringOtherApps: true)
//            
//            // Additional step to bring window to front
//            DispatchQueue.main.async {
//                NSApp.windows.first?.orderFrontRegardless()
//            }
//        }
//        .onDisappear {
//            // When settings disappear, hide from dock
//            NSApp.setActivationPolicy(.accessory)
//            NSApp.deactivate()
//        }
    }
}

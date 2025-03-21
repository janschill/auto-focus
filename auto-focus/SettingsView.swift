//
//  SettingsView.swift
//  auto-focus
//
//  Created by Jan Schill on 25/01/2025.
//

import SwiftUI
import LaunchAtLogin

struct SettingsView: View {
    @EnvironmentObject var focusManager: FocusManager
    @Environment(\.dismiss) var dismiss
    
    var body: some View {
        TabView {
            ConfigurationView()
                .tabItem {
                    Label("Configuration", systemImage: "gear")
                }
            
            InsightsView()
                .tabItem {
                    Label("Insights", systemImage: "chart.bar")
                }
        }
        .frame(width: 550, height: 500)
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

struct AppRowView: View {
    let app: AppInfo
    
    var body: some View {
        HStack {
            if let appUrl = NSWorkspace.shared.urlForApplication(withBundleIdentifier: app.bundleIdentifier),
               let appIcon = Optional(NSWorkspace.shared.icon(forFile: appUrl.path)) {
                Image(nsImage: appIcon)
                    .resizable()
                    .frame(width: 32, height: 32)
            }
            VStack(alignment: .leading) {
                Text(app.name)
                    .font(.headline)
            }
        }
        .tag(app.id)
    }
}

struct AppsListView: View {
    @EnvironmentObject var focusManager: FocusManager
    
    var body: some View {
        List(selection: $focusManager.selectedAppId) {
            ForEach(focusManager.focusApps) { app in
                AppRowView(app: app)
            }
        }
        .listStyle(.bordered)
    }
}

struct ConfigurationView: View {
    @EnvironmentObject var focusManager: FocusManager
    @State private var shortcutInstalled: Bool = false
    
    var body: some View {
        Form {
            Section(header: Text("General").font(.headline)) {
                LaunchAtLogin.Toggle().padding(.bottom, 8)
                HStack {
                    Button("Add Shortcut") {
                        installShortcut()
                    }
                    .disabled(shortcutInstalled)
                    
                    if shortcutInstalled {
                        Text("✓ Installed")
                            .foregroundColor(.green)
                    } else {
                        Text("⚠️ Not installed")
                            .foregroundColor(.red)
                    }
                }
                
                Text("This shortcut is required for Auto-Focus to toggle Do Not Disturb mode.")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            Section(header: Text("Thresholds").font(.headline)) {
                Text("Configure when to disable notifications automatically and start a focussed session. Give yourself a buffer time to not lose your focussed session immediately after you leave your focus apps.").font(.caption).foregroundColor(.secondary)
                VStack {
                    HStack {
                        Slider(
                            value: $focusManager.focusThreshold,
                            in: 2...24,
                            step: 2
                        )
                        Text("\(Int(focusManager.focusThreshold)) m")
                            .frame(width: 40)
                    }
                    Text("Focus activation threshold (in minutes)")
                }
                
                VStack {
                    HStack {
                        Slider(
                            value: $focusManager.focusLossBuffer,
                            in: 0...60,
                            step: 2
                        )
                        Text("\(Int(focusManager.focusLossBuffer)) s")
                            .frame(width: 40)
                    }
                    Text("Focus loss buffer (in seconds)")
                }
            }

            Spacer()
            
            Section(header: Text("Focus Applications").font(.headline)) {
                Text("Being in any of these apps will automatically activate focus mode").font(.caption).foregroundColor(.secondary)
                VStack {
                    AppsListView()
                    
                    HStack {
                        Button {
                            DispatchQueue.main.async {
                                focusManager.selectFocusApplication()
                            }
                        } label: {
                            Image(systemName: "plus")
                        }
                        
                        Button {
                            DispatchQueue.main.async {
                                focusManager.removeSelectedApp()
                            }
                        } label: {
                            Image(systemName: "minus")
                        }
                        .disabled(focusManager.selectedAppId == nil)
                        
                        Spacer()
                    }
                }
            }
        }
        .padding(8)
        .onAppear() {
            shortcutInstalled = focusManager.checkShortcutExists()
        }
    }
}

private func installShortcut() {
    guard let shortcutUrl = ResourceManager.copyShortcutToTemporary() else {
        print("Could not prepare shortcut for installation")
        return
    }
    
    NSWorkspace.shared.open(shortcutUrl)
}

#Preview {
    ConfigurationView()
        .environmentObject(FocusManager())
}

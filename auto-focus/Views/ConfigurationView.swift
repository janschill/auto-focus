//
//  ConfigurationView.swift
//  auto-focus
//
//  Created by Jan Schill on 16/04/2025.
//
import SwiftUI
import LaunchAtLogin

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
        
        if focusManager.isPremiumRequired {
            HStack {
                Image(systemName: "lock.fill")
                    .foregroundColor(.secondary)
                Text("Upgrade to Premium for unlimited apps")
                    .font(.caption)
                    .foregroundColor(.secondary)
                Spacer()
                Button("Upgrade") {
                    // Switch to the Premium tab
                    // This would need a custom implementation with a TabView binding
                }
                .buttonStyle(.borderless)
                .font(.caption)
                .foregroundColor(.blue)
            }
            .padding(.vertical, 6)
            .padding(.horizontal, 8)
            .background(Color.secondary.opacity(0.1))
            .cornerRadius(6)
        }
    }
}

struct ConfigurationView: View {
    @EnvironmentObject var focusManager: FocusManager
    @EnvironmentObject var licenseManager: LicenseManager
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
                        .disabled(!focusManager.canAddMoreApps)
                        
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

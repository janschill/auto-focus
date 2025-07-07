import SwiftUI

struct SlackView: View {
    @EnvironmentObject var focusManager: FocusManager
    
    private var slackManager: SlackIntegrationManager {
        return focusManager.slackIntegration
    }
    
    var body: some View {
        VStack(spacing: 10) {
            HeaderView()
            EnablementToggleView(slackManager: slackManager)
            
            if slackManager.settings.isEnabled {
                ConnectedWorkspacesView(slackManager: slackManager)
                StatusSettingsView(slackManager: slackManager)
            }
            
            Spacer()
        }
        .frame(maxWidth: .infinity)
        .padding()
    }
}

private struct HeaderView: View {
    var body: some View {
        GroupBox {
            VStack {
                Text("Slack Integration").font(.title)
                    .fontDesign(.default)
                    .fontWeight(.bold)
                    .bold()
                Text("Automatically update your Slack status and enable Do Not Disturb during focus sessions.")
                    .font(.callout)
                    .fontDesign(.default)
                    .fontWeight(.regular)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
            }
            .padding(.horizontal, 40)
            .padding(.vertical)
        }
        .frame(maxWidth: .infinity)
    }
}

private struct EnablementToggleView: View {
    let slackManager: SlackIntegrationManager
    
    var body: some View {
        GroupBox {
            VStack {
                HStack {
                    Text("Enable Slack Integration")
                        .frame(width: 200, alignment: .leading)
                        .fontWeight(.medium)
                    
                    Spacer()
                    
                    Toggle("", isOn: Binding(
                        get: { slackManager.settings.isEnabled },
                        set: { newValue in
                            var newSettings = slackManager.settings
                            newSettings.isEnabled = newValue
                            slackManager.updateSettings(newSettings)
                        }
                    ))
                    .toggleStyle(SwitchToggleStyle())
                    .labelsHidden()
                    .scaleEffect(0.8)
                    .padding(.trailing, 5)
                }
                
                if !slackManager.settings.isEnabled {
                    HStack {
                        Text("Enable this integration to automatically update your Slack status and notifications during focus sessions.")
                            .font(.callout)
                            .fontDesign(.default)
                            .fontWeight(.regular)
                            .foregroundColor(.secondary)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
            .padding(.horizontal, 5)
            .padding(.vertical)
        }
        .frame(maxWidth: .infinity)
    }
}

private struct ConnectedWorkspacesView: View {
    let slackManager: SlackIntegrationManager
    @State private var showingRemoveAlert = false
    @State private var workspaceToRemove: SlackWorkspace?
    
    var body: some View {
        GroupBox("Workspaces") {
            VStack(spacing: 12) {
                if slackManager.connectedWorkspaceCount == 0 {
                    // Empty state
                    VStack(spacing: 16) {
                        Image(systemName: "link.circle")
                            .font(.system(size: 48))
                            .foregroundColor(.gray)
                        
                        VStack(spacing: 8) {
                            Text("No Slack Workspaces Connected")
                                .font(.headline)
                                .foregroundColor(.secondary)
                            
                            Text("Connect your Slack workspaces to get started.")
                                .font(.callout)
                                .foregroundColor(.secondary)
                                .multilineTextAlignment(.center)
                        }
                        
                        Button {
                            slackManager.connectWorkspace()
                        } label: {
                            HStack {
                                Image(systemName: "plus.circle.fill")
                                Text("Connect Slack Workspace")
                            }
                            .fontWeight(.medium)
                        }
                        .buttonStyle(.borderedProminent)
                        .disabled(slackManager.oauthManager.isAuthenticating)
                    }
                    .padding(.vertical, 20)
                } else {
                    // Connected workspaces list
                    ForEach(slackManager.workspaceManager.connectedWorkspaces, id: \.id) { workspace in
                        WorkspaceRowView(
                            workspace: workspace,
                            onRemove: {
                                workspaceToRemove = workspace
                                showingRemoveAlert = true
                            }
                        )
                    }
                    
                    HStack {
                        Button {
                            slackManager.connectWorkspace()
                        } label: {
                            HStack {
                                Image(systemName: "plus.circle")
                                Text("Add Another Workspace")
                            }
                        }
                        .buttonStyle(.bordered)
                        .disabled(slackManager.oauthManager.isAuthenticating)
                        
                        Spacer()
                    }
                    .padding(.top, 8)
                }
                
                // OAuth loading state
                if slackManager.oauthManager.isAuthenticating {
                    VStack(spacing: 8) {
                        HStack {
                            ProgressView()
                                .progressViewStyle(CircularProgressViewStyle(tint: .blue))
                                .scaleEffect(0.8)
                            Text("Connecting to Slack...")
                                .font(.callout)
                                .foregroundColor(.blue)
                        }
                        
                        Button("Cancel") {
                            slackManager.oauthManager.cancelAuthentication()
                        }
                        .buttonStyle(.bordered)
                        .controlSize(.small)
                    }
                    .padding(.top, 8)
                }
                
                // OAuth error state
                if let error = slackManager.oauthManager.authError {
                    HStack {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .foregroundColor(.orange)
                        Text(error.localizedDescription)
                            .font(.callout)
                            .foregroundColor(.orange)
                    }
                    .padding(.top, 8)
                }
            }
            .padding()
        }
        .alert("Remove Workspace", isPresented: $showingRemoveAlert) {
            Button("Cancel", role: .cancel) { }
            Button("Remove", role: .destructive) {
                if let workspace = workspaceToRemove {
                    slackManager.disconnectWorkspace(workspace)
                    workspaceToRemove = nil
                }
            }
        } message: {
            if let workspace = workspaceToRemove {
                Text("Are you sure you want to disconnect from \(workspace.name)?")
            }
        }
    }
}

private struct WorkspaceRowView: View {
    let workspace: SlackWorkspace
    let onRemove: () -> Void
    
    var body: some View {
        HStack {
            Image(systemName: "building.2")
                .foregroundColor(.blue)
                .frame(width: 24, height: 24)
            
            VStack(alignment: .leading, spacing: 4) {
                Text(workspace.name)
                    .font(.headline)
                
                Text("Connected as \(workspace.userDisplayName)")
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                Text("Connected \(RelativeDateTimeFormatter().localizedString(for: workspace.connectedAt, relativeTo: Date()))")
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            Button {
                onRemove()
            } label: {
                Image(systemName: "xmark.circle")
                    .foregroundColor(.red)
            }
            .buttonStyle(.plain)
        }
        .padding(.vertical, 4)
    }
}

private struct StatusSettingsView: View {
    let slackManager: SlackIntegrationManager
    
    var body: some View {
        GroupBox("Settings") {
            VStack(spacing: 16) {
                // Custom Status Section
                VStack(spacing: 12) {
                    HStack {
                        Text("Custom Status")
                            .font(.headline)
                        Spacer()
                        Toggle("", isOn: Binding(
                            get: { slackManager.settings.useCustomStatus },
                            set: { newValue in
                                var newSettings = slackManager.settings
                                newSettings.useCustomStatus = newValue
                                slackManager.updateSettings(newSettings)
                            }
                        ))
                        .toggleStyle(SwitchToggleStyle())
                        .labelsHidden()
                        .scaleEffect(0.8)
                    }
                    
                    if slackManager.settings.useCustomStatus {
                        VStack(spacing: 8) {
                            HStack {
                                Text("Status Text:")
                                    .frame(width: 100, alignment: .leading)
                                TextField("Focus status message", text: Binding(
                                    get: { slackManager.settings.focusStatusText },
                                    set: { newValue in
                                        var newSettings = slackManager.settings
                                        newSettings.focusStatusText = newValue
                                        slackManager.updateSettings(newSettings)
                                    }
                                ))
                                .textFieldStyle(.roundedBorder)
                            }
                            
                            HStack {
                                Text("Emoji:")
                                    .frame(width: 100, alignment: .leading)
                                TextField(":brain:", text: Binding(
                                    get: { slackManager.settings.focusStatusEmoji },
                                    set: { newValue in
                                        var newSettings = slackManager.settings
                                        newSettings.focusStatusEmoji = newValue
                                        slackManager.updateSettings(newSettings)
                                    }
                                ))
                                .textFieldStyle(.roundedBorder)
                                .frame(maxWidth: 120)
                                Spacer()
                            }
                            
                            HStack {
                                Toggle("Clear status when focus ends", isOn: Binding(
                                    get: { slackManager.settings.clearStatusOnExit },
                                    set: { newValue in
                                        var newSettings = slackManager.settings
                                        newSettings.clearStatusOnExit = newValue
                                        slackManager.updateSettings(newSettings)
                                    }
                                ))
                                .font(.callout)
                                Spacer()
                            }
                        }
                        .padding(.leading, 20)
                    }
                }
                
                Divider()
                
                // Do Not Disturb Section
                VStack(spacing: 12) {
                    HStack {
                        Text("Do Not Disturb")
                            .font(.headline)
                        Spacer()
                        Toggle("", isOn: Binding(
                            get: { slackManager.settings.enableDND },
                            set: { newValue in
                                var newSettings = slackManager.settings
                                newSettings.enableDND = newValue
                                slackManager.updateSettings(newSettings)
                            }
                        ))
                        .toggleStyle(SwitchToggleStyle())
                        .labelsHidden()
                        .scaleEffect(0.8)
                    }
                    
                    if slackManager.settings.enableDND {
                        HStack {
                            Text("Duration:")
                                .frame(width: 100, alignment: .leading)
                            
                            Picker("Duration", selection: Binding(
                                get: { slackManager.settings.statusDurationMinutes ?? 0 },
                                set: { newValue in
                                    var newSettings = slackManager.settings
                                    newSettings.statusDurationMinutes = newValue == 0 ? nil : newValue
                                    slackManager.updateSettings(newSettings)
                                }
                            )) {
                                Text("Until focus ends").tag(0)
                                Text("30 minutes").tag(30)
                                Text("1 hour").tag(60)
                                Text("2 hours").tag(120)
                                Text("4 hours").tag(240)
                            }
                            .pickerStyle(.menu)
                            .frame(maxWidth: 200)
                            
                            Spacer()
                        }
                        .padding(.leading, 20)
                    }
                }
            }
            .padding()
        }
    }
}

#Preview {
    SlackView()
        .environmentObject(FocusManager.shared)
        .frame(width: 600, height: 800)
}
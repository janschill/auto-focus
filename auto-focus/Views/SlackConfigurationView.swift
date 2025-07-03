import SwiftUI

struct SlackConfigurationView: View {
    @ObservedObject var slackManager: SlackIntegrationManager
    @State private var showingStatusPreview = false
    @State private var statusPreviewText = ""
    @State private var isTestingConnection = false
    @State private var showingRemoveAlert = false
    @State private var workspaceToRemove: SlackWorkspace?
    
    var body: some View {
        VStack(spacing: 20) {
            HeaderView()
            
            if slackManager.isConnected {
                ConnectedWorkspacesView(
                    slackManager: slackManager,
                    showingRemoveAlert: $showingRemoveAlert,
                    workspaceToRemove: $workspaceToRemove
                )
                
                SlackSettingsView(slackManager: slackManager)
                
                StatusPreviewView(
                    slackManager: slackManager,
                    showingStatusPreview: $showingStatusPreview,
                    statusPreviewText: $statusPreviewText
                )
                
                TestConnectionView(
                    slackManager: slackManager,
                    isTestingConnection: $isTestingConnection
                )
            } else {
                NotConnectedView(slackManager: slackManager)
            }
            
            Spacer()
        }
        .padding()
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
        .alert("Preview Status", isPresented: $showingStatusPreview) {
            Button("OK") { }
        } message: {
            Text("Current status: \(statusPreviewText)")
        }
    }
}

private struct HeaderView: View {
    var body: some View {
        GroupBox {
            VStack(spacing: 16) {
                HStack {
                    Image(systemName: "bubble.left.and.bubble.right")
                        .font(.title2)
                        .foregroundColor(.blue)
                    
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Slack Integration")
                            .font(.title2)
                            .fontWeight(.bold)
                        
                        Text("Automatically set your Slack status and enable Do Not Disturb during focus sessions")
                            .font(.callout)
                            .foregroundColor(.secondary)
                    }
                    
                    Spacer()
                }
            }
            .padding(.vertical, 8)
        }
    }
}

private struct NotConnectedView: View {
    let slackManager: SlackIntegrationManager
    
    var body: some View {
        GroupBox {
            VStack(spacing: 20) {
                VStack(spacing: 12) {
                    Image(systemName: "link.circle")
                        .font(.system(size: 48))
                        .foregroundColor(.gray)
                    
                    Text("No Slack Workspaces Connected")
                        .font(.headline)
                        .foregroundColor(.secondary)
                    
                    Text("Connect your Slack workspaces to automatically update your status and notifications during focus sessions.")
                        .font(.callout)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                        .frame(maxWidth: 400)
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
                
                if slackManager.oauthManager.isAuthenticating {
                    HStack {
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle(tint: .blue))
                            .scaleEffect(0.8)
                        Text("Connecting to Slack...")
                    }
                    .font(.callout)
                    .foregroundColor(.blue)
                }
                
                if let error = slackManager.oauthManager.authError {
                    HStack {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .foregroundColor(.orange)
                        Text(error.localizedDescription)
                    }
                    .font(.callout)
                    .foregroundColor(.orange)
                }
            }
            .padding(.vertical, 20)
            .padding(.horizontal, 40)
        }
    }
}

private struct ConnectedWorkspacesView: View {
    let slackManager: SlackIntegrationManager
    @Binding var showingRemoveAlert: Bool
    @Binding var workspaceToRemove: SlackWorkspace?
    
    var body: some View {
        GroupBox("Connected Workspaces") {
            VStack(spacing: 12) {
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
            .padding()
        }
    }
}

private struct WorkspaceRowView: View {
    let workspace: SlackWorkspace
    let onRemove: () -> Void
    
    var body: some View {
        HStack {
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

private struct SlackSettingsView: View {
    let slackManager: SlackIntegrationManager
    @State private var localSettings: SlackIntegrationSettings
    
    init(slackManager: SlackIntegrationManager) {
        self.slackManager = slackManager
        self._localSettings = State(initialValue: slackManager.settings)
    }
    
    var body: some View {
        GroupBox("Settings") {
            VStack(spacing: 16) {
                Toggle("Enable Slack Integration", isOn: $localSettings.isEnabled)
                    .fontWeight(.medium)
                
                if localSettings.isEnabled {
                    Divider()
                    
                    VStack(spacing: 12) {
                        Toggle("Set Custom Status", isOn: $localSettings.useCustomStatus)
                        
                        if localSettings.useCustomStatus {
                            VStack(spacing: 8) {
                                HStack {
                                    Text("Status Text:")
                                        .frame(width: 100, alignment: .leading)
                                    TextField("Focus status message", text: $localSettings.focusStatusText)
                                        .textFieldStyle(.roundedBorder)
                                }
                                
                                HStack {
                                    Text("Emoji:")
                                        .frame(width: 100, alignment: .leading)
                                    TextField(":brain:", text: $localSettings.focusStatusEmoji)
                                        .textFieldStyle(.roundedBorder)
                                        .frame(maxWidth: 120)
                                    Spacer()
                                }
                                
                                Toggle("Clear status when focus ends", isOn: $localSettings.clearStatusOnExit)
                                    .font(.callout)
                            }
                            .padding(.leading, 20)
                        }
                    }
                    
                    Divider()
                    
                    VStack(spacing: 8) {
                        Toggle("Enable Do Not Disturb", isOn: $localSettings.enableDND)
                        
                        HStack {
                            Text("Duration:")
                                .frame(width: 100, alignment: .leading)
                            
                            Picker("Duration", selection: Binding(
                                get: { localSettings.statusDurationMinutes ?? 0 },
                                set: { localSettings.statusDurationMinutes = $0 == 0 ? nil : $0 }
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
                        .disabled(!localSettings.enableDND)
                    }
                }
            }
            .padding()
        }
        .onChange(of: localSettings) { newSettings in
            slackManager.updateSettings(newSettings)
        }
    }
}

private struct StatusPreviewView: View {
    let slackManager: SlackIntegrationManager
    @Binding var showingStatusPreview: Bool
    @Binding var statusPreviewText: String
    
    var body: some View {
        GroupBox("Preview") {
            VStack(spacing: 12) {
                HStack {
                    Text("Focus Status Preview:")
                        .font(.callout)
                        .foregroundColor(.secondary)
                    
                    Spacer()
                    
                    Button("Preview Current Status") {
                        Task {
                            do {
                                statusPreviewText = try await slackManager.previewStatus()
                                showingStatusPreview = true
                            } catch {
                                statusPreviewText = "Failed to load: \(error.localizedDescription)"
                                showingStatusPreview = true
                            }
                        }
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                }
                
                HStack {
                    Text("\(slackManager.settings.focusStatusEmoji) \(slackManager.settings.focusStatusText)")
                        .font(.callout)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(Color.blue.opacity(0.1))
                        .cornerRadius(8)
                    
                    Spacer()
                }
            }
            .padding()
        }
    }
}

private struct TestConnectionView: View {
    let slackManager: SlackIntegrationManager
    @Binding var isTestingConnection: Bool
    
    var body: some View {
        GroupBox("Connection") {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Status: \(slackManager.getConnectionStatusText())")
                        .font(.callout)
                    
                    if let error = slackManager.workspaceManager.lastError {
                        Text("Error: \(error.localizedDescription)")
                            .font(.caption)
                            .foregroundColor(.red)
                    }
                }
                
                Spacer()
                
                Button {
                    Task {
                        isTestingConnection = true
                        let success = await slackManager.testConnection()
                        isTestingConnection = false
                        
                        if success {
                            print("Connection test successful")
                        } else {
                            print("Connection test failed")
                        }
                    }
                } label: {
                    HStack {
                        if isTestingConnection {
                            ProgressView()
                                .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                .scaleEffect(0.8)
                        } else {
                            Image(systemName: "checkmark.circle")
                        }
                        Text("Test Connection")
                    }
                }
                .buttonStyle(.bordered)
                .disabled(isTestingConnection)
            }
            .padding()
        }
    }
}

#Preview {
    SlackConfigurationView(slackManager: SlackIntegrationManager())
        .frame(width: 600, height: 800)
}
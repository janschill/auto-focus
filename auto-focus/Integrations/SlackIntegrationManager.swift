import Foundation

protocol SlackIntegrationManagerDelegate: AnyObject {
    func slackIntegrationManager(_ manager: SlackIntegrationManager, didUpdateConnectionStatus isConnected: Bool)
    func slackIntegrationManager(_ manager: SlackIntegrationManager, didFailWithError error: SlackIntegrationError)
}

class SlackIntegrationManager: ObservableObject {
    weak var delegate: SlackIntegrationManagerDelegate?
    
    @Published var settings: SlackIntegrationSettings
    @Published var workspaceManager: SlackWorkspaceManager
    @Published var oauthManager: SlackOAuthManager
    
    private let userDefaultsManager: any PersistenceManaging
    private let settingsKey = "SlackIntegrationSettings"
    
    var isConnected: Bool {
        return !workspaceManager.connectedWorkspaces.isEmpty
    }
    
    var connectedWorkspaceCount: Int {
        return workspaceManager.connectedWorkspaces.count
    }
    
    init(userDefaultsManager: any PersistenceManaging = UserDefaultsManager()) {
        self.userDefaultsManager = userDefaultsManager
        self.workspaceManager = SlackWorkspaceManager()
        self.oauthManager = SlackOAuthManager()
        
        // Load settings
        self.settings = userDefaultsManager.load(SlackIntegrationSettings.self, forKey: settingsKey) ?? SlackIntegrationSettings()
        
        // Set up OAuth delegate
        oauthManager.delegate = self
        
        print("SlackIntegrationManager: Initialized with \(connectedWorkspaceCount) connected workspaces")
    }
    
    // MARK: - Settings Management
    
    func updateSettings(_ newSettings: SlackIntegrationSettings) {
        settings = newSettings
        saveSettings()
        
        print("SlackIntegrationManager: Updated settings - enabled: \(settings.isEnabled), status: '\(settings.focusStatusText)'")
    }
    
    private func saveSettings() {
        userDefaultsManager.save(settings, forKey: settingsKey)
    }
    
    // MARK: - Connection Management
    
    func connectWorkspace() {
        print("SlackIntegrationManager: Starting OAuth flow for new workspace")
        oauthManager.startOAuthFlow()
    }
    
    func disconnectWorkspace(_ workspace: SlackWorkspace) {
        workspaceManager.removeWorkspace(workspace)
        
        // Update settings to reflect current connected workspaces
        settings.connectedWorkspaces = workspaceManager.connectedWorkspaces
        saveSettings()
        
        delegate?.slackIntegrationManager(self, didUpdateConnectionStatus: isConnected)
        
        print("SlackIntegrationManager: Disconnected workspace \(workspace.name)")
    }
    
    func refreshAllWorkspaces() async {
        for workspace in workspaceManager.connectedWorkspaces {
            await workspaceManager.refreshWorkspace(workspace.id)
        }
    }
    
    // MARK: - Focus Integration
    
    func enableFocusMode() async {
        guard settings.isEnabled && isConnected else {
            print("SlackIntegrationManager: Focus mode not enabled or no workspaces connected")
            return
        }
        
        print("SlackIntegrationManager: Enabling focus mode for \(connectedWorkspaceCount) workspaces")
        
        // Set custom status if enabled
        if settings.useCustomStatus {
            let expiration = settings.statusDurationMinutes.map { 
                Date().addingTimeInterval(TimeInterval($0 * 60))
            }
            
            await workspaceManager.setFocusStatusForAllWorkspaces(
                statusText: settings.focusStatusText,
                emoji: settings.focusStatusEmoji,
                expiration: expiration
            )
        }
        
        // Enable DND if configured
        if settings.enableDND {
            // Use status duration or default to 120 minutes if indefinite
            let dndDuration = settings.statusDurationMinutes ?? 120
            await workspaceManager.enableDNDForAllWorkspaces(durationMinutes: dndDuration)
        }
    }
    
    func disableFocusMode() async {
        guard settings.isEnabled && isConnected else {
            print("SlackIntegrationManager: Focus mode not enabled or no workspaces connected")
            return
        }
        
        print("SlackIntegrationManager: Disabling focus mode for \(connectedWorkspaceCount) workspaces")
        
        // Clear status if configured
        if settings.useCustomStatus && settings.clearStatusOnExit {
            await workspaceManager.clearFocusStatusForAllWorkspaces()
        }
        
        // Disable DND if it was enabled
        if settings.enableDND {
            await workspaceManager.disableDNDForAllWorkspaces()
        }
    }
    
    // MARK: - Testing and Validation
    
    func testConnection() async -> Bool {
        guard isConnected else {
            return false
        }
        
        // Try to refresh one workspace to test connectivity
        if let firstWorkspace = workspaceManager.connectedWorkspaces.first {
            await workspaceManager.refreshWorkspace(firstWorkspace.id)
            
            // Check if workspace is still connected after refresh
            return workspaceManager.connectedWorkspaces.contains { $0.id == firstWorkspace.id }
        }
        
        return false
    }
    
    func previewStatus() async throws -> String {
        guard let firstWorkspace = workspaceManager.connectedWorkspaces.first else {
            throw SlackIntegrationError.noConnectedWorkspaces
        }
        
        let client = SlackAPIClient(workspace: firstWorkspace)
        let profile = try await client.getUserProfile()
        
        let currentStatus = profile.statusText ?? "(no status)"
        let currentEmoji = profile.statusEmoji ?? ""
        
        return "\(currentEmoji) \(currentStatus)"
    }
    
    // MARK: - Workspace Information
    
    func getWorkspaceDisplayName(_ workspace: SlackWorkspace) -> String {
        return "\(workspace.name) (\(workspace.userDisplayName))"
    }
    
    func getConnectionStatusText() -> String {
        switch connectedWorkspaceCount {
        case 0:
            return "Not connected"
        case 1:
            if let workspace = workspaceManager.connectedWorkspaces.first {
                return "Connected to \(workspace.name)"
            }
            return "Connected to 1 workspace"
        default:
            return "Connected to \(connectedWorkspaceCount) workspaces"
        }
    }
    
    // MARK: - Error Handling
    
    private func handleError(_ error: SlackIntegrationError) {
        print("SlackIntegrationManager: Error - \(error.localizedDescription)")
        delegate?.slackIntegrationManager(self, didFailWithError: error)
    }
}

// MARK: - SlackOAuthManagerDelegate

extension SlackIntegrationManager: SlackOAuthManagerDelegate {
    func slackOAuthManager(_ manager: SlackOAuthManager, didCompleteAuthWithWorkspace workspace: SlackWorkspace) {
        // Add workspace to manager
        workspaceManager.addWorkspace(workspace)
        
        // Update settings
        settings.connectedWorkspaces = workspaceManager.connectedWorkspaces
        saveSettings()
        
        // Notify delegate
        delegate?.slackIntegrationManager(self, didUpdateConnectionStatus: isConnected)
        
        print("SlackIntegrationManager: Successfully connected workspace \(workspace.name)")
    }
    
    func slackOAuthManager(_ manager: SlackOAuthManager, didFailWithError error: SlackIntegrationError) {
        handleError(error)
    }
}
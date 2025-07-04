import Foundation
import Security

class SlackWorkspaceManager: ObservableObject {
    @Published var connectedWorkspaces: [SlackWorkspace] = []
    @Published var isLoading = false
    @Published var lastError: SlackIntegrationError?
    
    private let keychainService = "com.janschill.auto-focus.slack"
    private let userDefaultsKey = "SlackConnectedWorkspaces"
    private let rateLimiter = SlackRateLimiter()
    
    init() {
        loadWorkspaces()
    }
    
    // MARK: - Workspace Management
    
    func addWorkspace(_ workspace: SlackWorkspace) {
        // Remove existing workspace with same ID if it exists
        connectedWorkspaces.removeAll { $0.id == workspace.id }
        
        // Add new workspace
        connectedWorkspaces.append(workspace)
        
        // Save to persistent storage
        saveWorkspaces()
        
        print("SlackWorkspaceManager: Added workspace \(workspace.name) (\(workspace.id))")
        print("SlackWorkspaceManager: Token length: \(workspace.accessToken.count)")
        print("SlackWorkspaceManager: Total workspaces: \(connectedWorkspaces.count)")
    }
    
    func removeWorkspace(_ workspace: SlackWorkspace) {
        connectedWorkspaces.removeAll { $0.id == workspace.id }
        
        // Remove token from keychain
        deleteTokenFromKeychain(workspaceId: workspace.id)
        
        // Save updated list
        saveWorkspaces()
        
        print("SlackWorkspaceManager: Removed workspace \(workspace.name) (\(workspace.id))")
    }
    
    func refreshWorkspace(_ workspaceId: String) async {
        guard let workspace = connectedWorkspaces.first(where: { $0.id == workspaceId }) else {
            return
        }
        
        do {
            let client = SlackAPIClient(workspace: workspace)
            let profile = try await client.getUserProfile()
            
            DispatchQueue.main.async {
                // Update workspace with fresh profile data
                if let index = self.connectedWorkspaces.firstIndex(where: { $0.id == workspaceId }) {
                    var updatedWorkspace = self.connectedWorkspaces[index]
                    updatedWorkspace = SlackWorkspace(
                        id: updatedWorkspace.id,
                        name: updatedWorkspace.name,
                        accessToken: updatedWorkspace.accessToken,
                        userId: updatedWorkspace.userId,
                        userDisplayName: profile.displayName ?? updatedWorkspace.userDisplayName,
                        scopes: updatedWorkspace.scopes,
                        connectedAt: updatedWorkspace.connectedAt
                    )
                    self.connectedWorkspaces[index] = updatedWorkspace
                    self.saveWorkspaces()
                }
            }
        } catch {
            DispatchQueue.main.async {
                if let slackError = error as? SlackIntegrationError {
                    self.lastError = slackError
                    
                    // Handle token expiration
                    if case .tokenExpired = slackError {
                        self.handleTokenExpiration(workspaceId: workspaceId)
                    }
                } else {
                    self.lastError = .networkError(error)
                }
            }
        }
    }
    
    private func handleTokenExpiration(workspaceId: String) {
        // Remove expired workspace
        if let workspace = connectedWorkspaces.first(where: { $0.id == workspaceId }) {
            removeWorkspace(workspace)
        }
        
        print("SlackWorkspaceManager: Token expired for workspace \(workspaceId), removed from connected workspaces")
    }
    
    // MARK: - Status and DND Operations
    
    func setFocusStatusForAllWorkspaces(statusText: String, emoji: String, expiration: Date? = nil) async {
        guard !connectedWorkspaces.isEmpty else {
            DispatchQueue.main.async {
                self.lastError = .noConnectedWorkspaces
            }
            return
        }
        
        // Check rate limiting
        guard rateLimiter.canMakeRequest() else {
            let waitTime = rateLimiter.timeUntilNextRequest()
            print("SlackWorkspaceManager: Rate limited, waiting \(waitTime) seconds")
            try? await Task.sleep(nanoseconds: UInt64(waitTime * 1_000_000_000))
            return
        }
        
        await withTaskGroup(of: Void.self) { group in
            for workspace in connectedWorkspaces {
                group.addTask {
                    await self.setStatusForWorkspace(workspace, statusText: statusText, emoji: emoji, expiration: expiration)
                }
            }
        }
        
        rateLimiter.recordRequest()
    }
    
    func enableDNDForAllWorkspaces(durationMinutes: Int) async {
        guard !connectedWorkspaces.isEmpty else {
            DispatchQueue.main.async {
                self.lastError = .noConnectedWorkspaces
            }
            return
        }
        
        await withTaskGroup(of: Void.self) { group in
            for workspace in connectedWorkspaces {
                group.addTask {
                    await self.enableDNDForWorkspace(workspace, durationMinutes: durationMinutes)
                }
            }
        }
    }
    
    func clearFocusStatusForAllWorkspaces() async {
        await withTaskGroup(of: Void.self) { group in
            for workspace in connectedWorkspaces {
                group.addTask {
                    await self.clearStatusForWorkspace(workspace)
                }
            }
        }
    }
    
    func disableDNDForAllWorkspaces() async {
        await withTaskGroup(of: Void.self) { group in
            for workspace in connectedWorkspaces {
                group.addTask {
                    await self.disableDNDForWorkspace(workspace)
                }
            }
        }
    }
    
    // MARK: - Individual Workspace Operations
    
    private func setStatusForWorkspace(_ workspace: SlackWorkspace, statusText: String, emoji: String, expiration: Date?) async {
        do {
            let client = SlackAPIClient(workspace: workspace)
            try await client.setStatus(text: statusText, emoji: emoji, expiration: expiration)
            print("SlackWorkspaceManager: Set status for \(workspace.name): \(statusText)")
        } catch {
            print("SlackWorkspaceManager: Failed to set status for \(workspace.name): \(error)")
            print("SlackWorkspaceManager: Workspace token: \(workspace.accessToken.prefix(10))...")
            await handleWorkspaceError(workspace: workspace, error: error)
        }
    }
    
    private func clearStatusForWorkspace(_ workspace: SlackWorkspace) async {
        do {
            let client = SlackAPIClient(workspace: workspace)
            try await client.clearStatus()
            print("SlackWorkspaceManager: Cleared status for \(workspace.name)")
        } catch {
            print("SlackWorkspaceManager: Failed to clear status for \(workspace.name): \(error)")
            await handleWorkspaceError(workspace: workspace, error: error)
        }
    }
    
    private func enableDNDForWorkspace(_ workspace: SlackWorkspace, durationMinutes: Int) async {
        do {
            let client = SlackAPIClient(workspace: workspace)
            try await client.enableDND(durationMinutes: durationMinutes)
            print("SlackWorkspaceManager: Enabled DND for \(workspace.name): \(durationMinutes) minutes")
        } catch {
            print("SlackWorkspaceManager: Failed to enable DND for \(workspace.name): \(error)")
            await handleWorkspaceError(workspace: workspace, error: error)
        }
    }
    
    private func disableDNDForWorkspace(_ workspace: SlackWorkspace) async {
        do {
            let client = SlackAPIClient(workspace: workspace)
            try await client.disableDND()
            print("SlackWorkspaceManager: Disabled DND for \(workspace.name)")
        } catch {
            print("SlackWorkspaceManager: Failed to disable DND for \(workspace.name): \(error)")
            await handleWorkspaceError(workspace: workspace, error: error)
        }
    }
    
    private func handleWorkspaceError(workspace: SlackWorkspace, error: Error) async {
        if let slackError = error as? SlackIntegrationError {
            switch slackError {
            case .tokenExpired:
                DispatchQueue.main.async {
                    self.handleTokenExpiration(workspaceId: workspace.id)
                }
            case .rateLimitExceeded:
                print("SlackWorkspaceManager: Rate limit exceeded for \(workspace.name)")
            default:
                DispatchQueue.main.async {
                    self.lastError = slackError
                }
            }
        }
    }
    
    // MARK: - Persistence
    
    private func saveWorkspaces() {
        // Save workspace metadata to UserDefaults (without tokens)
        let workspaceMetadata = connectedWorkspaces.map { workspace in
            return [
                "id": workspace.id,
                "name": workspace.name,
                "userId": workspace.userId,
                "userDisplayName": workspace.userDisplayName,
                "scopes": workspace.scopes,
                "connectedAt": workspace.connectedAt.timeIntervalSince1970
            ] as [String: Any]
        }
        
        UserDefaults.standard.set(workspaceMetadata, forKey: userDefaultsKey)
        
        // Save tokens to Keychain
        for workspace in connectedWorkspaces {
            saveTokenToKeychain(workspaceId: workspace.id, token: workspace.accessToken)
        }
    }
    
    private func loadWorkspaces() {
        guard let workspaceMetadata = UserDefaults.standard.array(forKey: userDefaultsKey) as? [[String: Any]] else {
            print("SlackWorkspaceManager: No workspace metadata found in UserDefaults")
            return
        }
        
        print("SlackWorkspaceManager: Loading \(workspaceMetadata.count) workspaces from UserDefaults")
        var loadedWorkspaces: [SlackWorkspace] = []
        
        for metadata in workspaceMetadata {
            guard let workspaceId = metadata["id"] as? String,
                  let name = metadata["name"] as? String,
                  let userId = metadata["userId"] as? String,
                  let userDisplayName = metadata["userDisplayName"] as? String,
                  let scopes = metadata["scopes"] as? [String],
                  let connectedAtTimestamp = metadata["connectedAt"] as? TimeInterval,
                  let token = loadTokenFromKeychain(workspaceId: workspaceId) else {
                print("SlackWorkspaceManager: Failed to load token for workspace \(metadata["id"] as? String ?? "unknown")")
                continue
            }
            
            let workspace = SlackWorkspace(
                id: workspaceId,
                name: name,
                accessToken: token,
                userId: userId,
                userDisplayName: userDisplayName,
                scopes: scopes,
                connectedAt: Date(timeIntervalSince1970: connectedAtTimestamp)
            )
            
            loadedWorkspaces.append(workspace)
        }
        
        connectedWorkspaces = loadedWorkspaces
        print("SlackWorkspaceManager: Loaded \(loadedWorkspaces.count) workspaces")
    }
    
    // MARK: - Keychain Operations
    
    private func saveTokenToKeychain(workspaceId: String, token: String) {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: keychainService,
            kSecAttrAccount as String: workspaceId,
            kSecValueData as String: token.data(using: .utf8)!
        ]
        
        // Delete existing entry
        SecItemDelete(query as CFDictionary)
        
        // Add new entry
        let status = SecItemAdd(query as CFDictionary, nil)
        
        if status != errSecSuccess {
            print("SlackWorkspaceManager: Failed to save token to keychain for \(workspaceId): \(status)")
        }
    }
    
    private func loadTokenFromKeychain(workspaceId: String) -> String? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: keychainService,
            kSecAttrAccount as String: workspaceId,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]
        
        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        
        guard status == errSecSuccess,
              let data = result as? Data,
              let token = String(data: data, encoding: .utf8) else {
            return nil
        }
        
        return token
    }
    
    private func deleteTokenFromKeychain(workspaceId: String) {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: keychainService,
            kSecAttrAccount as String: workspaceId
        ]
        
        let status = SecItemDelete(query as CFDictionary)
        
        if status != errSecSuccess && status != errSecItemNotFound {
            print("SlackWorkspaceManager: Failed to delete token from keychain for \(workspaceId): \(status)")
        }
    }
}
import Foundation

protocol SlackOAuthManagerDelegate: AnyObject {
    func slackOAuthManager(_ manager: SlackOAuthManager, didCompleteAuthWithWorkspace workspace: SlackWorkspace)
    func slackOAuthManager(_ manager: SlackOAuthManager, didFailWithError error: SlackIntegrationError)
}

class SlackOAuthManager: ObservableObject {
    weak var delegate: SlackOAuthManagerDelegate?
    
    private var currentState: String?
    
    @Published var isAuthenticating = false
    @Published var authError: SlackIntegrationError?
    
    init() {
        setupURLSchemeObserver()
    }
    
    // MARK: - OAuth Flow
    
    func startOAuthFlow() {
        isAuthenticating = true
        authError = nil
        
        // Generate random state for CSRF protection
        currentState = UUID().uuidString
        
        // Build OAuth URL
        guard let authURL = buildOAuthURL() else {
            handleAuthError(.invalidResponse)
            return
        }
        
        // Open browser for OAuth
        NSWorkspace.shared.open(authURL)
        
        print("SlackOAuth: Starting OAuth flow with state: \(currentState ?? "none")")
    }
    
    private func buildOAuthURL() -> URL? {
        guard let state = currentState else { return nil }
        
        var components = URLComponents(string: SlackAppConfig.authorizationURL)!
        components.queryItems = [
            URLQueryItem(name: "client_id", value: SlackAppConfig.clientId),
            URLQueryItem(name: "redirect_uri", value: SlackAppConfig.redirectURI),
            URLQueryItem(name: "state", value: state),
            URLQueryItem(name: "user_scope", value: SlackAppConfig.scopes.joined(separator: ","))
        ]
        
        return components.url
    }
    
    // MARK: - URL Scheme Handling
    
    private func setupURLSchemeObserver() {
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleURLSchemeCallback(_:)),
            name: Notification.Name("SlackOAuthCallback"),
            object: nil
        )
    }
    
    @objc private func handleURLSchemeCallback(_ notification: Notification) {
        guard let userInfo = notification.userInfo as? [String: String] else {
            print("SlackOAuth: Invalid callback data")
            return
        }
        
        DispatchQueue.main.async {
            if userInfo.keys.contains("error") {
                self.handleOAuthError(userInfo)
            } else {
                self.handleOAuthSuccess(userInfo)
            }
        }
    }
    
    private func handleOAuthSuccess(_ params: [String: String]) {
        guard let accessToken = params["access_token"],
              let teamId = params["team_id"],
              let teamName = params["team_name"],
              let userId = params["user_id"],
              let scope = params["scope"],
              let state = params["state"] else {
            print("SlackOAuth: Missing required parameters in success callback")
            handleAuthError(.invalidResponse)
            return
        }
        
        // Validate state parameter for CSRF protection
        guard state == currentState else {
            print("SlackOAuth: State mismatch - possible CSRF attack")
            handleAuthError(.authenticationFailed)
            return
        }
        
        print("SlackOAuth: Successfully received tokens for workspace: \(teamName)")
        
        // Create workspace object
        let workspace = SlackWorkspace(
            id: teamId,
            name: teamName,
            accessToken: accessToken,
            userId: userId,
            userDisplayName: "Loading...", // We'll fetch this from the API
            scopes: scope.components(separatedBy: ","),
            connectedAt: Date()
        )
        
        // Fetch user display name
        Task {
            await self.fetchUserDisplayName(for: workspace)
        }
        
        // Complete OAuth flow
        isAuthenticating = false
        authError = nil
        currentState = nil
        delegate?.slackOAuthManager(self, didCompleteAuthWithWorkspace: workspace)
    }
    
    private func handleOAuthError(_ params: [String: String]) {
        let errorCode = params["error"] ?? "unknown_error"
        print("SlackOAuth: OAuth error: \(errorCode)")
        
        let error: SlackIntegrationError
        switch errorCode {
        case "access_denied":
            error = .authenticationFailed
        case "invalid_request":
            error = .invalidResponse
        default:
            error = .authenticationFailed
        }
        
        handleAuthError(error)
    }
    
    private func handleAuthError(_ error: SlackIntegrationError) {
        print("SlackOAuth: Authentication failed: \(error.localizedDescription)")
        isAuthenticating = false
        authError = error
        currentState = nil
        delegate?.slackOAuthManager(self, didFailWithError: error)
    }
    
    // MARK: - User Profile Fetching
    
    private func fetchUserDisplayName(for workspace: SlackWorkspace) async {
        do {
            let client = SlackAPIClient(workspace: workspace)
            let profile = try await client.getUserProfile()
            
            // Update workspace with display name
            let updatedWorkspace = SlackWorkspace(
                id: workspace.id,
                name: workspace.name,
                accessToken: workspace.accessToken,
                userId: workspace.userId,
                userDisplayName: profile.displayName ?? profile.realName ?? "Unknown User",
                scopes: workspace.scopes,
                connectedAt: workspace.connectedAt
            )
            
            // Notify about the updated workspace
            DispatchQueue.main.async {
                self.delegate?.slackOAuthManager(self, didCompleteAuthWithWorkspace: updatedWorkspace)
            }
            
        } catch {
            print("SlackOAuth: Failed to fetch user profile: \(error)")
            // Don't fail the OAuth process for this, just keep the workspace as-is
        }
    }
    
    deinit {
        NotificationCenter.default.removeObserver(self)
    }
}

// MARK: - URL Scheme Registration Helper

extension SlackOAuthManager {
    static func registerURLScheme() {
        // This is called from AppDelegate to ensure URL scheme is properly registered
        print("SlackOAuth: URL scheme autofocus:// registered for OAuth callbacks")
    }
}
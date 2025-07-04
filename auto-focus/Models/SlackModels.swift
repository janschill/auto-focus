import Foundation

// MARK: - Slack Workspace Models

struct SlackWorkspace: Codable, Identifiable, Hashable {
    let id: String // team_id from Slack
    let name: String // team_name
    let accessToken: String
    let userId: String // user_id from OAuth response
    let userDisplayName: String
    let scopes: [String]
    let connectedAt: Date
    
    static func == (lhs: SlackWorkspace, rhs: SlackWorkspace) -> Bool {
        return lhs.id == rhs.id
    }
    
    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
}

// MARK: - Slack API Models

struct SlackTokenResponse: Codable {
    let ok: Bool
    let accessToken: String
    let tokenType: String
    let scope: String
    let authedUser: AuthedUser
    let team: Team
    let error: String?
    
    struct AuthedUser: Codable {
        let id: String
    }
    
    struct Team: Codable {
        let id: String
        let name: String
    }
}

struct SlackOAuthResponse: Codable {
    let ok: Bool
    let accessToken: String
    let tokenType: String
    let scope: String
    let userId: String
    let teamId: String
    let teamName: String
    let userName: String?
    
    private enum CodingKeys: String, CodingKey {
        case ok
        case accessToken = "access_token"
        case tokenType = "token_type"
        case scope
        case userId = "user_id"
        case teamId = "team_id"
        case teamName = "team_name"
        case userName = "user_name"
    }
}

struct SlackAPIError: Codable, Error {
    let ok: Bool
    let error: String
    let detail: String?
    
    var localizedDescription: String {
        return detail ?? error
    }
}

struct SlackProfileResponse: Codable {
    let ok: Bool
    let profile: SlackProfile?
    let error: String?
}

struct SlackProfile: Codable {
    let statusText: String?
    let statusEmoji: String?
    let statusExpiration: Int?
    let displayName: String?
    let realName: String?
    
    private enum CodingKeys: String, CodingKey {
        case statusText = "status_text"
        case statusEmoji = "status_emoji"
        case statusExpiration = "status_expiration"
        case displayName = "display_name"
        case realName = "real_name"
    }
}

struct SlackDNDResponse: Codable {
    let ok: Bool
    let snoozeEnabled: Bool?
    let snoozeEndtime: Int?
    let snoozeRemaining: Int?
    let snoozeIsIndefinite: Bool?
    let error: String?
    
    private enum CodingKeys: String, CodingKey {
        case ok
        case snoozeEnabled = "snooze_enabled"
        case snoozeEndtime = "snooze_endtime"
        case snoozeRemaining = "snooze_remaining"
        case snoozeIsIndefinite = "snooze_is_indefinite"
        case error
    }
}

// MARK: - Slack Integration Settings

struct SlackIntegrationSettings: Codable, Equatable {
    var isEnabled: Bool = false
    var focusStatusText: String = "🧠 In deep focus mode"
    var focusStatusEmoji: String = ":brain:"
    var enableDND: Bool = true
    var connectedWorkspaces: [SlackWorkspace] = []
    
    // Status customization options
    var useCustomStatus: Bool = true
    var clearStatusOnExit: Bool = true
    var statusDurationMinutes: Int? = nil // nil means indefinite
}

// MARK: - Slack Integration Errors

enum SlackIntegrationError: Error, LocalizedError {
    case notConfigured
    case noConnectedWorkspaces
    case authenticationFailed
    case networkError(Error)
    case apiError(SlackAPIError)
    case invalidResponse
    case rateLimitExceeded
    case workspaceNotFound(String)
    case tokenExpired(String)
    
    var errorDescription: String? {
        switch self {
        case .notConfigured:
            return "Slack integration is not configured"
        case .noConnectedWorkspaces:
            return "No Slack workspaces are connected"
        case .authenticationFailed:
            return "Slack authentication failed"
        case .networkError(let error):
            return "Network error: \(error.localizedDescription)"
        case .apiError(let slackError):
            return "Slack API error: \(slackError.localizedDescription)"
        case .invalidResponse:
            return "Invalid response from Slack API"
        case .rateLimitExceeded:
            return "Slack API rate limit exceeded"
        case .workspaceNotFound(let workspaceId):
            return "Workspace not found: \(workspaceId)"
        case .tokenExpired(let workspaceId):
            return "Access token expired for workspace: \(workspaceId)"
        }
    }
}

// MARK: - Slack App Configuration

struct SlackAppConfig {
    // Use the centralized configuration
    static let clientId = SlackConfig.clientId
    static let redirectURI = SlackConfig.redirectURI
    static let scopes = SlackConfig.scopes
    static let authorizationURL = SlackConfig.authorizationURL
    
    // Slack API URLs
    static let profileSetURL = "https://slack.com/api/users.profile.set"
    static let profileGetURL = "https://slack.com/api/users.profile.get"
    static let dndSetSnoozeURL = "https://slack.com/api/dnd.setSnooze"
    static let dndEndSnoozeURL = "https://slack.com/api/dnd.endSnooze"
    
    // Rate limiting
    static let maxProfileUpdatesPerMinute = 10
    static let maxRequestsPerMinute = 60
}
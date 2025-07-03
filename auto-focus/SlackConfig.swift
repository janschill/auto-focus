import Foundation

// MARK: - Slack Configuration

struct SlackConfig {
    static let clientId = "8373877629553.8361209748131"
    static let redirectURI = "https://auto-focus.app/api/slack/oauth/callback"
    static let scopes = ["users.profile:read", "users.profile:write", "dnd:write"]
    static let authorizationURL = "https://slack.com/oauth/v2/authorize"
}

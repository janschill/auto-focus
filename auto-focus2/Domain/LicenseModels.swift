import Foundation

public enum LicenseState: String, Codable, Hashable, Sendable {
    case unlicensed
    case licensed
    case offline
    case validationFailed
    case unknown
}

public struct PremiumEntitlements: Codable, Hashable, Sendable {
    /// -1 means unlimited.
    public var maxFocusEntities: Int
    public var exportEnabled: Bool
    /// -1 means unlimited.
    public var insightsDepthDays: Int

    public init(maxFocusEntities: Int, exportEnabled: Bool, insightsDepthDays: Int) {
        self.maxFocusEntities = maxFocusEntities
        self.exportEnabled = exportEnabled
        self.insightsDepthDays = insightsDepthDays
    }
}

public struct LicenseStatusSnapshot: Codable, Hashable, Sendable {
    public var state: LicenseState
    public var lastValidatedAt: Date?
    public var message: String?
    public var entitlements: PremiumEntitlements

    public init(state: LicenseState, lastValidatedAt: Date? = nil, message: String? = nil, entitlements: PremiumEntitlements) {
        self.state = state
        self.lastValidatedAt = lastValidatedAt
        self.message = message
        self.entitlements = entitlements
    }
}



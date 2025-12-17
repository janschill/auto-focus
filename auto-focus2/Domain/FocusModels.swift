import Foundation

// MARK: - Focus Entity

public enum FocusEntityType: String, Codable, Hashable, Sendable {
    case app
    case domain
}

public struct FocusEntity: Identifiable, Codable, Hashable, Sendable {
    public let id: UUID
    public var type: FocusEntityType
    public var displayName: String
    /// For `app`: bundle identifier (e.g. com.apple.dt.Xcode). For `domain`: normalized domain (e.g. github.com).
    public var matchValue: String
    public var isEnabled: Bool
    public var createdAt: Date
    public var updatedAt: Date

    public init(
        id: UUID = UUID(),
        type: FocusEntityType,
        displayName: String,
        matchValue: String,
        isEnabled: Bool = true,
        createdAt: Date = Date(),
        updatedAt: Date = Date()
    ) {
        self.id = id
        self.type = type
        self.displayName = displayName
        self.matchValue = matchValue
        self.isEnabled = isEnabled
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }
}

// MARK: - Settings

public struct FocusSettings: Codable, Hashable, Sendable {
    public var activationMinutes: Int
    public var bufferSeconds: Int

    public init(activationMinutes: Int, bufferSeconds: Int) {
        self.activationMinutes = activationMinutes
        self.bufferSeconds = bufferSeconds
    }
}

// MARK: - Events & Sessions

public enum FocusEventKind: String, Codable, Hashable, Sendable {
    case foregroundChanged
    case domainChanged
    case enteredCounting
    case enteredFocusMode
    case enteredBuffer
    case exitedFocusMode
    case permissionChanged
    case error
}

public struct FocusEvent: Identifiable, Codable, Hashable, Sendable {
    public let id: UUID
    public let timestamp: Date
    public var kind: FocusEventKind
    public var appBundleId: String?
    public var domain: String?
    public var focusEntityId: UUID?
    public var details: String?

    public init(
        id: UUID = UUID(),
        timestamp: Date = Date(),
        kind: FocusEventKind,
        appBundleId: String? = nil,
        domain: String? = nil,
        focusEntityId: UUID? = nil,
        details: String? = nil
    ) {
        self.id = id
        self.timestamp = timestamp
        self.kind = kind
        self.appBundleId = appBundleId
        self.domain = domain
        self.focusEntityId = focusEntityId
        self.details = details
    }
}

public enum FocusSessionEndReason: String, Codable, Hashable, Sendable {
    case leftFocusEntities
    case bufferTimeout
    case userDisabled
    case error
}

public struct FocusSession: Identifiable, Codable, Hashable, Sendable {
    public let id: UUID
    public let startedAt: Date
    public var endedAt: Date?
    public var activationMinutes: Int
    public var bufferSeconds: Int
    public var endedReason: FocusSessionEndReason?
    public var totalSecondsInFocusMode: Int

    public init(
        id: UUID = UUID(),
        startedAt: Date = Date(),
        endedAt: Date? = nil,
        activationMinutes: Int,
        bufferSeconds: Int,
        endedReason: FocusSessionEndReason? = nil,
        totalSecondsInFocusMode: Int = 0
    ) {
        self.id = id
        self.startedAt = startedAt
        self.endedAt = endedAt
        self.activationMinutes = activationMinutes
        self.bufferSeconds = bufferSeconds
        self.endedReason = endedReason
        self.totalSecondsInFocusMode = totalSecondsInFocusMode
    }
}



import Foundation

// MARK: - Foreground observation

public struct ForegroundContext: Equatable, Sendable {
    public var appBundleId: String?
    public var domain: String?

    public init(appBundleId: String?, domain: String?) {
        self.appBundleId = appBundleId
        self.domain = domain
    }
}

public protocol ForegroundProviding: Sendable {
    func currentForegroundAppBundleId() -> String?
}

// MARK: - Browser domain provider

public enum DomainAvailabilityReason: String, Sendable {
    case permissionDenied
    case unsupportedBrowser
    case noActiveTab
    case scriptError
    case unknown
}

public struct DomainResult: Equatable, Sendable {
    public var domain: String?
    public var isAvailable: Bool
    public var reason: DomainAvailabilityReason?

    public static func available(_ domain: String) -> DomainResult {
        DomainResult(domain: domain, isAvailable: true, reason: nil)
    }

    public static func unavailable(reason: DomainAvailabilityReason) -> DomainResult {
        DomainResult(domain: nil, isAvailable: false, reason: reason)
    }
}

public protocol BrowserDomainProviding: Sendable {
    func currentDomainIfBrowserFrontmost(foregroundBundleId: String?) -> DomainResult
}

// MARK: - Notifications control (Shortcut runner)

public enum NotificationsDesiredState: Sendable {
    case enabled
    case disabled
}

public protocol NotificationsControlling: Sendable {
    func setNotifications(_ state: NotificationsDesiredState) async throws
}

// MARK: - Persistence ports (domain-level)

public protocol FocusSettingsStoring: Sendable {
    func load() throws -> FocusSettings
    func save(_ settings: FocusSettings) throws
}

public protocol FocusEntityStoring: Sendable {
    func list() throws -> [FocusEntity]
    func upsert(_ entity: FocusEntity) throws
    func delete(id: UUID) throws
}

public protocol FocusEventStoring: Sendable {
    func append(_ event: FocusEvent) throws
}

public protocol FocusSessionStoring: Sendable {
    func start(_ session: FocusSession) throws
    func end(sessionId: UUID, endedAt: Date, reason: FocusSessionEndReason, totalSecondsInFocusMode: Int) throws
}



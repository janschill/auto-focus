import Foundation

// MARK: - Browser Integration Models

struct FocusURL: Identifiable, Codable, Hashable {
    let id: UUID
    var name: String
    var domain: String
    var matchType: URLMatchType
    var isEnabled: Bool
    var category: URLCategory
    var isPremium: Bool

    init(name: String, domain: String, matchType: URLMatchType = .domain, category: URLCategory = .work, isPremium: Bool = false) {
        self.id = UUID()
        self.name = name
        self.domain = domain.lowercased()
        self.matchType = matchType
        self.isEnabled = true
        self.category = category
        self.isPremium = isPremium
    }

    // Check if a URL matches this focus URL
    func matches(_ url: String) -> Bool {
        guard isEnabled else { return false }

        let urlLowercase = url.lowercased()
        let domainLowercase = domain.lowercased()

        switch matchType {
        case .exact:
            return urlLowercase == domainLowercase
        case .domain:
            // Extract hostname from URL
            if let urlObj = URL(string: url), let host = urlObj.host {
                return host == domainLowercase || host.hasSuffix("." + domainLowercase)
            }
            return urlLowercase.contains(domainLowercase)
        case .contains:
            return urlLowercase.contains(domainLowercase)
        case .startsWith:
            return urlLowercase.hasPrefix(domainLowercase)
        }
    }
}

enum URLMatchType: String, CaseIterable, Codable {
    case exact = "exact"
    case domain = "domain"
    case contains = "contains"
    case startsWith = "startsWith"

    var displayName: String {
        switch self {
        case .exact: return "Exact URL"
        case .domain: return "Domain"
        case .contains: return "Contains"
        case .startsWith: return "Starts With"
        }
    }

    var description: String {
        switch self {
        case .exact: return "Matches the exact URL"
        case .domain: return "Matches the domain (recommended)"
        case .contains: return "URL contains the text"
        case .startsWith: return "URL starts with the text"
        }
    }
}

enum URLCategory: String, CaseIterable, Codable {
    case work = "work"
    case communication = "communication"
    case development = "development"
    case design = "design"
    case documentation = "documentation"
    case productivity = "productivity"
    case learning = "learning"
    case custom = "custom"

    var displayName: String {
        switch self {
        case .work: return "Work"
        case .communication: return "Communication"
        case .development: return "Development"
        case .design: return "Design"
        case .documentation: return "Documentation"
        case .productivity: return "Productivity"
        case .learning: return "Learning"
        case .custom: return "Custom"
        }
    }

    var icon: String {
        switch self {
        case .work: return "briefcase"
        case .communication: return "message"
        case .development: return "terminal"
        case .design: return "paintbrush"
        case .documentation: return "doc.text"
        case .productivity: return "checkmark.circle"
        case .learning: return "book"
        case .custom: return "star"
        }
    }

    var color: String {
        switch self {
        case .work: return "blue"
        case .communication: return "green"
        case .development: return "purple"
        case .design: return "pink"
        case .documentation: return "orange"
        case .productivity: return "indigo"
        case .learning: return "yellow"
        case .custom: return "gray"
        }
    }
}

// MARK: - Browser Tab Information

struct BrowserTabInfo: Codable {
    let url: String
    let title: String
    let timestamp: Date
    let isFocusURL: Bool
    let matchedFocusURL: FocusURL?

    init(url: String, title: String, isFocusURL: Bool = false, matchedFocusURL: FocusURL? = nil) {
        self.url = url
        self.title = title
        self.timestamp = Date()
        self.isFocusURL = isFocusURL
        self.matchedFocusURL = matchedFocusURL
    }
}

// MARK: - Extension Health Models

struct ExtensionHealth: Codable {
    let version: String
    let installationDate: Date?
    let lastUpdateCheck: Date?
    let errors: [ExtensionError]
    let consecutiveFailures: Int

    init(version: String, installationDate: Date? = nil, lastUpdateCheck: Date? = nil, errors: [ExtensionError] = [], consecutiveFailures: Int = 0) {
        self.version = version
        self.installationDate = installationDate
        self.lastUpdateCheck = lastUpdateCheck
        self.errors = errors
        self.consecutiveFailures = consecutiveFailures
    }
}

struct ExtensionError: Codable, Identifiable {
    let id = UUID()
    let type: String
    let message: String
    let timestamp: Date
    let stack: String?

    init(type: String, message: String, timestamp: Date = Date(), stack: String? = nil) {
        self.type = type
        self.message = message
        self.timestamp = timestamp
        self.stack = stack
    }
}

enum ConnectionQuality: String, Codable, CaseIterable {
    case unknown = "unknown"
    case excellent = "excellent"
    case good = "good"
    case fair = "fair"
    case poor = "poor"
    case disconnected = "disconnected"

    var displayName: String {
        switch self {
        case .unknown: return "Unknown"
        case .excellent: return "Excellent"
        case .good: return "Good"
        case .fair: return "Fair"
        case .poor: return "Poor"
        case .disconnected: return "Disconnected"
        }
    }

    var color: String {
        switch self {
        case .unknown: return "gray"
        case .excellent: return "green"
        case .good: return "blue"
        case .fair: return "yellow"
        case .poor: return "orange"
        case .disconnected: return "red"
        }
    }

    var icon: String {
        switch self {
        case .unknown: return "questionmark.circle"
        case .excellent: return "wifi.circle.fill"
        case .good: return "wifi.circle"
        case .fair: return "wifi.exclamationmark"
        case .poor: return "wifi.slash"
        case .disconnected: return "wifi.slash.circle"
        }
    }
}

// MARK: - Native Messaging Protocol

struct NativeMessage: Codable {
    let command: String
    let data: [String: AnyCodable]?
    let timestamp: Date

    init(command: String, data: [String: Any]? = nil) {
        self.command = command
        self.data = data?.mapValues { AnyCodable($0) }
        self.timestamp = Date()
    }
}

struct AnyCodable: Codable {
    let value: Any

    init(_ value: Any) {
        self.value = value
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()

        switch value {
        case let string as String:
            try container.encode(string)
        case let int as Int:
            try container.encode(int)
        case let double as Double:
            try container.encode(double)
        case let bool as Bool:
            try container.encode(bool)
        case let array as [Any]:
            try container.encode(array.map { AnyCodable($0) })
        case let dict as [String: Any]:
            try container.encode(dict.mapValues { AnyCodable($0) })
        default:
            try container.encode(String(describing: value))
        }
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()

        if let string = try? container.decode(String.self) {
            value = string
        } else if let int = try? container.decode(Int.self) {
            value = int
        } else if let double = try? container.decode(Double.self) {
            value = double
        } else if let bool = try? container.decode(Bool.self) {
            value = bool
        } else if let array = try? container.decode([AnyCodable].self) {
            value = array.map { $0.value }
        } else if let dict = try? container.decode([String: AnyCodable].self) {
            value = dict.mapValues { $0.value }
        } else {
            throw DecodingError.dataCorruptedError(in: container, debugDescription: "Unsupported type")
        }
    }
}

// MARK: - Common Focus URL Presets

extension FocusURL {
    static let commonPresets: [FocusURL] = [
        // Development
        FocusURL(name: "GitHub", domain: "github.com", category: .development, isPremium: false),
        FocusURL(name: "GitLab", domain: "gitlab.com", category: .development, isPremium: true),
        FocusURL(name: "Stack Overflow", domain: "stackoverflow.com", category: .development, isPremium: false),
        FocusURL(name: "MDN Web Docs", domain: "developer.mozilla.org", category: .documentation, isPremium: true),

        // Design
        FocusURL(name: "Figma", domain: "figma.com", category: .design, isPremium: true),
        FocusURL(name: "Adobe Creative Cloud", domain: "adobe.com", category: .design, isPremium: true),
        FocusURL(name: "Dribbble", domain: "dribbble.com", category: .design, isPremium: true),

        // Productivity
        FocusURL(name: "Google Docs", domain: "docs.google.com", category: .productivity, isPremium: false),
        FocusURL(name: "Google Sheets", domain: "sheets.google.com", category: .productivity, isPremium: true),
        FocusURL(name: "Notion", domain: "notion.so", category: .productivity, isPremium: true),
        FocusURL(name: "Trello", domain: "trello.com", category: .productivity, isPremium: true),
        FocusURL(name: "Asana", domain: "asana.com", category: .productivity, isPremium: true),

        // Communication (Work)
        FocusURL(name: "Slack", domain: "slack.com", category: .communication, isPremium: true),
        FocusURL(name: "Microsoft Teams", domain: "teams.microsoft.com", category: .communication, isPremium: true),
        FocusURL(name: "Zoom", domain: "zoom.us", category: .communication, isPremium: true),

        // Documentation
        FocusURL(name: "Confluence", domain: "atlassian.net", category: .documentation, isPremium: true),
        FocusURL(name: "GitBook", domain: "gitbook.io", category: .documentation, isPremium: true),

        // Learning
        FocusURL(name: "Coursera", domain: "coursera.org", category: .learning, isPremium: true),
        FocusURL(name: "Udemy", domain: "udemy.com", category: .learning, isPremium: true),
        FocusURL(name: "Khan Academy", domain: "khanacademy.org", category: .learning, isPremium: true)
    ]

    static let freePresets: [FocusURL] = {
        return commonPresets.filter { !$0.isPremium }
    }()
}

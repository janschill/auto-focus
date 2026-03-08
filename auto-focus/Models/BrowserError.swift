import Foundation

/// Domain-specific errors for browser integration functionality
enum BrowserError: LocalizedError {
    case invalidURL(String)
    case focusURLAddFailed(String)
    case focusURLRemoveFailed(String)
    case automationPermissionDenied(String)
    case unsupportedBrowser(String)

    var errorDescription: String? {
        switch self {
        case .invalidURL(let url):
            return "Invalid URL format: \(url)"
        case .focusURLAddFailed(let reason):
            return "Failed to add focus URL: \(reason)"
        case .focusURLRemoveFailed(let reason):
            return "Failed to remove focus URL: \(reason)"
        case .automationPermissionDenied(let browser):
            return "Automation permission denied for \(browser)"
        case .unsupportedBrowser(let browser):
            return "Browser not supported: \(browser)"
        }
    }
}

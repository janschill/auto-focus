import Foundation

/// Domain-specific errors for browser integration functionality
enum BrowserError: LocalizedError {
    case extensionNotConnected
    case serverStartFailed(Error)
    case serverStopFailed(Error)
    case invalidMessageFormat(String)
    case connectionTimeout
    case invalidURL(String)
    case focusURLAddFailed(String)
    case focusURLRemoveFailed(String)
    case browserManagerNotAvailable
    case portAlreadyInUse(UInt16)
    case maxRetriesExceeded

    var errorDescription: String? {
        switch self {
        case .extensionNotConnected:
            return "Browser extension is not connected"
        case .serverStartFailed(let error):
            return "Failed to start HTTP server: \(error.localizedDescription)"
        case .serverStopFailed(let error):
            return "Failed to stop HTTP server: \(error.localizedDescription)"
        case .invalidMessageFormat(let message):
            return "Invalid message format: \(message)"
        case .connectionTimeout:
            return "Connection to browser extension timed out"
        case .invalidURL(let url):
            return "Invalid URL format: \(url)"
        case .focusURLAddFailed(let reason):
            return "Failed to add focus URL: \(reason)"
        case .focusURLRemoveFailed(let reason):
            return "Failed to remove focus URL: \(reason)"
        case .browserManagerNotAvailable:
            return "Browser manager is not available"
        case .portAlreadyInUse(let port):
            return "Port \(port) is already in use"
        case .maxRetriesExceeded:
            return "Maximum retry attempts exceeded"
        }
    }

    var failureReason: String? {
        switch self {
        case .extensionNotConnected:
            return "The browser extension has not established a connection with the app"
        case .serverStartFailed(let error):
            return error.localizedDescription
        case .serverStopFailed(let error):
            return error.localizedDescription
        case .invalidMessageFormat(let message):
            return "Message does not match expected format: \(message)"
        case .connectionTimeout:
            return "No response received from browser extension within the timeout period"
        case .invalidURL(let url):
            return "The URL '\(url)' is not in a valid format"
        case .focusURLAddFailed(let reason):
            return reason
        case .focusURLRemoveFailed(let reason):
            return reason
        case .browserManagerNotAvailable:
            return "Browser manager instance is nil or unavailable"
        case .portAlreadyInUse(let port):
            return "Another process is using port \(port)"
        case .maxRetriesExceeded:
            return "The maximum number of retry attempts has been reached"
        }
    }
}


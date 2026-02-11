import os.log
import Foundation

/// Centralized logging system for Auto-Focus app
public struct AppLogger {
    private let logger: Logger
    private let subsystem: String
    private let category: String

    // Shared loggers for different app components
    public static let license = AppLogger(category: "license")
    public static let focus = AppLogger(category: "focus")
    public static let session = AppLogger(category: "session")
    public static let browser = AppLogger(category: "browser")
    public static let network = AppLogger(category: "network")
    public static let ui = AppLogger(category: "ui")
    public static let general = AppLogger(category: "general")
    public static let version = AppLogger(category: "version")

    private init(category: String) {
        self.subsystem = "com.janschill.auto-focus"
        self.category = category
        self.logger = Logger(subsystem: subsystem, category: category)
    }

    // MARK: - Logging Methods

    /// Log informational messages
    public func info(_ message: String, metadata: [String: String] = [:], file: String = #file, function: String = #function, line: Int = #line) {
        let enrichedMessage = formatMessage(message, metadata: metadata, file: file, function: function, line: line)
        logger.info("\(enrichedMessage, privacy: .public)")
    }

    /// Log debug messages (only in debug builds)
    public func debug(_ message: String, metadata: [String: String] = [:], file: String = #file, function: String = #function, line: Int = #line) {
        #if DEBUG
        let enrichedMessage = formatMessage(message, metadata: metadata, file: file, function: function, line: line)
        logger.debug("\(enrichedMessage, privacy: .public)")
        #endif
    }

    /// Log warning messages
    public func warning(_ message: String, metadata: [String: String] = [:], file: String = #file, function: String = #function, line: Int = #line) {
        let enrichedMessage = formatMessage(message, metadata: metadata, file: file, function: function, line: line)
        logger.warning("\(enrichedMessage, privacy: .public)")
    }

    /// Log error messages
    public func error(_ message: String, error: Error? = nil, metadata: [String: String] = [:], file: String = #file, function: String = #function, line: Int = #line) {
        var enrichedMetadata = metadata

        if let error = error {
            enrichedMetadata["error_type"] = String(describing: type(of: error))
            enrichedMetadata["error_description"] = error.localizedDescription

            if let nsError = error as NSError? {
                enrichedMetadata["error_domain"] = nsError.domain
                enrichedMetadata["error_code"] = String(nsError.code)
            }
        }

        let enrichedMessage = formatMessage(message, metadata: enrichedMetadata, file: file, function: function, line: line)
        logger.error("\(enrichedMessage, privacy: .public)")
    }

    /// Log critical system failures
    public func critical(_ message: String, error: Error? = nil, metadata: [String: String] = [:], file: String = #file, function: String = #function, line: Int = #line) {
        var enrichedMetadata = metadata
        enrichedMetadata["severity"] = "CRITICAL"

        if let error = error {
            enrichedMetadata["error_type"] = String(describing: type(of: error))
            enrichedMetadata["error_description"] = error.localizedDescription
        }

        let enrichedMessage = formatMessage(message, metadata: enrichedMetadata, file: file, function: function, line: line)
        logger.critical("\(enrichedMessage, privacy: .public)")
    }

    // MARK: - State Change Logging

    /// Log application state changes
    public func stateChange(from oldState: String, to newState: String, metadata: [String: String] = [:]) {
        var stateMetadata = metadata
        stateMetadata["old_state"] = oldState
        stateMetadata["new_state"] = newState

        let message = "State Change: \(oldState) → \(newState)"
        logger.info("\(formatMessage(message, metadata: stateMetadata), privacy: .public)")
    }

    // MARK: - Private Helper Methods

    private func formatMessage(_ message: String, metadata: [String: String], file: String? = nil, function: String? = nil, line: Int? = nil) -> String {
        var components = [message]

        // Add location info in debug builds
        #if DEBUG
        if let file = file, let function = function, let line = line {
            let filename = URL(fileURLWithPath: file).lastPathComponent
            components.append("[\(filename):\(line) \(function)]")
        }
        #endif

        // Add metadata
        if !metadata.isEmpty {
            let metadataString = metadata
                .sorted(by: { $0.key < $1.key })
                .map { "\($0.key)=\($0.value)" }
                .joined(separator: " ")
            components.append("{\(metadataString)}")
        }

        return components.joined(separator: " ")
    }
}

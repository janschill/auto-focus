import os.log
import Foundation

/// Centralized logging system for Auto-Focus app
/// Provides structured logging optimized for AI analysis and debugging
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
    
    private init(category: String) {
        self.subsystem = "com.janschill.auto-focus"
        self.category = category
        self.logger = Logger(subsystem: subsystem, category: category)
    }
    
    // MARK: - Structured Logging Methods
    
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
    
    // MARK: - Performance Logging
    
    /// Log performance metrics
    public func performance(_ operation: String, duration: TimeInterval, metadata: [String: String] = [:]) {
        var performanceMetadata = metadata
        performanceMetadata["operation"] = operation
        performanceMetadata["duration_ms"] = String(format: "%.2f", duration * 1000)
        performanceMetadata["performance_metric"] = "true"
        
        let message = "Performance: \(operation) completed in \(String(format: "%.2f", duration * 1000))ms"
        logger.info("\(formatMessage(message, metadata: performanceMetadata), privacy: .public)")
    }
    
    /// Measure and log execution time of a block
    public func measure<T>(_ operation: String, metadata: [String: String] = [:], block: () throws -> T) rethrows -> T {
        let startTime = CFAbsoluteTimeGetCurrent()
        let result = try block()
        let duration = CFAbsoluteTimeGetCurrent() - startTime
        
        performance(operation, duration: duration, metadata: metadata)
        return result
    }
    
    /// Measure and log execution time of an async block
    public func measureAsync<T>(_ operation: String, metadata: [String: String] = [:], block: () async throws -> T) async rethrows -> T {
        let startTime = CFAbsoluteTimeGetCurrent()
        let result = try await block()
        let duration = CFAbsoluteTimeGetCurrent() - startTime
        
        performance(operation, duration: duration, metadata: metadata)
        return result
    }
    
    // MARK: - User Action Logging
    
    /// Log user interactions for analytics and debugging
    public func userAction(_ action: String, metadata: [String: String] = [:]) {
        var userMetadata = metadata
        userMetadata["user_action"] = "true"
        userMetadata["action_type"] = action
        userMetadata["timestamp"] = ISO8601DateFormatter().string(from: Date())
        
        let message = "User Action: \(action)"
        logger.info("\(formatMessage(message, metadata: userMetadata), privacy: .public)")
    }
    
    // MARK: - State Change Logging
    
    /// Log application state changes
    public func stateChange(from oldState: String, to newState: String, metadata: [String: String] = [:]) {
        var stateMetadata = metadata
        stateMetadata["state_change"] = "true"
        stateMetadata["old_state"] = oldState
        stateMetadata["new_state"] = newState
        stateMetadata["timestamp"] = ISO8601DateFormatter().string(from: Date())
        
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

// MARK: - Convenience Extensions

extension AppLogger {
    /// Log the start of an operation
    public func operationStarted(_ operation: String, metadata: [String: String] = [:]) {
        var operationMetadata = metadata
        operationMetadata["operation_state"] = "started"
        operationMetadata["operation_id"] = UUID().uuidString
        
        info("Operation started: \(operation)", metadata: operationMetadata)
    }
    
    /// Log the completion of an operation
    public func operationCompleted(_ operation: String, metadata: [String: String] = [:]) {
        var operationMetadata = metadata
        operationMetadata["operation_state"] = "completed"
        
        info("Operation completed: \(operation)", metadata: operationMetadata)
    }
    
    /// Log a failed operation
    public func operationFailed(_ operation: String, error: Error, metadata: [String: String] = [:]) {
        var operationMetadata = metadata
        operationMetadata["operation_state"] = "failed"
        
        self.error("Operation failed: \(operation)", error: error, metadata: operationMetadata)
    }
}

// MARK: - SwiftUI View Logging Extension

#if canImport(SwiftUI)
import SwiftUI

extension View {
    /// Log view lifecycle events
    public func logViewAppearance(_ viewName: String, logger: AppLogger = .ui) -> some View {
        self
            .onAppear {
                logger.info("View appeared: \(viewName)", metadata: ["view_lifecycle": "appeared"])
            }
            .onDisappear {
                logger.info("View disappeared: \(viewName)", metadata: ["view_lifecycle": "disappeared"])
            }
    }
}
#endif
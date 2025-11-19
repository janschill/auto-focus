import Foundation
import os.log
import Darwin

/// File-based logger for debugging extension communication issues
/// Enabled by creating ~/.auto-focus-debug-enable file
class FileLogger {
    static let shared = FileLogger()

    private let logFileURL: URL?
    private let fileHandle: FileHandle?
    private let isEnabled: Bool
    private let queue = DispatchQueue(label: "com.janschill.auto-focus.filelogger", qos: .utility)
    private let dateFormatter: DateFormatter

    private init() {
        // Check if debug logging is enabled
        #if DEBUG
        // In debug builds, enable logging by default
        isEnabled = true
        print("FileLogger: Debug logging enabled by default (DEBUG build)")
        #else
        // In production builds, check for enable file in home directory
        // Get actual home directory (not sandbox container directory)
        let actualHomeDir: String

        // Try HOME environment variable first (works in most cases)
        if let homeDir = ProcessInfo.processInfo.environment["HOME"], !homeDir.contains("/Containers/") {
            actualHomeDir = homeDir
        } else {
            // Fallback: use NSUserName() to get username, then construct path
            let username = NSUserName()
            actualHomeDir = "/Users/\(username)"
        }

        let enableFile = URL(fileURLWithPath: actualHomeDir)
            .appendingPathComponent(".auto-focus-debug-enable")

        let enableFilePath = enableFile.path
        isEnabled = FileManager.default.fileExists(atPath: enableFilePath)

        // Log to console for debugging
        print("FileLogger: Debug logging enabled: \(isEnabled)")
        print("FileLogger: Actual home directory: \(actualHomeDir)")
        print("FileLogger: Enable file path: \(enableFilePath)")
        print("FileLogger: Enable file exists: \(FileManager.default.fileExists(atPath: enableFilePath))")
        #endif

        if isEnabled {
            // Create log file in app support directory
            guard let appSupportURL = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first else {
                print("FileLogger: ERROR - Could not get application support directory")
                logFileURL = nil
                fileHandle = nil
                dateFormatter = DateFormatter()
                dateFormatter.dateFormat = "yyyy-MM-dd HH:mm:ss.SSS"
                return
            }

            let appName = Bundle.main.bundleIdentifier ?? "auto-focus"
            let appSupportDir = appSupportURL.appendingPathComponent(appName, isDirectory: true)

            print("FileLogger: App support directory: \(appSupportDir.path)")

            // Create directory if it doesn't exist
            do {
                try FileManager.default.createDirectory(at: appSupportDir, withIntermediateDirectories: true)
                print("FileLogger: Created/verified app support directory")
            } catch {
                print("FileLogger: ERROR - Failed to create directory: \(error.localizedDescription)")
                logFileURL = nil
                fileHandle = nil
                dateFormatter = DateFormatter()
                dateFormatter.dateFormat = "yyyy-MM-dd HH:mm:ss.SSS"
                return
            }

            // Create log file with date in name
            let dateFormatter = DateFormatter()
            dateFormatter.dateFormat = "yyyy-MM-dd"
            let dateString = dateFormatter.string(from: Date())
            logFileURL = appSupportDir.appendingPathComponent("auto-focus-debug-\(dateString).log")

            print("FileLogger: Log file path: \(logFileURL?.path ?? "nil")")

            // Create file if it doesn't exist
            if let logFileURL = logFileURL {
                if !FileManager.default.fileExists(atPath: logFileURL.path) {
                    let created = FileManager.default.createFile(atPath: logFileURL.path, contents: nil)
                    print("FileLogger: Created log file: \(created)")
                } else {
                    print("FileLogger: Log file already exists")
                }
            }

            // Open file handle for appending
            if let logFileURL = logFileURL {
                do {
                    fileHandle = try FileHandle(forWritingTo: logFileURL)
                    fileHandle?.seekToEndOfFile()
                    print("FileLogger: Successfully opened file handle")
                } catch {
                    print("FileLogger: ERROR - Failed to open file handle: \(error.localizedDescription)")
                    fileHandle = nil
                }
            } else {
                fileHandle = nil
            }

            // Write initial header
            if let fileHandle = fileHandle {
                let header = """
                    \n\n=== Auto-Focus Debug Log Started ===
                    Date: \(ISO8601DateFormatter().string(from: Date()))
                    App Version: \(Bundle.main.infoDictionary?["CFBundleShortVersionString"] ?? "unknown")
                    macOS Version: \(ProcessInfo.processInfo.operatingSystemVersionString)
                    ========================================\n\n
                    """
                if let data = header.data(using: .utf8) {
                    fileHandle.write(data)
                    fileHandle.synchronizeFile()
                    print("FileLogger: Wrote initial header to log file")
                }
            } else {
                print("FileLogger: WARNING - File handle is nil, cannot write logs")
            }
        } else {
            logFileURL = nil
            fileHandle = nil
        }

        // Setup date formatter for log entries
        dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd HH:mm:ss.SSS"
    }

    func log(_ level: String, category: String, message: String, metadata: [String: String] = [:], file: String? = nil, function: String? = nil, line: Int? = nil) {
        guard isEnabled, let fileHandle = fileHandle else { return }

        queue.async {
            var components: [String] = []

            // Timestamp
            components.append("[\(self.dateFormatter.string(from: Date()))]")

            // Level
            components.append("[\(level)]")

            // Category
            components.append("[\(category)]")

            // Location (if available)
            if let file = file, let function = function, let line = line {
                let filename = URL(fileURLWithPath: file).lastPathComponent
                components.append("[\(filename):\(line) \(function)]")
            }

            // Message
            components.append(message)

            // Metadata
            if !metadata.isEmpty {
                let metadataString = metadata
                    .sorted(by: { $0.key < $1.key })
                    .map { "\($0.key)=\($0.value)" }
                    .joined(separator: " ")
                components.append("{\(metadataString)}")
            }

            let logLine = components.joined(separator: " ") + "\n"

            if let data = logLine.data(using: .utf8) {
                fileHandle.write(data)
                fileHandle.synchronizeFile()
            }
        }
    }

    func info(_ message: String, category: String, metadata: [String: String] = [:], file: String = #file, function: String = #function, line: Int = #line) {
        log("INFO", category: category, message: message, metadata: metadata, file: file, function: function, line: line)
    }

    func warning(_ message: String, category: String, metadata: [String: String] = [:], file: String = #file, function: String = #function, line: Int = #line) {
        log("WARN", category: category, message: message, metadata: metadata, file: file, function: function, line: line)
    }

    func error(_ message: String, category: String, error: Error? = nil, metadata: [String: String] = [:], file: String = #file, function: String = #function, line: Int = #line) {
        var errorMetadata = metadata
        if let error = error {
            errorMetadata["error"] = error.localizedDescription
            errorMetadata["error_type"] = String(describing: type(of: error))
        }
        log("ERROR", category: category, message: message, metadata: errorMetadata, file: file, function: function, line: line)
    }

    func debug(_ message: String, category: String, metadata: [String: String] = [:], file: String = #file, function: String = #function, line: Int = #line) {
        log("DEBUG", category: category, message: message, metadata: metadata, file: file, function: function, line: line)
    }

    deinit {
        fileHandle?.closeFile()
    }
}

// Extension to AppLogger to also write to file
extension AppLogger {
    /// Log to both console and file (if enabled)
    func infoToFile(_ message: String, metadata: [String: String] = [:], file: String = #file, function: String = #function, line: Int = #line) {
        info(message, metadata: metadata, file: file, function: function, line: line)
        FileLogger.shared.info(message, category: categoryName, metadata: metadata, file: file, function: function, line: line)
    }

    func warningToFile(_ message: String, metadata: [String: String] = [:], file: String = #file, function: String = #function, line: Int = #line) {
        warning(message, metadata: metadata, file: file, function: function, line: line)
        FileLogger.shared.warning(message, category: categoryName, metadata: metadata, file: file, function: function, line: line)
    }

    func errorToFile(_ message: String, error: Error? = nil, metadata: [String: String] = [:], file: String = #file, function: String = #function, line: Int = #line) {
        self.error(message, error: error, metadata: metadata, file: file, function: function, line: line)
        FileLogger.shared.error(message, category: categoryName, error: error, metadata: metadata, file: file, function: function, line: line)
    }

    func debugToFile(_ message: String, metadata: [String: String] = [:], file: String = #file, function: String = #function, line: Int = #line) {
        debug(message, metadata: metadata, file: file, function: function, line: line)
        FileLogger.shared.debug(message, category: categoryName, metadata: metadata, file: file, function: function, line: line)
    }
}


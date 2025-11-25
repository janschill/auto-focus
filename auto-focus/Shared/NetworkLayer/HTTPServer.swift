import Foundation
import Network

class HTTPServer: ObservableObject {
    private var listener: NWListener?
    private let port: UInt16 = AppConfiguration.serverPort
    private weak var browserManager: BrowserManager?
    private var startupRetryCount = 0
    private let maxStartupRetries = AppConfiguration.maxStartupRetries

    func setBrowserManager(_ manager: BrowserManager) {
        self.browserManager = manager
    }

    func start() {
        do {
            // Clean up any existing listener first
            if listener != nil {
                stop()
            }

            listener = try NWListener(using: .tcp, on: NWEndpoint.Port(rawValue: port)!)
            listener?.stateUpdateHandler = { state in
                switch state {
                case .ready:
                    AppLogger.network.info("Successfully listening on port", metadata: [
                        "port": String(self.port)
                    ])
                    self.startupRetryCount = 0 // Reset retry count on success
                case .failed(let error):
                    let browserError = BrowserError.serverStartFailed(error)
                    AppLogger.network.error("Failed to start HTTP server", error: browserError, metadata: [
                        "port": String(self.port)
                    ])
                    self.handleStartupFailure(browserError)
                case .waiting(let error):
                    AppLogger.network.warning("Waiting to start HTTP server", metadata: [
                        "error": error.localizedDescription,
                        "port": String(self.port)
                    ])
                case .cancelled:
                    AppLogger.network.info("HTTP server cancelled")
                default:
                    AppLogger.network.info("HTTP server state changed", metadata: [
                        "state": String(describing: state)
                    ])
                }
            }

            listener?.newConnectionHandler = { connection in
                self.handleConnection(connection)
            }

            listener?.start(queue: .global())
            AppLogger.network.info("Starting HTTP server", metadata: [
                "port": String(port)
            ])
        } catch {
            let browserError = BrowserError.serverStartFailed(error)
            AppLogger.network.error("Failed to create HTTP server listener", error: browserError, metadata: [
                "port": String(port)
            ])
            handleStartupFailure(browserError)
        }
    }

    private func handleStartupFailure(_ error: BrowserError) {
        startupRetryCount += 1

        if startupRetryCount <= maxStartupRetries {
            let delay = Double(startupRetryCount) * 2.0 // 2, 4, 6 second delays
            AppLogger.network.warning("Retrying HTTP server startup", metadata: [
                "delay": String(format: "%.1f", delay),
                "attempt": String(startupRetryCount),
                "max_attempts": String(maxStartupRetries),
                "error": error.localizedDescription
            ])

            DispatchQueue.global().asyncAfter(deadline: .now() + delay) {
                self.start()
            }
        } else {
            let maxRetriesError = BrowserError.maxRetriesExceeded
            AppLogger.network.critical("Max startup retries exceeded - HTTP server failed to start", error: maxRetriesError, metadata: [
                "max_retries": String(maxStartupRetries)
            ])
            startupRetryCount = 0 // Reset for potential future attempts
        }
    }

    func stop() {
        listener?.cancel()
        listener = nil
    }

    private func handleConnection(_ connection: NWConnection) {
        connection.start(queue: .global())

        connection.receive(minimumIncompleteLength: 1, maximumLength: 4096) { data, _, isComplete, _ in
            if let data = data, !data.isEmpty {
                self.handleRequest(data, connection: connection)
            }

            if isComplete {
                connection.cancel()
            }
        }
    }

    private func handleRequest(_ data: Data, connection: NWConnection) {
        guard let requestString = String(data: data, encoding: .utf8) else {
            sendResponse("HTTP/1.1 400 Bad Request\r\n\r\n", to: connection)
            return
        }

        // Parse HTTP request
        let lines = requestString.components(separatedBy: "\r\n")
        guard let firstLine = lines.first else {
            sendResponse("HTTP/1.1 400 Bad Request\r\n\r\n", to: connection)
            return
        }

        let parts = firstLine.components(separatedBy: " ")
        guard parts.count >= 3, parts[0] == "POST", parts[1] == "/browser" else {
            sendResponse("HTTP/1.1 404 Not Found\r\n\r\n", to: connection)
            return
        }

        // Find JSON body
        if let bodyStart = requestString.range(of: "\r\n\r\n") {
            let jsonString = String(requestString[bodyStart.upperBound...])
            handleBrowserMessage(jsonString, connection: connection)
        } else {
            sendResponse("HTTP/1.1 400 Bad Request\r\n\r\n", to: connection)
        }
    }

    private func handleBrowserMessage(_ jsonString: String, connection: NWConnection) {
        guard let jsonData = jsonString.data(using: .utf8),
              let message = try? JSONSerialization.jsonObject(with: jsonData) as? [String: Any],
              let command = message["command"] as? String else {
            sendResponse("HTTP/1.1 400 Bad Request\r\n\r\n", to: connection)
            return
        }

        AppLogger.network.infoToFile("Received command from browser extension", metadata: [
            "command": command,
            "timestamp": ISO8601DateFormatter().string(from: Date())
        ])

        switch command {
        case "handshake":
            handleHandshakeMessage(message, connection: connection)

        case "heartbeat":
            handleHeartbeatMessage(message, connection: connection)

        case "browser_lost_focus":
            handleBrowserLostFocus(message, connection: connection)

        case "tab_changed":
            handleTabChanged(message, connection: connection)

        case "add_focus_url":
            handleAddFocusURL(message, connection: connection)

        case "connection_test":
            handleConnectionTest(message, connection: connection)

        default:
            sendResponse("HTTP/1.1 400 Bad Request\r\n\r\n", to: connection)
        }
    }

    private func handleBrowserLostFocus(_ message: [String: Any], connection: NWConnection) {
        AppLogger.network.info("Browser lost focus")

        // Immediately notify browser manager that browser is no longer in focus
        DispatchQueue.main.async {
            // Create a dummy tab info indicating no focus
            let tabInfo = BrowserTabInfo(
                url: "about:blank",
                title: "Browser Lost Focus",
                isFocusURL: false,
                matchedFocusURL: nil
            )
            self.browserManager?.updateFromExtension(tabInfo: tabInfo, isFocus: false)
        }

        let response = [
            "command": "browser_lost_focus_response",
            "status": "ok"
        ] as [String: Any]
        sendJSONResponse(response, to: connection)
    }

    private func handleTabChanged(_ message: [String: Any], connection: NWConnection) {
        guard let url = message["url"] as? String else {
            AppLogger.network.errorToFile("Tab changed message missing URL", metadata: [
                "message_keys": Array(message.keys).joined(separator: ",")
            ])
            sendResponse("HTTP/1.1 400 Bad Request\r\n\r\n", to: connection)
            return
        }

        let forcedByFocus = message["forcedByFocus"] as? Bool ?? false
        // Support both old and new field names for backward compatibility
        let isBrowserFocused = message["isBrowserFocused"] as? Bool ??
                              message["isChromeFocused"] as? Bool ?? true // Default to true for backward compatibility
        AppLogger.network.infoToFile("Tab changed", metadata: [
            "url": url,
            "forced_by_focus": String(forcedByFocus),
            "browser_focused": String(isBrowserFocused),
            "timestamp": ISO8601DateFormatter().string(from: Date())
        ])

        // Check if URL is a focus URL using BrowserManager
        let (isFocus, matchedURL) = browserManager?.checkIfURLIsFocus(url) ?? (false, nil)
        AppLogger.network.info("URL check result", metadata: [
            "url": url,
            "is_focus": String(isFocus),
            "matched_url": matchedURL?.name ?? "none"
        ])

        // Only activate focus mode if browser is actually focused
        // This prevents false positives when browser is in the background
        let effectiveIsFocus = isFocus && isBrowserFocused

        if isFocus && !isBrowserFocused {
            AppLogger.network.info("Focus URL detected but browser is not frontmost - suppressing focus activation", metadata: [
                "url": url
            ])
        }

        // Update browser manager state
        let tabInfo = BrowserTabInfo(
            url: url,
            title: message["title"] as? String ?? "",
            isFocusURL: effectiveIsFocus,
            matchedFocusURL: matchedURL
        )

        // Process update on main queue
        DispatchQueue.main.async {
            self.browserManager?.updateFromExtension(tabInfo: tabInfo, isFocus: effectiveIsFocus)
        }

        let response = [
            "command": "focus_state_changed",
            "isFocusActive": effectiveIsFocus
        ] as [String: Any]

        sendJSONResponse(response, to: connection)
    }

    private func handleAddFocusURL(_ message: [String: Any], connection: NWConnection) {
        guard let domain = message["domain"] as? String,
              let name = message["name"] as? String else {
            sendResponse("HTTP/1.1 400 Bad Request\r\n\r\n", to: connection)
            return
        }

        let currentUrl = message["url"] as? String
        AppLogger.network.info("Adding focus URL", metadata: [
            "domain": domain,
            "name": name,
            "current_url": currentUrl ?? "unknown"
        ])

        // Create new FocusURL
        let newURL = FocusURL(
            name: name,
            domain: domain.lowercased(),
            matchType: .domain,
            category: .work,
            isPremium: false
        )

        // Add URL through BrowserManager
        DispatchQueue.main.async {
            if let browserManager = self.browserManager {
                browserManager.addFocusURLWithoutImmediateActivation(newURL)
                AppLogger.network.info("Successfully added focus URL with suppressed activation", metadata: [
                    "domain": domain
                ])

                let response = [
                    "command": "add_focus_url_response",
                    "success": true,
                    "message": "Added \(domain) as focus URL"
                ] as [String: Any]

                self.sendJSONResponse(response, to: connection)
            } else {
                let error = BrowserError.browserManagerNotAvailable
                AppLogger.network.error("Failed to add focus URL - no browser manager", error: error, metadata: [
                    "domain": domain
                ])

                let response = [
                    "command": "add_focus_url_response",
                    "success": false,
                    "error": error.localizedDescription
                ] as [String: Any]

                self.sendJSONResponse(response, to: connection)
            }
        }
        return // Early return since we handle response in async block
    }

    private func sendJSONResponse(_ object: [String: Any], to connection: NWConnection) {
        do {
            let jsonData = try JSONSerialization.data(withJSONObject: object)
            let jsonString = String(data: jsonData, encoding: .utf8) ?? "{}"

            let response = """
                HTTP/1.1 200 OK\r
                Content-Type: application/json\r
                Access-Control-Allow-Origin: *\r
                Access-Control-Allow-Methods: POST\r
                Access-Control-Allow-Headers: Content-Type\r
                Content-Length: \(jsonString.utf8.count)\r
                \r
                \(jsonString)
                """

            sendResponse(response, to: connection)
        } catch {
            sendResponse("HTTP/1.1 500 Internal Server Error\r\n\r\n", to: connection)
        }
    }

    private func sendResponse(_ response: String, to connection: NWConnection) {
        let data = response.data(using: .utf8)!
        connection.send(content: data, completion: .contentProcessed { error in
            if let error = error {
                AppLogger.network.errorToFile("Failed to send HTTP response", error: error, metadata: [
                    "response_length": String(data.count)
                ])
            }
            connection.cancel()
        })
    }

    // MARK: - Message Handlers

    private func handleHandshakeMessage(_ message: [String: Any], connection: NWConnection) {
        let extensionVersion = message["version"] as? String ?? "unknown"
        let extensionId = message["extensionId"] as? String ?? "unknown"

        AppLogger.network.infoToFile("Handshake from browser extension", metadata: [
            "version": extensionVersion,
            "extension_id": extensionId,
            "timestamp": ISO8601DateFormatter().string(from: Date())
        ])

        // Parse extension health data
        if let healthData = message["healthData"] as? [String: Any] {
            updateExtensionHealth(healthData, version: extensionVersion, extensionId: extensionId)
        }

        // Reset connection timeout timer and mark as connected when handshake is received
        DispatchQueue.main.async {
            self.browserManager?.resetConnectionTimeoutTimer()

            // Ensure connection state is marked as connected
            if let browserManager = self.browserManager, !browserManager.isExtensionConnected {
                AppLogger.network.info("Extension connection established via handshake", metadata: [
                    "extension_id": extensionId,
                    "timestamp": ISO8601DateFormatter().string(from: Date())
                ])
                browserManager.isExtensionConnected = true
                browserManager.delegate?.browserManager(browserManager, didChangeConnectionState: true)
            }
        }

        let response = [
            "command": "handshake_response",
            "status": "connected",
            "version": "1.0.0",
            "appVersion": Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0.0",
            "timestamp": Date().timeIntervalSince1970,
            "recommendations": generateRecommendations()
        ] as [String: Any]

        sendJSONResponse(response, to: connection)
    }

    private func handleHeartbeatMessage(_ message: [String: Any], connection: NWConnection) {
        // Update connection quality based on heartbeat data
        if let connectionHealth = message["connectionHealth"] as? [String: Any] {
            updateConnectionQuality(connectionHealth)
        }

        // Reset connection timeout timer when heartbeat is received
        // This prevents the connection from being marked as disconnected when only heartbeats are received
        DispatchQueue.main.async {
            self.browserManager?.resetConnectionTimeoutTimer()

            // Also ensure connection state is marked as connected if we're receiving heartbeats
            if let browserManager = self.browserManager, !browserManager.isExtensionConnected {
                AppLogger.network.info("Extension connection restored via heartbeat", metadata: [
                    "timestamp": ISO8601DateFormatter().string(from: Date())
                ])
                browserManager.isExtensionConnected = true
                browserManager.delegate?.browserManager(browserManager, didChangeConnectionState: true)
            }
        }

        let response = [
            "command": "heartbeat_response",
            "status": "ok",
            "timestamp": Date().timeIntervalSince1970,
            "connectionQuality": browserManager?.connectionQuality.rawValue ?? "unknown"
        ] as [String: Any]

        sendJSONResponse(response, to: connection)
    }

    private func updateExtensionHealth(_ healthData: [String: Any], version: String, extensionId: String) {
        DispatchQueue.main.async {
            let errors = (healthData["errors"] as? [[String: Any]] ?? []).compactMap { errorDict -> ExtensionError? in
                guard let type = errorDict["type"] as? String,
                      let message = errorDict["message"] as? String,
                      let timestamp = errorDict["timestamp"] as? Double else {
                    return nil
                }
                return ExtensionError(
                    type: type,
                    message: message,
                    timestamp: Date(timeIntervalSince1970: timestamp / 1000),
                    stack: errorDict["stack"] as? String
                )
            }

            let consecutiveFailures = healthData["consecutiveFailures"] as? Int ?? 0

            self.browserManager?.extensionHealth = ExtensionHealth(
                version: version,
                installationDate: nil, // Will be updated from extension storage
                lastUpdateCheck: Date(),
                errors: errors,
                consecutiveFailures: consecutiveFailures
            )

            // Update connection quality based on health
            if consecutiveFailures == 0 {
                self.browserManager?.connectionQuality = .excellent
            } else if consecutiveFailures < 3 {
                self.browserManager?.connectionQuality = .good
            } else if consecutiveFailures < 10 {
                self.browserManager?.connectionQuality = .fair
            } else {
                self.browserManager?.connectionQuality = .poor
            }

            AppLogger.network.info("Updated extension health", metadata: [
                "version": version,
                "error_count": String(errors.count),
                "consecutive_failures": String(consecutiveFailures)
            ])
        }
    }

    private func updateConnectionQuality(_ connectionHealth: [String: Any]) {
        DispatchQueue.main.async {
            let state = connectionHealth["state"] as? String ?? "unknown"
            let consecutiveFailures = connectionHealth["consecutiveFailures"] as? Int ?? 0

            let quality: ConnectionQuality
            switch state {
            case "connected":
                if consecutiveFailures == 0 {
                    quality = .excellent
                } else if consecutiveFailures < 2 {
                    quality = .good
                } else {
                    quality = .fair
                }
            case "connecting", "degraded":
                quality = .fair
            case "error", "lost":
                quality = .poor
            case "disconnected", "permanently_failed":
                quality = .disconnected
            default:
                quality = .unknown
            }

            self.browserManager?.connectionQuality = quality
        }
    }

    private func generateRecommendations() -> [String] {
        var recommendations: [String] = []

        if let health = browserManager?.extensionHealth {
            if health.consecutiveFailures > 5 {
                recommendations.append("Consider restarting your browser to improve connection stability")
            }

            if health.errors.count > 10 {
                recommendations.append("Extension has encountered multiple errors - check browser console")
            }
        }

        if browserManager?.connectionQuality == .poor {
            recommendations.append("Connection quality is poor - ensure Auto-Focus app is running")
        }

        return recommendations
    }

    private func handleConnectionTest(_ message: [String: Any], connection: NWConnection) {
        let extensionId = message["extensionId"] as? String ?? "unknown"
        let testData = message["testData"] as? String ?? ""

        AppLogger.network.info("Connection test from browser extension", metadata: [
            "extension_id": extensionId,
            "test_data": testData
        ])

        let response = [
            "command": "connection_test_response",
            "status": "ok",
            "timestamp": Date().timeIntervalSince1970,
            "testData": testData,
            "serverStatus": "healthy"
        ] as [String: Any]

        sendJSONResponse(response, to: connection)
    }
}

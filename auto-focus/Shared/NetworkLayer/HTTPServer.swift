import Foundation
import Network

class HTTPServer: ObservableObject {
    private var listener: NWListener?
    private let port: UInt16 = 8942
    private weak var browserManager: BrowserManager?
    private var startupRetryCount = 0
    private let maxStartupRetries = 3

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
                    print("HTTPServer: ✅ Successfully listening on port \(self.port)")
                    self.startupRetryCount = 0 // Reset retry count on success
                case .failed(let error):
                    print("HTTPServer: ❌ Failed to start - \(error.localizedDescription)")
                    self.handleStartupFailure(error)
                case .waiting(let error):
                    print("HTTPServer: ⏳ Waiting to start - \(error.localizedDescription)")
                case .cancelled:
                    print("HTTPServer: Server cancelled")
                default:
                    print("HTTPServer: State changed to \(state)")
                }
            }

            listener?.newConnectionHandler = { connection in
                self.handleConnection(connection)
            }

            listener?.start(queue: .global())
            print("HTTPServer: Starting server on port \(port)...")
        } catch {
            print("HTTPServer: ❌ Failed to create listener - \(error.localizedDescription)")
            handleStartupFailure(error)
        }
    }

    private func handleStartupFailure(_ error: Error) {
        startupRetryCount += 1

        if startupRetryCount <= maxStartupRetries {
            let delay = Double(startupRetryCount) * 2.0 // 2, 4, 6 second delays
            print("HTTPServer: Retrying startup in \(delay) seconds (attempt \(startupRetryCount)/\(maxStartupRetries))")

            DispatchQueue.global().asyncAfter(deadline: .now() + delay) {
                self.start()
            }
        } else {
            print("HTTPServer: ❌ Max startup retries (\(maxStartupRetries)) exceeded. Server failed to start.")
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

        print("HTTPServer: Received command: \(command)")

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
        print("HTTPServer: Browser lost focus")

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
            sendResponse("HTTP/1.1 400 Bad Request\r\n\r\n", to: connection)
            return
        }

        let forcedByFocus = message["forcedByFocus"] as? Bool ?? false
        let isChromeFocused = message["isChromeFocused"] as? Bool ?? true // Default to true for backward compatibility
        print("HTTPServer: Tab changed to \(url)\(forcedByFocus ? " (due to Chrome focus)" : "") - Chrome focused: \(isChromeFocused)")

        // Check if URL is a focus URL using BrowserManager
        let (isFocus, matchedURL) = browserManager?.checkIfURLIsFocus(url) ?? (false, nil)
        print("HTTPServer: URL check result - isFocus: \(isFocus), matched: \(matchedURL?.name ?? "none")")

        // Only activate focus mode if Chrome is actually focused
        // This prevents false positives when Chrome is in the background
        let effectiveIsFocus = isFocus && isChromeFocused

        if isFocus && !isChromeFocused {
            print("HTTPServer: Focus URL detected but Chrome is not frontmost - suppressing focus activation")
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
        print("HTTPServer: Adding focus URL - domain: \(domain), name: \(name), current URL: \(currentUrl ?? "unknown")")

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
                print("HTTPServer: Successfully added focus URL: \(domain) (with suppressed activation)")

                let response = [
                    "command": "add_focus_url_response",
                    "success": true,
                    "message": "Added \(domain) as focus URL"
                ] as [String: Any]

                self.sendJSONResponse(response, to: connection)
            } else {
                print("HTTPServer: Failed to add focus URL - no browser manager")

                let response = [
                    "command": "add_focus_url_response",
                    "success": false,
                    "error": "Browser manager not available"
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
                print("HTTPServer: Send error - \(error)")
            }
            connection.cancel()
        })
    }

    // MARK: - Message Handlers

    private func handleHandshakeMessage(_ message: [String: Any], connection: NWConnection) {
        let extensionVersion = message["version"] as? String ?? "unknown"
        let extensionId = message["extensionId"] as? String ?? "unknown"

        print("HTTPServer: Handshake from extension v\(extensionVersion) (ID: \(extensionId))")

        // Parse extension health data
        if let healthData = message["healthData"] as? [String: Any] {
            updateExtensionHealth(healthData, version: extensionVersion, extensionId: extensionId)
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

            print("HTTPServer: Updated extension health - version: \(version), errors: \(errors.count), failures: \(consecutiveFailures)")
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

        print("HTTPServer: Connection test from extension \(extensionId) with data: \(testData)")

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

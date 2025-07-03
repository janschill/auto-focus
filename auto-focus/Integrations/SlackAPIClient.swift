import Foundation

class SlackAPIClient {
    private let workspace: SlackWorkspace
    private let urlSession: URLSession
    
    init(workspace: SlackWorkspace, urlSession: URLSession = .shared) {
        self.workspace = workspace
        self.urlSession = urlSession
    }
    
    // MARK: - Status Management
    
    func setStatus(text: String, emoji: String, expiration: Date? = nil) async throws {
        let profile: [String: Any] = [
            "status_text": text,
            "status_emoji": emoji,
            "status_expiration": expiration?.timeIntervalSince1970 ?? 0
        ]
        
        let requestBody = [
            "profile": profile
        ]
        
        try await makeAPIRequest(
            url: SlackAppConfig.profileSetURL,
            method: "POST",
            body: requestBody
        )
    }
    
    func clearStatus() async throws {
        let profile: [String: Any] = [
            "status_text": "",
            "status_emoji": "",
            "status_expiration": 0
        ]
        
        let requestBody = [
            "profile": profile
        ]
        
        try await makeAPIRequest(
            url: SlackAppConfig.profileSetURL,
            method: "POST",
            body: requestBody
        )
    }
    
    // MARK: - Do Not Disturb Management
    
    func enableDND(durationMinutes: Int) async throws {
        let requestBody = [
            "num_minutes": durationMinutes
        ]
        
        try await makeAPIRequest(
            url: SlackAppConfig.dndSetSnoozeURL,
            method: "POST",
            body: requestBody
        )
    }
    
    func disableDND() async throws {
        try await makeAPIRequest(
            url: SlackAppConfig.dndEndSnoozeURL,
            method: "POST",
            body: [:]
        )
    }
    
    // MARK: - Profile Information
    
    func getUserProfile() async throws -> SlackProfile {
        let response: SlackProfileResponse = try await makeAPIRequest(
            url: SlackAppConfig.profileGetURL,
            method: "GET",
            body: nil
        )
        
        guard response.ok, let profile = response.profile else {
            throw SlackIntegrationError.apiError(SlackAPIError(
                ok: false,
                error: response.error ?? "Unknown error",
                detail: nil
            ))
        }
        
        return profile
    }
    
    // MARK: - Generic API Request
    
    private func makeAPIRequest<T: Codable>(
        url: String,
        method: String,
        body: [String: Any]?
    ) async throws -> T {
        guard let requestURL = URL(string: url) else {
            throw SlackIntegrationError.invalidResponse
        }
        
        var request = URLRequest(url: requestURL)
        request.httpMethod = method
        request.setValue("Bearer \(workspace.accessToken)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        if let body = body {
            do {
                request.httpBody = try JSONSerialization.data(withJSONObject: body)
            } catch {
                throw SlackIntegrationError.networkError(error)
            }
        }
        
        do {
            let (data, response) = try await urlSession.data(for: request)
            
            // Check HTTP status code
            if let httpResponse = response as? HTTPURLResponse {
                switch httpResponse.statusCode {
                case 200...299:
                    break
                case 429:
                    throw SlackIntegrationError.rateLimitExceeded
                case 401:
                    throw SlackIntegrationError.tokenExpired(workspace.id)
                default:
                    throw SlackIntegrationError.apiError(SlackAPIError(
                        ok: false,
                        error: "HTTP \(httpResponse.statusCode)",
                        detail: nil
                    ))
                }
            }
            
            // For void responses (like DND end), return empty success
            if T.self == VoidResponse.self {
                return VoidResponse() as! T
            }
            
            // Parse JSON response
            let decoder = JSONDecoder()
            return try decoder.decode(T.self, from: data)
            
        } catch {
            if error is SlackIntegrationError {
                throw error
            }
            throw SlackIntegrationError.networkError(error)
        }
    }
}

// MARK: - Helper Types

private struct VoidResponse: Codable {
    init() {}
}

// MARK: - Rate Limiting Helper

class SlackRateLimiter {
    private var requestTimes: [Date] = []
    private let maxRequests: Int
    private let timeWindow: TimeInterval
    private let queue = DispatchQueue(label: "slack.rate.limiter")
    
    init(maxRequests: Int = SlackAppConfig.maxRequestsPerMinute, timeWindow: TimeInterval = 60) {
        self.maxRequests = maxRequests
        self.timeWindow = timeWindow
    }
    
    func canMakeRequest() -> Bool {
        return queue.sync {
            cleanOldRequests()
            return requestTimes.count < maxRequests
        }
    }
    
    func recordRequest() {
        queue.sync {
            requestTimes.append(Date())
            cleanOldRequests()
        }
    }
    
    private func cleanOldRequests() {
        let cutoff = Date().addingTimeInterval(-timeWindow)
        requestTimes = requestTimes.filter { $0 > cutoff }
    }
    
    func timeUntilNextRequest() -> TimeInterval {
        return queue.sync {
            cleanOldRequests()
            if requestTimes.count < maxRequests {
                return 0
            }
            
            guard let oldestRequest = requestTimes.first else {
                return 0
            }
            
            let nextAvailable = oldestRequest.addingTimeInterval(timeWindow)
            return max(0, nextAvailable.timeIntervalSinceNow)
        }
    }
}
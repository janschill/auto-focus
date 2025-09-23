import Foundation
import SwiftUI

class VersionCheckManager: ObservableObject {
    @Published var isUpdateAvailable: Bool = false
    @Published var latestVersion: String = ""
    @Published var currentVersion: String = ""
    @Published var isChecking: Bool = false
    @Published var lastCheckDate: Date?
    
    private let checkInterval: TimeInterval = 24 * 60 * 60 // 24 hours
    private let githubAPIURL = "https://api.github.com/repos/janschill/auto-focus/releases/latest"
    private let userDefaults = UserDefaults.standard
    private let lastCheckKey = "AutoFocus_LastVersionCheck"
    private let lastVersionKey = "AutoFocus_LastKnownVersion"
    private let updateAvailableKey = "AutoFocus_UpdateAvailable"
    
    init() {
        currentVersion = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0.0"
        loadPersistedData()
        
        // Check for updates on initialization if enough time has passed
        if shouldCheckForUpdates() {
            checkForUpdates()
        }
    }
    
    private func loadPersistedData() {
        lastCheckDate = userDefaults.object(forKey: lastCheckKey) as? Date
        latestVersion = userDefaults.string(forKey: lastVersionKey) ?? ""
        isUpdateAvailable = userDefaults.bool(forKey: updateAvailableKey)
    }
    
    private func persistData() {
        userDefaults.set(lastCheckDate, forKey: lastCheckKey)
        userDefaults.set(latestVersion, forKey: lastVersionKey)
        userDefaults.set(isUpdateAvailable, forKey: updateAvailableKey)
    }
    
    func checkForUpdates() {
        guard !isChecking else { return }
        
        isChecking = true
        
        guard let url = URL(string: githubAPIURL) else {
            isChecking = false
            return
        }
        
        URLSession.shared.dataTask(with: url) { [weak self] data, response, error in
            DispatchQueue.main.async {
                self?.isChecking = false
                
                guard let data = data,
                      error == nil,
                      let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                      let tagName = json["tag_name"] as? String else {
                    // If check fails, don't update the UI but log the attempt
                    self?.lastCheckDate = Date()
                    self?.persistData()
                    return
                }
                
                self?.latestVersion = tagName.replacingOccurrences(of: "v", with: "")
                self?.lastCheckDate = Date()
                self?.isUpdateAvailable = self?.isVersionNewer(self?.latestVersion ?? "", than: self?.currentVersion ?? "") ?? false
                self?.persistData()
            }
        }.resume()
    }
    
    private func shouldCheckForUpdates() -> Bool {
        guard let lastCheck = lastCheckDate else { return true }
        return Date().timeIntervalSince(lastCheck) > checkInterval
    }
    
    private func isVersionNewer(_ new: String, than current: String) -> Bool {
        let newComponents = new.split(separator: ".").compactMap { Int($0) }
        let currentComponents = current.split(separator: ".").compactMap { Int($0) }
        
        let maxLength = max(newComponents.count, currentComponents.count)
        
        for i in 0..<maxLength {
            let newValue = i < newComponents.count ? newComponents[i] : 0
            let currentValue = i < currentComponents.count ? currentComponents[i] : 0
            
            if newValue > currentValue {
                return true
            } else if newValue < currentValue {
                return false
            }
        }
        
        return false
    }
    
    func openDownloadPage() {
        if let url = URL(string: "https://auto-focus.app") {
            NSWorkspace.shared.open(url)
        }
    }
}
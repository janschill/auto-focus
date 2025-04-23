//
//  FocusManager.swift
//  auto-focus
//
//  Created by Jan Schill on 25/01/2025.
//

import Foundation
import AppKit

struct AppInfo: Identifiable, Codable, Hashable {
    var id: String
    var name: String
    var bundleIdentifier: String
    
    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
    
    static func == (lhs: AppInfo, rhs: AppInfo) -> Bool {
        return lhs.id == rhs.id
    }
}

class FocusManager: ObservableObject {
    @Published var timeSpent: TimeInterval = 0
    @Published var isFocusAppActive = false
    @Published var isNotificationsEnabled: Bool = true
    @Published var isPaused: Bool = false {
        didSet {
            UserDefaults.standard.set(isPaused, forKey: "isPaused")
        }
    }
    @Published var focusApps: [AppInfo] = [] {
        didSet {
            if let encoded = try? JSONEncoder().encode(focusApps) {
                UserDefaults.standard.set(encoded, forKey: "focusApps")
            }
        }
    }
    @Published var focusThreshold: TimeInterval = 12 {
        didSet {
            UserDefaults.standard.set(focusThreshold, forKey: "focusThreshold")
        }
    }
    @Published var focusLossBuffer: TimeInterval = 2 {
        didSet {
            UserDefaults.standard.set(focusLossBuffer, forKey: "focusLossBuffer")
        }
    }
    @Published var selectedAppId: String? = nil
    @Published var focusSessions: [FocusSession] = [] {
        didSet {
            saveSessions()
        }
    }
    @Published var isInFocusMode = false
    @Published private(set) var bufferTimeRemaining: TimeInterval = 0
    @Published private(set) var isInBufferPeriod = false
    
    private var freeAppLimit: Int = 2
    @Published var isPremiumUser: Bool = true
    
    private var focusLossTimer: Timer?
    private var remainingBufferTime: TimeInterval = 0
    private var timer: Timer?
    private let checkInterval: TimeInterval = 1.0
    
    private var currentSessionStartTime: Date?
    var todaysSessions: [FocusSession] {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        
        return focusSessions.filter { session in
            calendar.startOfDay(for: session.startTime) == today
        }
    }
    
    var weekSessions: [FocusSession] {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        guard let oneWeekAgo = calendar.date(byAdding: .day, value: -7, to: today) else {
            return []
        }
        
        return focusSessions.filter { session in
            session.startTime >= oneWeekAgo
        }
    }
    
    var monthSessions: [FocusSession] {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        guard let oneMonthAgo = calendar.date(byAdding: .month, value: -1, to: today) else {
            return []
        }
        
        return focusSessions.filter { session in
            session.startTime >= oneMonthAgo
        }
    }
    
    var canAddMoreApps: Bool {
        return isPremiumUser || focusApps.count < freeAppLimit
    }
    
    var isPremiumRequired: Bool {
        return !isPremiumUser && focusApps.count >= freeAppLimit
    }
    
    init() {
        loadFocusApps()
        loadSessions()
        focusLossBuffer = UserDefaults.standard.double(forKey: "focusLossBuffer")
        if focusLossBuffer == 0 { focusLossBuffer = 2 }
        isPaused = UserDefaults.standard.bool(forKey: "isPaused")
        startMonitoring()
    }
    
    func togglePause() {
        isPaused = !isPaused
        if isPaused {
            if isFocusAppActive {
                saveFocusSession()
                resetFocusState()
                if !isNotificationsEnabled {
                    setFocusMode(enabled: false)
                }
            }
        }
    }
    
    private func saveSessions() {
        if let encoded = try? JSONEncoder().encode(focusSessions) {
            UserDefaults.standard.set(encoded, forKey: "focusSessions")
        }
    }
    
    private func loadSessions() {
        if let data = UserDefaults.standard.data(forKey: "focusSessions"),
           let decoded = try? JSONDecoder().decode([FocusSession].self, from: data) {
            focusSessions = decoded
        }
    }
    
    func removeSelectedApp() {
        if let selectedId = selectedAppId {
            focusApps.removeAll { $0.id == selectedId }
            selectedAppId = nil
        }
    }
    
    private func loadFocusApps() {
        if let data = UserDefaults.standard.data(forKey: "focusApps"),
           let apps = try? JSONDecoder().decode([AppInfo].self, from: data) {
            focusApps = apps
        }
    }
    
    private func startMonitoring() {
        timer = Timer.scheduledTimer(withTimeInterval: checkInterval, repeats: true) { [weak self] _ in
            self?.checkActiveApp()
        }
    }
    
    private func checkActiveApp() {
        if isPaused {
            return
        }
        
        guard let workspace = NSWorkspace.shared.frontmostApplication else { return }
        let currentApp = workspace.bundleIdentifier
        let isFocusAppInFront = focusApps.contains { $0.bundleIdentifier == currentApp }
        
        if isFocusAppInFront {
            handleFocusAppInFront()
        } else if isFocusAppActive {
            handleNonFocusAppInFront()
        }
    }
    
    private func handleFocusAppInFront() {
        focusLossTimer?.invalidate()
        focusLossTimer = nil
        
        if !isFocusAppActive {
            startFocusSession()
        } else {
            updateFocusSession()
        }
    }
    
    private func startFocusSession() {
        isFocusAppActive = true
        timeSpent = 0
        currentSessionStartTime = Date()
    }
    
    private func updateFocusSession() {
        timeSpent += checkInterval
        if shouldEnterFocusMode {
            print("activating focus mode")
            isInFocusMode = true
            setFocusMode(enabled: true)
        }
    }
    
    private var shouldEnterFocusMode: Bool {
        var multiplier: Double = 60
        #if DEBUG
            multiplier = 1
        #endif
        
        return isNotificationsEnabled && timeSpent >= (focusThreshold * multiplier) && !isInFocusMode
    }
    
    private func handleNonFocusAppInFront() {
        
        if focusLossTimer != nil {
            return
        }
        
        if isInFocusMode {
            startBufferTimer()
        } else {
            resetFocusState()

            if !isNotificationsEnabled {
                setFocusMode(enabled: false)
            }
        }
        
    }
    
    private func startBufferTimer() {
        isInBufferPeriod = true
        remainingBufferTime = focusLossBuffer
        bufferTimeRemaining = remainingBufferTime
        focusLossTimer?.invalidate()
        
        focusLossTimer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] timer in
            guard let self = self else {
                timer.invalidate()
                return
            }
            
            self.remainingBufferTime -= 1
            self.bufferTimeRemaining = self.remainingBufferTime
            
            if self.remainingBufferTime <= 0 {
                self.saveFocusSession()
                self.resetFocusState()
                if !self.isNotificationsEnabled {
                    self.setFocusMode(enabled: false)
                }
                timer.invalidate()
                self.focusLossTimer = nil
                self.isInBufferPeriod = false
            }
        }
        
        RunLoop.current.add(focusLossTimer!, forMode: .common)
    }
    
    private func saveFocusSession() {
        guard let startTime = currentSessionStartTime else { return }
        let session = FocusSession(startTime: startTime, endTime: Date())
        focusSessions.append(session)
        
         print("appending session: \(session)")
    }
    
    private func resetFocusState() {
        isFocusAppActive = false
        timeSpent = 0
        isInFocusMode = false
        currentSessionStartTime = nil
        focusLossTimer?.invalidate()
        focusLossTimer = nil
        isInBufferPeriod = false
        bufferTimeRemaining = 0
    }
    
    
    private func setFocusMode(enabled: Bool) {
        let toggleScript = """
        tell application "System Events"
            tell application "Shortcuts Events"
                run shortcut "Toggle Do Not Disturb" without activating
            end tell
        end tell
        """
        
        var error: NSDictionary?
        if let scriptObject = NSAppleScript(source: toggleScript) {
            scriptObject.executeAndReturnError(&error)
            if error == nil {
                self.isNotificationsEnabled = !enabled
            } else {
                print("AppleScript error: \(String(describing: error))")
            }
        }
    }
    
    func checkShortcutExists() -> Bool {
        let shortcutsApp = NSWorkspace.shared.urlForApplication(withBundleIdentifier: "com.apple.shortcuts")
        guard shortcutsApp != nil else { return false }
        
        // Use Shortcuts API to check if shortcut exists
        let script = """
        tell application "Shortcuts"
            exists shortcut "Toggle Do Not Disturb"
        end tell
        """
        
        if let scriptObject = NSAppleScript(source: script) {
            var error: NSDictionary?
            if let result = Optional(scriptObject.executeAndReturnError(&error)) {
                return result.booleanValue
            }
        }
        return false
    }
    
    func selectFocusApplication() {
        if !canAddMoreApps {
            return
        }
        
        let openPanel = NSOpenPanel()
        openPanel.canChooseFiles = true
        openPanel.canChooseDirectories = false
        openPanel.allowsMultipleSelection = false
        openPanel.directoryURL = URL(fileURLWithPath: "/Applications")
        
        openPanel.begin { result in
            if result == .OK {
                guard let url = openPanel.url else { return }
                let bundle = Bundle(url: url)
                guard let bundleIdentifier = bundle?.bundleIdentifier,
                      let appName = bundle?.infoDictionary?["CFBundleName"] as? String else { return }
                
                DispatchQueue.main.async {
                    if !self.focusApps.contains(where: { $0.bundleIdentifier == bundleIdentifier }) {
                        let newApp = AppInfo(
                            id: UUID().uuidString,
                            name: appName,
                            bundleIdentifier: bundleIdentifier
                        )
                        self.focusApps.append(newApp)
                    }
                }
            }
        }
    }
}

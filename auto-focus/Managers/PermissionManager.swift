//
//  PermissionManager.swift
//  auto-focus
//
//  Created by Copilot on 13/08/2025.
//

import Foundation
import AppKit
import SwiftUI

class PermissionManager: ObservableObject {
    @Published var automationPermissionGranted: Bool = false
    @Published var shortcutExists: Bool = false
    
    init() {
        checkPermissions()
    }
    
    // MARK: - Permission Checking
    
    func checkPermissions() {
        DispatchQueue.main.async {
            self.automationPermissionGranted = self.checkAutomationPermission()
            self.shortcutExists = self.checkShortcutExists()
        }
    }
    
    private func checkAutomationPermission() -> Bool {
        // Check if we have automation permission by trying to access System Events
        let script = """
        tell application "System Events"
            get name of processes
        end tell
        """
        
        var error: NSDictionary?
        if let scriptObject = NSAppleScript(source: script) {
            scriptObject.executeAndReturnError(&error)
            return error == nil
        }
        
        return false
    }
    
    private func checkShortcutExists() -> Bool {
        // Use the existing FocusModeManager logic for checking shortcut existence
        let shortcutsApp = NSWorkspace.shared.urlForApplication(withBundleIdentifier: AppConfiguration.shortcutsAppBundleIdentifier)
        guard shortcutsApp != nil else {
            return false
        }
        
        let script = """
        tell application "Shortcuts"
            exists shortcut "\(AppConfiguration.shortcutName)"
        end tell
        """
        
        var error: NSDictionary?
        if let scriptObject = NSAppleScript(source: script) {
            if let result = Optional(scriptObject.executeAndReturnError(&error)) {
                return result.booleanValue
            }
        }
        
        return false
    }
    
    // MARK: - Permission Requests
    
    func requestAutomationPermission() {
        // Trigger the system dialog by attempting to use System Events
        let script = """
        tell application "System Events"
            get name of processes
        end tell
        """
        
        var error: NSDictionary?
        if let scriptObject = NSAppleScript(source: script) {
            scriptObject.executeAndReturnError(&error)
        }
        
        // Re-check permissions after a short delay
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            self.checkPermissions()
        }
    }
    
    func requestShortcutsPermission() {
        // Install the shortcut using existing ResourceManager logic
        installShortcut()
        
        // Re-check permissions after a short delay
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            self.checkPermissions()
        }
    }
    
    func testShortcut() {
        // Test the shortcut using existing FocusModeManager logic
        let toggleScript = """
        tell application "System Events"
            tell application "Shortcuts Events"
                run shortcut "\(AppConfiguration.shortcutName)" without activating
            end tell
        end tell
        """
        
        var error: NSDictionary?
        if let scriptObject = NSAppleScript(source: toggleScript) {
            scriptObject.executeAndReturnError(&error)
            if error == nil {
                print("Shortcut test successful")
            } else {
                print("Shortcut test failed: \(error?.description ?? "Unknown error")")
            }
        }
    }
    
    func openSystemPreferences() {
        // Open System Settings to Privacy & Security > Automation
        let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Automation")!
        NSWorkspace.shared.open(url)
    }
    
    // MARK: - Private Helpers
    
    private func installShortcut() {
        guard let shortcutUrl = ResourceManager.copyShortcutToTemporary() else {
            print("Could not prepare shortcut for installation")
            return
        }
        
        NSWorkspace.shared.open(shortcutUrl)
    }
}
// Add this AppDelegate to your project or update your existing one

import SwiftUI
import AppKit

class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        // Start as a menu bar app with no dock icon
        NSApp.setActivationPolicy(.accessory)
    }
    
    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        // When the last window closes, hide from dock
        NSApp.setActivationPolicy(.accessory)
        NSApp.deactivate()
        return false
    }
}
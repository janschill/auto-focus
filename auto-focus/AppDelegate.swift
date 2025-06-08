//
//  AppDelegate.swift
//  auto-focus
//
//  Created by Jan Schill on 21/03/2025.
//

// Add this AppDelegate to your project or update your existing one

import AppKit
import SwiftUI

class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        // Start as a menu bar app with no dock icon
        NSApp.setActivationPolicy(.accessory)
        
        // Listen for window creation to manage app activation policy
        NotificationCenter.default.addObserver(
            forName: NSWindow.didBecomeKeyNotification,
            object: nil,
            queue: .main
        ) { [weak self] notification in
            self?.handleWindowBecameKey(notification)
        }
        
        NotificationCenter.default.addObserver(
            forName: NSWindow.willCloseNotification,
            object: nil,
            queue: .main
        ) { [weak self] notification in
            self?.handleWindowWillClose(notification)
        }
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        // When the last window closes, hide from dock
        NSApp.setActivationPolicy(.accessory)
        NSApp.deactivate()
        return false
    }
    
    private func handleWindowBecameKey(_ notification: Notification) {
        // When a window becomes key (like Settings), make the app regular so it can be focused
        if NSApp.windows.contains(where: { $0.isVisible && !$0.title.isEmpty }) {
            NSApp.setActivationPolicy(.regular)
            NSApp.activate(ignoringOtherApps: true)
        }
    }
    
    private func handleWindowWillClose(_ notification: Notification) {
        // When windows close, check if we should return to accessory mode
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            let visibleWindows = NSApp.windows.filter { $0.isVisible && !$0.title.isEmpty }
            if visibleWindows.isEmpty {
                NSApp.setActivationPolicy(.accessory)
                NSApp.deactivate()
            }
        }
    }
}

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
        // Set up debugging
        CoreSVGDebugger.setupDebugging()
        
        // Register Slack OAuth URL scheme
        SlackOAuthManager.registerURLScheme()
        
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
                
                // Clear image cache when no windows are visible to free memory
                SafeImageLoader.clearCache()
            }
        }
    }
    
    func applicationDidReceiveMemoryWarning(_ application: NSApplication) {
        // Clear image cache on memory warnings
        SafeImageLoader.clearCache()
    }
    
    // MARK: - URL Scheme Handling
    
    func application(_ application: NSApplication, open urls: [URL]) {
        for url in urls {
            handleURLScheme(url)
        }
    }
    
    private func handleURLScheme(_ url: URL) {
        print("AppDelegate: Received URL scheme: \(url)")
        print("AppDelegate: Full URL string: \(url.absoluteString)")
        
        guard url.scheme == "autofocus" else {
            print("AppDelegate: Unknown URL scheme: \(url.scheme ?? "none")")
            return
        }
        
        if url.host == "slack" {
            handleSlackCallback(url)
        } else {
            print("AppDelegate: Unknown autofocus host: \(url.host ?? "none")")
        }
    }
    
    private func handleSlackCallback(_ url: URL) {
        guard let components = URLComponents(url: url, resolvingAgainstBaseURL: false) else {
            print("AppDelegate: Failed to parse Slack callback URL")
            return
        }
        
        let path = components.path
        
        // Parse query parameters
        let params = components.queryItems?.reduce(into: [String: String]()) { result, item in
            if let value = item.value {
                result[item.name] = value
            }
        } ?? [:]
        
        print("AppDelegate: Slack callback - path: \(path), params: \(params.keys.joined(separator: ", "))")
        
        // Route based on path
        switch path {
        case "/oauth/success":
            print("AppDelegate: Slack OAuth success")
            NotificationCenter.default.post(
                name: Notification.Name("SlackOAuthCallback"),
                object: nil,
                userInfo: params
            )
            
        case "/oauth/error":
            print("AppDelegate: Slack OAuth error: \(params["error"] ?? "unknown")")
            NotificationCenter.default.post(
                name: Notification.Name("SlackOAuthCallback"),
                object: nil,
                userInfo: params
            )
            
        default:
            print("AppDelegate: Unknown Slack callback path: \(path)")
        }
    }
}

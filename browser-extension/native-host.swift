#!/usr/bin/env swift

import Foundation

// Simple native messaging host for Auto-Focus browser extension
// This communicates with the main Auto-Focus app via UserDefaults

class NativeMessagingHost {
    private let userDefaults = UserDefaults(suiteName: "group.com.janschill.auto-focus") ?? UserDefaults.standard
    
    func run() {
        // Load focus URLs from shared UserDefaults
        let focusURLsData = userDefaults.data(forKey: "focusURLs") ?? Data()
        
        while true {
            // Read message length (4 bytes)
            var lengthBytes = Data(count: 4)
            let lengthRead = lengthBytes.withUnsafeMutableBytes { buffer in
                return fread(buffer.baseAddress, 1, 4, stdin)
            }
            
            guard lengthRead == 4 else {
                break
            }
            
            // Convert to message length
            let messageLength = lengthBytes.withUnsafeBytes { buffer in
                return buffer.load(as: UInt32.self).littleEndian
            }
            
            guard messageLength > 0 && messageLength < 1024 * 1024 else {
                continue
            }
            
            // Read message data
            var messageData = Data(count: Int(messageLength))
            let messageRead = messageData.withUnsafeMutableBytes { buffer in
                return fread(buffer.baseAddress, 1, Int(messageLength), stdin)
            }
            
            guard messageRead == messageLength else {
                continue
            }
            
            // Parse and handle message
            handleMessage(messageData)
        }
    }
    
    private func handleMessage(_ data: Data) {
        do {
            let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]
            guard let message = json,
                  let command = message["command"] as? String else {
                return
            }
            
            switch command {
            case "handshake":
                sendResponse([
                    "command": "handshake_response",
                    "status": "connected",
                    "version": "1.0.0"
                ])
                
            case "tab_changed":
                guard let url = message["url"] as? String else { 
                    sendResponse([
                        "command": "focus_state_changed", 
                        "isFocusActive": false
                    ])
                    return 
                }
                
                let isFocus = checkIfFocusURL(url)
                
                // Store current tab info for main app
                userDefaults.set(url, forKey: "currentBrowserURL")
                userDefaults.set(isFocus, forKey: "isBrowserInFocus")
                userDefaults.set(Date().timeIntervalSince1970, forKey: "lastBrowserUpdate")
                
                // Send response to extension
                sendResponse([
                    "command": "focus_state_changed",
                    "isFocusActive": isFocus
                ])
                
            default:
                break
            }
            
        } catch {
            // Ignore JSON errors
        }
    }
    
    private func checkIfFocusURL(_ url: String) -> Bool {
        // For now, let's hardcode some focus URLs to test
        let hardcodedFocusURLs = [
            "github.com",
            "stackoverflow.com", 
            "docs.google.com"
        ]
        
        guard let urlObj = URL(string: url) else {
            return false
        }
        
        let domain = urlObj.host ?? ""
        
        for focusDomain in hardcodedFocusURLs {
            if domain == focusDomain || domain.hasSuffix("." + focusDomain) {
                return true
            }
        }
        
        return false
    }
    
    private func sendResponse(_ message: [String: Any]) {
        do {
            let jsonData = try JSONSerialization.data(withJSONObject: message)
            let length = UInt32(jsonData.count).littleEndian
            
            // Write length (4 bytes) then message
            let lengthData = withUnsafeBytes(of: length) { Data($0) }
            
            lengthData.withUnsafeBytes { buffer in
                fwrite(buffer.baseAddress, 1, 4, stdout)
            }
            
            jsonData.withUnsafeBytes { buffer in
                fwrite(buffer.baseAddress, 1, jsonData.count, stdout)
            }
            
            fflush(stdout)
            
        } catch {
            // Ignore encoding errors
        }
    }
}

// Simplified for testing - we'll use hardcoded URLs for now

// Run the native messaging host
let host = NativeMessagingHost()
host.run()
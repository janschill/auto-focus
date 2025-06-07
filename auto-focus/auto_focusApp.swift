//
//  auto_focusApp.swift
//  auto-focus
//
//  Created by Jan Schill on 25/01/2025.
//

import SwiftUI

@main
struct auto_focusApp: App {
    @StateObject private var focusManager = FocusManager()
    @StateObject private var licenseManager = LicenseManager()
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    var body: some Scene {
        Settings {
            SettingsView()
                .environmentObject(focusManager)
                .environmentObject(licenseManager)
        }
        
        MenuBarExtra {
            MenuBarView()
                .environmentObject(focusManager)
        } label: {
            HStack(spacing: 4) {
                if focusManager.isPaused {
                    Image(systemName: "pause.circle")
                } else if focusManager.isFocusAppActive {
                    Text(TimeFormatter.duration(focusManager.timeSpent))
                        .font(.system(size: 10, weight: .medium))
                }
                if focusManager.isInFocusMode {
                    Image(systemName: "brain.head.profile.fill")
                } else {
                    Image(systemName: "brain.head.profile")
                }
                if focusManager.isInBufferPeriod {
                    Text(TimeFormatter.duration(focusManager.bufferTimeRemaining))
                        .font(.system(size: 10, weight: .medium))
                }
            }
        }
        .menuBarExtraStyle(.window)
    }
}

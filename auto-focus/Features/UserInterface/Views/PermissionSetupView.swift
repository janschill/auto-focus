//
//  PermissionSetupView.swift
//  auto-focus
//
//  Created by Copilot on 13/08/2025.
//

import SwiftUI

struct PermissionSetupView: View {
    @StateObject private var permissionManager = PermissionManager()
    @EnvironmentObject var focusManager: FocusManager
    @State private var showingPermissionAlert = false
    @State private var permissionStep = 0
    
    var body: some View {
        GroupBox("Permissions Setup") {
            VStack(alignment: .leading, spacing: 16) {
                Text("Auto-Focus needs permission to control macOS Focus modes")
                    .font(.headline)
                
                // Step 1: Automation Permission
                PermissionStepView(
                    stepNumber: 1,
                    title: "System Automation",
                    description: "Allows Auto-Focus to control Do Not Disturb",
                    isCompleted: permissionManager.automationPermissionGranted,
                    action: {
                        permissionManager.requestAutomationPermission()
                        showingPermissionAlert = true
                    }
                )
                
                // Step 2: Shortcuts Permission
                PermissionStepView(
                    stepNumber: 2,
                    title: "Shortcuts Access",
                    description: "Allows Auto-Focus to run the Do Not Disturb shortcut",
                    isCompleted: permissionManager.shortcutExists,
                    action: {
                        permissionManager.requestShortcutsPermission()
                    }
                )
                
                // Step 3: Test
                if permissionManager.automationPermissionGranted && permissionManager.shortcutExists {
                    HStack {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundColor(.green)
                        Text("Ready to test!")
                        Spacer()
                        Button("Test Shortcut") {
                            permissionManager.testShortcut()
                        }
                        .buttonStyle(.borderedProminent)
                    }
                    .padding(.vertical, 8)
                    .padding(.horizontal, 12)
                    .background(Color.green.opacity(0.1))
                    .cornerRadius(8)
                }
                
                // Manual fallback
                Divider()
                
                VStack(alignment: .leading, spacing: 8) {
                    Text("Need manual setup?")
                        .font(.subheadline)
                        .fontWeight(.medium)
                    
                    HStack {
                        Button("Open System Settings") {
                            permissionManager.openSystemPreferences()
                        }
                        .controlSize(.small)
                        
                        Text("Go to Privacy & Security > Automation")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
            }
            .padding()
        }
        .onAppear {
            permissionManager.checkPermissions()
        }
        .alert("Permission Request Sent", isPresented: $showingPermissionAlert) {
            Button("OK") {
                // Re-check permissions after user dismisses alert
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                    permissionManager.checkPermissions()
                }
            }
        } message: {
            Text("A system dialog should have appeared asking for automation permission. If you don't see it, click 'Open System Settings' below.")
        }
    }
}

struct PermissionStepView: View {
    let stepNumber: Int
    let title: String
    let description: String
    let isCompleted: Bool
    let action: () -> Void
    
    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            // Step indicator
            ZStack {
                Circle()
                    .fill(isCompleted ? Color.green : Color.blue)
                    .frame(width: 24, height: 24)
                
                if isCompleted {
                    Image(systemName: "checkmark")
                        .foregroundColor(.white)
                        .font(.caption.bold())
                } else {
                    Text("\(stepNumber)")
                        .foregroundColor(.white)
                        .font(.caption.bold())
                }
            }
            
            // Content
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.subheadline)
                    .fontWeight(.medium)
                
                Text(description)
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                if !isCompleted {
                    Button("Grant Permission") {
                        action()
                    }
                    .controlSize(.small)
                    .buttonStyle(.borderedProminent)
                }
            }
            
            Spacer()
        }
        .padding(.vertical, 4)
    }
}

#Preview {
    PermissionSetupView()
        .environmentObject(FocusManager.shared)
        .frame(width: 600, height: 400)
}
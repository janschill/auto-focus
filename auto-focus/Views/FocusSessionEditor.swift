//
//  FocusSessionEditor.swift
//  auto-focus
//
//  Created by Jan Schill on 27/01/2025.
//

import SwiftUI

struct FocusSessionEditor: View {
    @EnvironmentObject var focusManager: FocusManager
    @State private var startTime: Date
    @State private var endTime: Date
    @State private var showingValidationAlert = false
    @State private var validationMessage = ""
    
    private let session: FocusSession
    private let onSave: (FocusSession) -> Void
    private let onCancel: () -> Void
    private let onDelete: () -> Void
    
    init(session: FocusSession, onSave: @escaping (FocusSession) -> Void, onCancel: @escaping () -> Void, onDelete: @escaping () -> Void) {
        self.session = session
        self.onSave = onSave
        self.onCancel = onCancel
        self.onDelete = onDelete
        self._startTime = State(initialValue: session.startTime)
        self._endTime = State(initialValue: session.endTime)
    }
    
    var body: some View {
        VStack(spacing: 20) {
            // Header
            HStack {
                Text("Edit Focus Session")
                    .font(.title2)
                    .fontWeight(.bold)
                Spacer()
                Button("Cancel", action: onCancel)
            }
            .padding(.bottom, 10)
            
            VStack(alignment: .leading, spacing: 16) {
                // Session Info
                GroupBox("Session Information") {
                    VStack(alignment: .leading, spacing: 12) {
                        HStack {
                            Text("Session ID:")
                                .fontWeight(.medium)
                                .frame(width: 100, alignment: .leading)
                            Text(session.id.uuidString.prefix(8))
                                .font(.monospaced(.body)())
                                .foregroundColor(.secondary)
                        }
                        
                        HStack {
                            Text("Original Duration:")
                                .fontWeight(.medium)
                                .frame(width: 100, alignment: .leading)
                            Text(TimeFormatter.duration(Int(session.duration / 60)))
                                .foregroundColor(.secondary)
                        }
                        
                        HStack {
                            Text("New Duration:")
                                .fontWeight(.medium)
                                .frame(width: 100, alignment: .leading)
                            Text(TimeFormatter.duration(Int(newDuration / 60)))
                                .foregroundColor(newDuration > 0 ? .primary : .red)
                        }
                    }
                }
                
                // Time Editor
                GroupBox("Edit Times") {
                    VStack(spacing: 16) {
                        HStack {
                            Text("Start Time:")
                                .fontWeight(.medium)
                                .frame(width: 100, alignment: .leading)
                            DatePicker(
                                "",
                                selection: $startTime,
                                displayedComponents: [.date, .hourAndMinute]
                            )
                            .labelsHidden()
                        }
                        
                        HStack {
                            Text("End Time:")
                                .fontWeight(.medium)
                                .frame(width: 100, alignment: .leading)
                            DatePicker(
                                "",
                                selection: $endTime,
                                displayedComponents: [.date, .hourAndMinute]
                            )
                            .labelsHidden()
                        }
                        
                        if !isValidSession {
                            HStack {
                                Image(systemName: "exclamationmark.triangle.fill")
                                    .foregroundColor(.orange)
                                Text("End time must be after start time")
                                    .font(.caption)
                                    .foregroundColor(.orange)
                            }
                        }
                    }
                }
                
                // Quick Duration Adjustments
                GroupBox("Quick Adjustments") {
                    VStack(spacing: 8) {
                        Text("Adjust session duration:")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        
                        HStack(spacing: 12) {
                            Button("-5m") { adjustDuration(-5) }
                                .controlSize(.small)
                            Button("-1m") { adjustDuration(-1) }
                                .controlSize(.small)
                            Button("+1m") { adjustDuration(1) }
                                .controlSize(.small)
                            Button("+5m") { adjustDuration(5) }
                                .controlSize(.small)
                        }
                        .buttonStyle(.bordered)
                        
                        Text("(Adjusts end time by the specified amount)")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
            }
            
            Spacer()
            
            // Action Buttons
            HStack(spacing: 16) {
                Button("Delete Session") {
                    onDelete()
                }
                .buttonStyle(.bordered)
                .foregroundColor(.red)
                
                Spacer()
                
                Button("Save Changes") {
                    saveSession()
                }
                .buttonStyle(.borderedProminent)
                .disabled(!isValidSession || !hasChanges)
            }
        }
        .padding()
        .frame(width: 500, height: 550)
        .alert("Invalid Session", isPresented: $showingValidationAlert) {
            Button("OK") { }
        } message: {
            Text(validationMessage)
        }
    }
    
    // MARK: - Computed Properties
    
    private var newDuration: TimeInterval {
        return endTime.timeIntervalSince(startTime)
    }
    
    private var isValidSession: Bool {
        return startTime < endTime
    }
    
    private var hasChanges: Bool {
        return startTime != session.startTime || endTime != session.endTime
    }
    
    // MARK: - Helper Methods
    
    private func adjustDuration(_ minutes: Int) {
        let adjustment = TimeInterval(minutes * 60)
        let newEndTime = endTime.addingTimeInterval(adjustment)
        
        // Ensure the new end time is still after start time
        if newEndTime > startTime {
            endTime = newEndTime
        }
    }
    
    private func saveSession() {
        guard isValidSession else {
            validationMessage = "End time must be after start time."
            showingValidationAlert = true
            return
        }
        
        // Additional validation: prevent sessions longer than 24 hours
        if newDuration > 24 * 60 * 60 {
            validationMessage = "Session duration cannot exceed 24 hours."
            showingValidationAlert = true
            return
        }
        
        // Prevent sessions shorter than 1 minute
        if newDuration < 60 {
            validationMessage = "Session duration must be at least 1 minute."
            showingValidationAlert = true
            return
        }
        
        var updatedSession = session
        updatedSession.startTime = startTime
        updatedSession.endTime = endTime
        
        onSave(updatedSession)
    }
}

// MARK: - Preview

#Preview {
    let sampleSession = FocusSession(
        startTime: Date().addingTimeInterval(-3600), // 1 hour ago
        endTime: Date()
    )
    
    return FocusSessionEditor(
        session: sampleSession,
        onSave: { _ in print("Save") },
        onCancel: { print("Cancel") },
        onDelete: { print("Delete") }
    )
    .environmentObject(FocusManager.shared)
}
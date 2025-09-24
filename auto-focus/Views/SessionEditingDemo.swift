//
//  SessionEditingDemo.swift
//  auto-focus
//
//  Created by Jan Schill on 27/01/2025.
//

import SwiftUI

#if DEBUG

struct SessionEditingDemo: View {
    @StateObject private var demoFocusManager = createDemoFocusManager()
    @State private var showingDataView = false
    
    var body: some View {
        VStack(spacing: 20) {
            Text("Session Editor Demo")
                .font(.largeTitle)
                .fontWeight(.bold)
            
            Text("This demo showcases the new session editing functionality")
                .font(.subheadline)
                .foregroundColor(.secondary)
            
            VStack(spacing: 12) {
                Text("Sample Sessions Loaded:")
                    .font(.headline)
                
                Text("\(demoFocusManager.focusSessions.count) sessions")
                    .font(.title2)
                    .fontWeight(.semibold)
                
                if let shortest = demoFocusManager.focusSessions.min(by: { $0.duration < $1.duration }) {
                    Text("Shortest: \(TimeFormatter.duration(Int(shortest.duration / 60)))")
                        .font(.caption)
                        .foregroundColor(shortest.duration < 60 ? .orange : .primary)
                }
                
                if let longest = demoFocusManager.focusSessions.max(by: { $0.duration < $1.duration }) {
                    Text("Longest: \(TimeFormatter.duration(Int(longest.duration / 60)))")
                        .font(.caption)
                        .foregroundColor(.blue)
                }
            }
            .padding()
            .background(Color(.controlBackgroundColor))
            .cornerRadius(8)
            
            Button("Open Data Management") {
                showingDataView = true
            }
            .buttonStyle(.borderedProminent)
            .font(.headline)
            
            Spacer()
            
            VStack(alignment: .leading, spacing: 8) {
                Text("Features to test:")
                    .font(.headline)
                
                VStack(alignment: .leading, spacing: 4) {
                    Label("View and filter sessions by duration", systemImage: "eye")
                    Label("Edit session start and end times", systemImage: "pencil")
                    Label("Quick duration adjustments (+/-1m, +/-5m)", systemImage: "clock.arrow.circlepath")
                    Label("Validation for invalid session times", systemImage: "checkmark.shield")
                    Label("Delete sessions with confirmation", systemImage: "trash")
                }
                .font(.caption)
                .foregroundColor(.secondary)
            }
            .padding()
            .background(Color(.controlBackgroundColor).opacity(0.5))
            .cornerRadius(8)
        }
        .padding()
        .frame(width: 500, height: 600)
        .sheet(isPresented: $showingDataView) {
            NavigationView {
                DataView(selectedTab: .constant(2))
                    .environmentObject(demoFocusManager)
                    .environmentObject(LicenseManager())
                    .navigationTitle("Data Management")
                    .navigationBarTitleDisplayMode(.inline)
                    .toolbar {
                        ToolbarItem(placement: .navigationBarTrailing) {
                            Button("Close") {
                                showingDataView = false
                            }
                        }
                    }
            }
            .frame(minWidth: 800, minHeight: 700)
        }
    }
}

private func createDemoFocusManager() -> FocusManager {
    let mockSessionManager = MockSessionManager()
    let focusManager = FocusManager(sessionManager: mockSessionManager)
    
    // Create sample sessions with various durations for testing
    let now = Date()
    let sampleSessions = [
        // Very short session (30 seconds) - should show in orange
        FocusSession(startTime: now.addingTimeInterval(-86400), endTime: now.addingTimeInterval(-86400 + 30)),
        
        // Short session (5 minutes) - should show in yellow  
        FocusSession(startTime: now.addingTimeInterval(-7200), endTime: now.addingTimeInterval(-7200 + 300)),
        
        // Medium session (25 minutes) - should show in green
        FocusSession(startTime: now.addingTimeInterval(-3600), endTime: now.addingTimeInterval(-3600 + 1500)),
        
        // Long session (2 hours) - should show in blue
        FocusSession(startTime: now.addingTimeInterval(-14400), endTime: now.addingTimeInterval(-14400 + 7200)),
        
        // Today's session (45 minutes)
        FocusSession(startTime: now.addingTimeInterval(-2700), endTime: now),
        
        // Another today session (15 minutes)
        FocusSession(startTime: now.addingTimeInterval(-1800), endTime: now.addingTimeInterval(-900))
    ]
    
    focusManager.addSampleSessions(sampleSessions)
    return focusManager
}

// MARK: - Preview

#Preview {
    SessionEditingDemo()
}

#endif
//
//  SessionListView.swift
//  auto-focus
//
//  Created by Jan Schill on 27/01/2025.
//

import SwiftUI

struct SessionListView: View {
    @EnvironmentObject var focusManager: FocusManager
    @State private var showingSessionEditor = false
    @State private var selectedSession: FocusSession?
    @State private var showingDeleteConfirmation = false
    @State private var sessionToDelete: FocusSession?
    @State private var sortOrder: SessionSortOrder = .newest
    @State private var filterDuration: SessionDurationFilter = .all
    
    private var filteredAndSortedSessions: [FocusSession] {
        let filtered = filteredSessions
        
        switch sortOrder {
        case .newest:
            return filtered.sorted { $0.startTime > $1.startTime }
        case .oldest:
            return filtered.sorted { $0.startTime < $1.startTime }
        case .shortest:
            return filtered.sorted { $0.duration < $1.duration }
        case .longest:
            return filtered.sorted { $0.duration > $1.duration }
        }
    }
    
    private var filteredSessions: [FocusSession] {
        let sessions = focusManager.focusSessions
        
        switch filterDuration {
        case .all:
            return sessions
        case .veryShort:
            return sessions.filter { $0.duration < 60 } // Less than 1 minute
        case .short:
            return sessions.filter { $0.duration >= 60 && $0.duration < 10 * 60 } // 1-10 minutes
        case .medium:
            return sessions.filter { $0.duration >= 10 * 60 && $0.duration < 60 * 60 } // 10-60 minutes
        case .long:
            return sessions.filter { $0.duration >= 60 * 60 } // 1+ hours
        }
    }
    
    var body: some View {
        VStack(spacing: 16) {
            // Header and Controls
            sessionControlsHeader
            
            if filteredAndSortedSessions.isEmpty {
                emptyStateView
            } else {
                sessionsList
            }
        }
        .sheet(isPresented: $showingSessionEditor) {
            sessionEditorSheet
        }
        .alert(isPresented: $showingDeleteConfirmation) {
            deleteConfirmationAlert
        }
    }
    
    // MARK: - View Components
    
    private var sessionControlsHeader: some View {
        VStack(spacing: 12) {
            HStack {
                Text("Focus Sessions")
                    .font(.headline)
                    .fontWeight(.semibold)
                
                Spacer()
                
                Text("\(filteredAndSortedSessions.count) sessions")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            // Filters and Sort Controls
            HStack(spacing: 16) {
                // Duration Filter
                Picker("Filter", selection: $filterDuration) {
                    ForEach(SessionDurationFilter.allCases, id: \.self) { filter in
                        Text(filter.displayName).tag(filter)
                    }
                }
                .pickerStyle(.menu)
                .frame(maxWidth: 150)
                
                // Sort Order
                Picker("Sort", selection: $sortOrder) {
                    ForEach(SessionSortOrder.allCases, id: \.self) { order in
                        Text(order.displayName).tag(order)
                    }
                }
                .pickerStyle(.menu)
                .frame(maxWidth: 150)
                
                Spacer()
            }
        }
    }
    
    private var emptyStateView: some View {
        VStack(spacing: 12) {
            Image(systemName: "clock.badge.questionmark")
                .font(.largeTitle)
                .foregroundColor(.secondary)
            
            Text("No sessions found")
                .font(.headline)
                .foregroundColor(.secondary)
            
            if filterDuration != .all || focusManager.focusSessions.isEmpty {
                Text(focusManager.focusSessions.isEmpty 
                     ? "Start using Auto-Focus to record your first session"
                     : "Try adjusting your filters to see more sessions")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
            }
        }
        .padding(.vertical, 40)
    }
    
    private var sessionsList: some View {
        ScrollView {
            LazyVStack(spacing: 8) {
                ForEach(filteredAndSortedSessions) { session in
                    SessionRowView(
                        session: session,
                        onEdit: {
                            selectedSession = session
                            showingSessionEditor = true
                        },
                        onDelete: {
                            sessionToDelete = session
                            showingDeleteConfirmation = true
                        }
                    )
                }
            }
            .padding(.horizontal, 4)
        }
        .frame(maxHeight: 400)
    }
    
    // MARK: - Sheets and Alerts
    
    private var sessionEditorSheet: some View {
        Group {
            if let session = selectedSession {
                FocusSessionEditor(
                    session: session,
                    onSave: { updatedSession in
                        focusManager.updateSession(updatedSession)
                        selectedSession = nil
                        showingSessionEditor = false
                    },
                    onCancel: {
                        selectedSession = nil
                        showingSessionEditor = false
                    },
                    onDelete: {
                        if let sessionToDelete = selectedSession {
                            focusManager.deleteSession(sessionToDelete)
                            selectedSession = nil
                            showingSessionEditor = false
                        }
                    }
                )
            }
        }
    }
    
    private var deleteConfirmationAlert: Alert {
        Alert(
            title: Text("Delete Session"),
            message: Text("Are you sure you want to delete this session? This action cannot be undone."),
            primaryButton: .destructive(Text("Delete")) {
                if let session = sessionToDelete {
                    focusManager.deleteSession(session)
                    sessionToDelete = nil
                }
            },
            secondaryButton: .cancel {
                sessionToDelete = nil
            }
        )
    }
}

// MARK: - Session Row View

struct SessionRowView: View {
    let session: FocusSession
    let onEdit: () -> Void
    let onDelete: () -> Void
    
    private var dateFormatter: DateFormatter {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter
    }
    
    private var durationColor: Color {
        let duration = session.duration
        if duration < 60 { return .orange } // Very short
        if duration < 10 * 60 { return .yellow } // Short
        if duration < 60 * 60 { return .green } // Good
        return .blue // Long
    }
    
    var body: some View {
        HStack(spacing: 12) {
            // Duration indicator
            RoundedRectangle(cornerRadius: 2)
                .fill(durationColor)
                .frame(width: 4)
            
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(TimeFormatter.duration(Int(session.duration / 60)))
                        .font(.headline)
                        .fontWeight(.semibold)
                    
                    Spacer()
                    
                    Text(dateFormatter.string(from: session.startTime))
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                HStack {
                    Text("Started: \(formatTime(session.startTime))")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    Text("•")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    Text("Ended: \(formatTime(session.endTime))")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    Spacer()
                }
            }
            
            // Action buttons
            HStack(spacing: 8) {
                Button(action: onEdit) {
                    Image(systemName: "pencil")
                        .foregroundColor(.blue)
                }
                .buttonStyle(.plain)
                .help("Edit session")
                
                Button(action: onDelete) {
                    Image(systemName: "trash")
                        .foregroundColor(.red)
                }
                .buttonStyle(.plain)
                .help("Delete session")
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(Color(.controlBackgroundColor))
        .cornerRadius(8)
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(Color(.separatorColor), lineWidth: 0.5)
        )
    }
    
    private func formatTime(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
}

// MARK: - Supporting Types

enum SessionSortOrder: CaseIterable {
    case newest, oldest, shortest, longest
    
    var displayName: String {
        switch self {
        case .newest: return "Newest First"
        case .oldest: return "Oldest First"
        case .shortest: return "Shortest First"
        case .longest: return "Longest First"
        }
    }
}

enum SessionDurationFilter: CaseIterable {
    case all, veryShort, short, medium, long
    
    var displayName: String {
        switch self {
        case .all: return "All Sessions"
        case .veryShort: return "Very Short (<1m)"
        case .short: return "Short (1-10m)"
        case .medium: return "Medium (10-60m)"
        case .long: return "Long (1h+)"
        }
    }
}

// MARK: - Preview

#Preview {
    let sampleSessions = [
        FocusSession(startTime: Date().addingTimeInterval(-7200), endTime: Date().addingTimeInterval(-6000)),
        FocusSession(startTime: Date().addingTimeInterval(-14400), endTime: Date().addingTimeInterval(-14340)),
        FocusSession(startTime: Date().addingTimeInterval(-86400), endTime: Date().addingTimeInterval(-82800))
    ]
    
    return SessionListView()
        .environmentObject(FocusManager.shared)
        .onAppear {
            FocusManager.shared.addSampleSessions(sampleSessions)
        }
        .frame(width: 600, height: 500)
}
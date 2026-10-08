//
//  SessionListView.swift
//  auto-focus
//
//  Created by Jan Schill on 27/01/2025.
//

import SwiftUI

struct SessionListView: View {
    @EnvironmentObject var focusManager: FocusManager
    @Environment(\.dismiss) private var dismiss
    @State private var showingDeleteConfirmation = false
    @State private var showingBulkDeleteConfirmation = false
    @State private var sessionToDelete: FocusSession?
    @State private var sortOrder: SessionSortOrder
    @State private var filterDuration: SessionDurationFilter

    init(initialFilter: SessionDurationFilter = .all, initialSort: SessionSortOrder = .newest) {
        _filterDuration = State(initialValue: initialFilter)
        _sortOrder = State(initialValue: initialSort)
    }

    /// Filtered and sorted sessions, recomputed only when sessions, filter or sort change.
    @State private var filteredAndSortedSessions: [FocusSession] = []

    private func updateFilteredAndSortedSessions() {
        filteredAndSortedSessions = Self.filterAndSort(
            focusManager.focusSessions,
            filter: filterDuration,
            sortOrder: sortOrder
        )
    }

    /// Applies the duration filter and sort order to the given sessions.
    static func filterAndSort(
        _ sessions: [FocusSession],
        filter: SessionDurationFilter,
        sortOrder: SessionSortOrder
    ) -> [FocusSession] {
        let filtered: [FocusSession]
        switch filter {
        case .all:
            filtered = sessions
        case .veryShort:
            filtered = sessions.filter { $0.duration < 60 } // Less than 1 minute
        case .short:
            filtered = sessions.filter { $0.duration >= 60 && $0.duration < 10 * 60 } // 1-10 minutes
        case .medium:
            filtered = sessions.filter { $0.duration >= 10 * 60 && $0.duration < 60 * 60 } // 10-60 minutes
        case .long:
            filtered = sessions.filter { $0.duration >= 60 * 60 } // 1+ hours
        }

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

    private var sessionCountText: String {
        "\(filteredAndSortedSessions.count.formatted()) session\(filteredAndSortedSessions.count == 1 ? "" : "s")"
    }

    var body: some View {
        VStack(spacing: 0) {
            sessionControlsHeader
                .padding()

            Divider()

            if filteredAndSortedSessions.isEmpty {
                emptyStateView
            } else {
                sessionsList
            }

            Divider()

            HStack {
                Spacer()
                Button("Done") { dismiss() }
                    .keyboardShortcut(.defaultAction)
            }
            .padding()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .onAppear(perform: updateFilteredAndSortedSessions)
        .onChange(of: focusManager.focusSessions) { updateFilteredAndSortedSessions() }
        .onChange(of: filterDuration) { updateFilteredAndSortedSessions() }
        .onChange(of: sortOrder) { updateFilteredAndSortedSessions() }
        .alert(isPresented: $showingDeleteConfirmation) {
            deleteConfirmationAlert
        }
        .alert("Delete \(sessionCountText)?", isPresented: $showingBulkDeleteConfirmation) {
            Button("Cancel", role: .cancel) {}
            Button("Delete", role: .destructive) {
                let toDelete = filteredAndSortedSessions
                focusManager.deleteSessions(toDelete)
            }
        } message: {
            Text("This will delete every session matching '\(filterDuration.displayName)'. This action cannot be undone.")
        }
    }

    // MARK: - View Components

    private var sessionControlsHeader: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .firstTextBaseline) {
                Text("Focus Sessions")
                    .font(.title3)
                    .fontWeight(.semibold)

                Spacer()

                Text(sessionCountText)
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .monospacedDigit()
            }

            HStack(spacing: 12) {
                Picker("Filter", selection: $filterDuration) {
                    ForEach(SessionDurationFilter.allCases, id: \.self) { filter in
                        Text(filter.displayName).tag(filter)
                    }
                }
                .pickerStyle(.menu)
                .fixedSize()

                Picker("Sort", selection: $sortOrder) {
                    ForEach(SessionSortOrder.allCases, id: \.self) { order in
                        Text(order.displayName).tag(order)
                    }
                }
                .pickerStyle(.menu)
                .fixedSize()

                Spacer()

                if filterDuration != .all && !filteredAndSortedSessions.isEmpty {
                    Button(role: .destructive) {
                        showingBulkDeleteConfirmation = true
                    } label: {
                        Label("Delete \(sessionCountText)", systemImage: "trash")
                    }
                    .tint(.red)
                    .help("Delete every session matching the current filter")
                }
            }
        }
    }

    private var emptyStateView: some View {
        VStack(spacing: 8) {
            Image(systemName: "clock.badge.questionmark")
                .font(.title)
                .foregroundStyle(.secondary)

            Text("No sessions found")
                .font(.headline)
                .foregroundStyle(.secondary)

            if filterDuration != .all || focusManager.focusSessions.isEmpty {
                Text(focusManager.focusSessions.isEmpty
                     ? "Start using Auto-Focus to record your first session"
                     : "Try adjusting your filters to see more sessions")
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }
        }
        .padding()
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var sessionsList: some View {
        List(filteredAndSortedSessions) { session in
            SessionRowView(
                session: session,
                onDelete: {
                    sessionToDelete = session
                    showingDeleteConfirmation = true
                }
            )
        }
        .listStyle(.inset(alternatesRowBackgrounds: true))
    }

    // MARK: - Alerts

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
    let onDelete: () -> Void
    @State private var isHovering = false

    private var durationCategory: (color: Color, description: String) {
        let duration = session.duration
        if duration < 60 { return (.orange, "Very short session (under 1 minute)") }
        if duration < 10 * 60 { return (.yellow, "Short session (1–10 minutes)") }
        if duration < 60 * 60 { return (.green, "Medium session (10–60 minutes)") }
        return (.blue, "Long session (1 hour or more)")
    }

    private var timeRangeText: String {
        let start = session.startTime.formatted(date: .abbreviated, time: .shortened)
        let sameDay = Calendar.current.isDate(session.startTime, inSameDayAs: session.endTime)
        let end = session.endTime.formatted(date: sameDay ? .omitted : .abbreviated, time: .shortened)
        return "\(start) – \(end)"
    }

    var body: some View {
        let category = durationCategory

        HStack(spacing: 10) {
            Circle()
                .fill(category.color.gradient)
                .frame(width: 8, height: 8)
                .help(category.description)
                .accessibilityLabel(category.description)

            VStack(alignment: .leading, spacing: 2) {
                Text(TimeFormatter.duration(Int(session.duration / 60)))
                    .font(.headline)
                    .monospacedDigit()

                Text(timeRangeText)
                    .font(.callout)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            Button(action: onDelete) {
                Image(systemName: "trash")
            }
            .buttonStyle(.borderless)
            .foregroundStyle(.secondary)
            .help("Delete session")
            .opacity(isHovering ? 1 : 0)
            .allowsHitTesting(isHovering)
        }
        .padding(.vertical, 4)
        .contentShape(Rectangle())
        .onHover { isHovering = $0 }
        .contextMenu {
            Button("Delete", role: .destructive, action: onDelete)
        }
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

// InsightsViewModel.swift
import Combine
import SwiftUI

/// Holds the insights for the selected timeframe and date as a precomputed
/// snapshot. The snapshot is rebuilt only when one of its inputs changes, not on
/// every FocusManager timer tick.
class InsightsViewModel: ObservableObject {
    @Published var selectedTimeframe: InsightsDataProvider.Timeframe = .day {
        didSet { refresh() }
    }
    @Published var selectedDate: Date {
        didSet { refresh() }
    }
    @Published private(set) var snapshot: InsightsSnapshot

    private let dataProvider: InsightsDataProvider
    private var lastInputs: InsightsInputs?
    private var focusManagerCancellable: AnyCancellable?

    init(dataProvider: InsightsDataProvider) {
        let today = Date()
        self.dataProvider = dataProvider
        _selectedDate = Published(initialValue: today)
        snapshot = dataProvider.makeSnapshot(timeframe: .day, selectedDate: today)
        lastInputs = currentInputs()
    }

    /// Starts recomputing the snapshot whenever FocusManager changes one of its inputs.
    /// Call when the insights become visible.
    func startObserving() {
        refresh()
        focusManagerCancellable = dataProvider.focusManager.objectWillChange
            // objectWillChange fires before the mutation; read the new values on the next run loop pass.
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                self?.refresh()
            }
    }

    /// Stops observing FocusManager. Call when the insights are no longer visible.
    func stopObserving() {
        focusManagerCancellable = nil
    }

    /// Rebuilds the snapshot if any input changed since the last build.
    func refresh() {
        let inputs = currentInputs()
        guard inputs != lastInputs else { return }
        lastInputs = inputs
        snapshot = dataProvider.makeSnapshot(timeframe: selectedTimeframe, selectedDate: selectedDate)
    }

    /// Adds a focus URL. The snapshot picks it up on the next FocusManager change.
    func addFocusURL(_ focusURL: FocusURL) {
        dataProvider.focusManager.addFocusURL(focusURL)
    }

    func navigateDay(forward: Bool) {
        let calendar = Calendar.current

        // Find the next/previous day with data
        var currentDate = selectedDate
        let maxAttempts = 365 // Prevent infinite loop
        var attempts = 0

        while attempts < maxAttempts {
            currentDate = calendar.date(byAdding: .day, value: forward ? 1 : -1, to: currentDate) ?? currentDate

            // Check if this date has any sessions
            let sessions = dataProvider.sessionsForDate(currentDate)
            if !sessions.isEmpty {
                selectedDate = currentDate
                return
            }

            // Don't go beyond today when going forward
            if forward && calendar.isDateInToday(currentDate) {
                // If today has no data, stay on current date
                return
            }

            attempts += 1
        }

        // If we couldn't find a day with data, just move one day
        selectedDate = calendar.date(byAdding: .day, value: forward ? 1 : -1, to: selectedDate) ?? selectedDate
    }

    func navigateWeek(forward: Bool) {
        let calendar = Calendar.current
        selectedDate = calendar.date(byAdding: .day, value: forward ? 7 : -7, to: selectedDate) ?? selectedDate
    }

    func goToToday() {
        selectedTimeframe = .day
        selectedDate = Date()
    }

    private func currentInputs() -> InsightsInputs {
        let focusManager = dataProvider.focusManager
        return InsightsInputs(
            timeframe: selectedTimeframe,
            selectedDate: selectedDate,
            today: Calendar.current.startOfDay(for: Date()),
            sessions: focusManager.focusSessions,
            focusBundleIDs: focusManager.focusApps.map(\.bundleIdentifier),
            focusURLs: focusManager.focusURLs,
            currentAppBundleID: focusManager.currentAppBundleId,
            currentBrowserURL: focusManager.currentBrowserTab?.url
        )
    }
}

/// Everything an `InsightsSnapshot` depends on. The current app and browser URL
/// stand in for the app event log, which only grows when the user switches context.
private struct InsightsInputs: Equatable {
    let timeframe: InsightsDataProvider.Timeframe
    let selectedDate: Date
    let today: Date
    let sessions: [FocusSession]
    let focusBundleIDs: [String]
    let focusURLs: [FocusURL]
    let currentAppBundleID: String?
    let currentBrowserURL: String?
}

extension Calendar {
    func startOfWeek(for date: Date) -> Date {
        return self.date(from: self.dateComponents([.yearForWeekOfYear, .weekOfYear], from: date))!
    }
}

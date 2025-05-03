// InsightsViewModel.swift
import SwiftUI

class InsightsViewModel: ObservableObject {
    @Published var selectedTimeframe: InsightsDataProvider.Timeframe = .day
    @Published var selectedDate: Date = Date()

    private var dataProvider: InsightsDataProvider

    init(dataProvider: InsightsDataProvider) {
        self.dataProvider = dataProvider
    }

    func updateFocusManager(_ focusManager: FocusManager) {
        dataProvider.focusManager = focusManager
    }

    var displayedDateString: String {
        let calendar = Calendar.current
        let now = Date()

        if selectedTimeframe == .day {
            return dataProvider.dateString(for: selectedDate)
        }

        let startOfWeek = calendar.startOfWeek(for: selectedDate)
        let endOfWeek = calendar.date(byAdding: .day, value: 6, to: startOfWeek)!

        if calendar.isDate(startOfWeek, equalTo: now, toGranularity: .weekOfYear) {
            return "This week"
        } else if let lastWeek = calendar.date(byAdding: .weekOfYear, value: -1, to: now),
                  calendar.isDate(startOfWeek, equalTo: lastWeek, toGranularity: .weekOfYear) {
            return "Last week"
        } else {
            let formatter = DateFormatter()
            formatter.dateFormat = "MMM d"
            return "\(formatter.string(from: startOfWeek))–\(formatter.string(from: endOfWeek))"
        }
    }

    var totalFocusTime: TimeInterval {
        dataProvider.totalFocusTime(timeframe: selectedTimeframe, selectedDate: selectedDate)
    }
    
    var totalFocusTimeThisMonth: TimeInterval {
        dataProvider.calculateTotalFocusTimeThisMonth()
    }

    var relevantSessions: [FocusSession] {
        dataProvider.relevantSessions(timeframe: selectedTimeframe, selectedDate: selectedDate)
    }

    var weekdayData: [DayData] {
        dataProvider.weekdayData(selectedDate: selectedDate, selectedTimeframe: selectedTimeframe)
    }

    var hourlyData: [HourData] {
        dataProvider.hourlyData(selectedDate: selectedDate)
    }

    var averageDailyMinutes: Int {
        dataProvider.averageDailyMinutes(weekdayData: weekdayData)
    }

    var weekComparisonPercentage: Int? {
        let calendar = Calendar.current
        guard selectedTimeframe == .week else { return nil }

        let thisWeekStart = calendar.startOfWeek(for: selectedDate)
        guard let lastWeekStart = calendar.date(byAdding: .day, value: -7, to: thisWeekStart) else { return nil }

        let thisWeekDuration = dataProvider.totalFocusTimeInWeek(starting: thisWeekStart)
        let lastWeekDuration = dataProvider.totalFocusTimeInWeek(starting: lastWeekStart)

        guard lastWeekDuration > 0 else { return nil }

        let delta = thisWeekDuration - lastWeekDuration
        return Int((delta / lastWeekDuration) * 100)
    }

    func navigateDay(forward: Bool) {
        let calendar = Calendar.current
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
    
    func rearrangeWeekdaysStartingMonday(_ weekdayData: [(day: String, average: TimeInterval)]) -> [(day: String, average: TimeInterval)] {
        // American calendar: Sunday is at index 0, we need to move it to the end
        var rearranged = weekdayData
        if weekdayData.count == 7 {
            let sunday = rearranged.removeFirst()
            rearranged.append(sunday)
        }
        return rearranged
    }
    
    var productiveTimeRange: (startHour: Int, endHour: Int, duration: TimeInterval)? {
        return dataProvider.calculateProductiveTimeRange()
    }
    
    var productiveWeekday: (weekday: Int, duration: TimeInterval)? {
        return dataProvider.calculateProductiveWeekday()
    }
    
    var weekdayAverages: [(day: String, average: TimeInterval)] {
        return dataProvider.calculateWeekdayAverages()
    }
    
    func formatHourRange(_ startHour: Int, _ endHour: Int) -> String {
        return dataProvider.formatHourRange(startHour, endHour)
    }
}

extension Calendar {
    func startOfWeek(for date: Date) -> Date {
        return self.date(from: self.dateComponents([.yearForWeekOfYear, .weekOfYear], from: date))!
    }
}

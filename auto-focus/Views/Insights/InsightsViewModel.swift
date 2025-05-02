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
        if selectedTimeframe == .day {
            return dataProvider.dateString(for: selectedDate)
        } else {
            return "Last Week"
        }
    }
    
    var totalFocusTime: TimeInterval {
        dataProvider.totalFocusTime(timeframe: selectedTimeframe, selectedDate: selectedDate)
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
    
    func navigateDay(forward: Bool) {
        let calendar = Calendar.current
        if forward {
            selectedDate = calendar.date(byAdding: .day, value: 1, to: selectedDate) ?? selectedDate
        } else {
            selectedDate = calendar.date(byAdding: .day, value: -1, to: selectedDate) ?? selectedDate
        }
    }
    
    func navigateWeek(forward: Bool) {
        let calendar = Calendar.current
        if forward {
            selectedDate = calendar.date(byAdding: .day, value: 7, to: selectedDate) ?? selectedDate
        } else {
            selectedDate = calendar.date(byAdding: .day, value: -7, to: selectedDate) ?? selectedDate
        }
    }
    
    func goToToday() {
        selectedTimeframe = .day
        selectedDate = Date()
    }
}

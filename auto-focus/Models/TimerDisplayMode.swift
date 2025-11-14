import Foundation

enum TimerDisplayMode: String, CaseIterable, Codable {
    case hidden = "hidden"
    case full = "full"
    case simplified = "simplified"
    
    var displayName: String {
        switch self {
        case .hidden:
            return "Hidden"
        case .full:
            return "Full (00:00)"
        case .simplified:
            return "Simplified (0m)"
        }
    }
    
    var description: String {
        switch self {
        case .hidden:
            return "Don't show timer in menu bar"
        case .full:
            return "Show timer with seconds (e.g. 12:34)"
        case .simplified:
            return "Show timer in minutes only (e.g. 12m)"
        }
    }
}
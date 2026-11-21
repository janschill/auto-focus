import SwiftUI

/// How each flow state is shown in the menu bar, the menu, and insights.
extension FlowState {
    var title: String {
        switch self {
        case .flow: return "Flow"
        case .focused: return "Focused"
        case .scattered: return "Scattered"
        case .neutral: return "Calm"
        }
    }

    var systemImage: String {
        switch self {
        case .flow: return "water.waves"
        case .focused: return "scope"
        case .scattered: return "wind"
        case .neutral: return "circle.dotted"
        }
    }

    var color: Color {
        switch self {
        case .flow: return .indigo
        case .focused: return .blue
        case .scattered: return .orange
        case .neutral: return .secondary
        }
    }

    /// Whether the state is worth a glyph in the menu bar; the in-between states stay quiet.
    var showsInMenuBar: Bool {
        self == .flow || self == .scattered
    }
}

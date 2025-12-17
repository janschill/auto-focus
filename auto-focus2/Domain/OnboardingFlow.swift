import Foundation

public enum OnboardingStep: String, Codable, Hashable, Sendable {
    case permissions
    case shortcut
    case license
    case configuration
    case done
}

public struct OnboardingState: Codable, Hashable, Sendable {
    public var step: OnboardingStep
    public var hasPermissions: Bool
    public var hasShortcutConfigured: Bool
    public var hasCompletedConfiguration: Bool

    public init(
        step: OnboardingStep = .permissions,
        hasPermissions: Bool = false,
        hasShortcutConfigured: Bool = false,
        hasCompletedConfiguration: Bool = false
    ) {
        self.step = step
        self.hasPermissions = hasPermissions
        self.hasShortcutConfigured = hasShortcutConfigured
        self.hasCompletedConfiguration = hasCompletedConfiguration
    }
}

public enum OnboardingEvent: Sendable {
    case permissionsGranted(Bool)
    case shortcutConfigured(Bool)
    case configurationCompleted(Bool)
    case next
    case back
}

/// Pure onboarding state machine. UI can drive it and render based on `state.step`.
public enum OnboardingFlow {
    public static func reduce(_ state: OnboardingState, event: OnboardingEvent) -> OnboardingState {
        var next = state

        switch event {
        case .permissionsGranted(let granted):
            next.hasPermissions = granted
            if granted && next.step == .permissions {
                next.step = .shortcut
            }

        case .shortcutConfigured(let configured):
            next.hasShortcutConfigured = configured
            if configured && next.step == .shortcut {
                next.step = .license
            }

        case .configurationCompleted(let completed):
            next.hasCompletedConfiguration = completed
            if completed && next.step == .configuration {
                next.step = .done
            }

        case .next:
            next.step = advance(from: next.step, state: next)

        case .back:
            next.step = retreat(from: next.step)
        }

        // If prerequisites not met, clamp to earliest required step.
        if !next.hasPermissions { next.step = .permissions }
        else if !next.hasShortcutConfigured { next.step = .shortcut }
        else if next.step == .done && !next.hasCompletedConfiguration { next.step = .configuration }

        return next
    }

    private static func advance(from step: OnboardingStep, state: OnboardingState) -> OnboardingStep {
        switch step {
        case .permissions: return state.hasPermissions ? .shortcut : .permissions
        case .shortcut: return state.hasShortcutConfigured ? .license : .shortcut
        case .license: return .configuration
        case .configuration: return state.hasCompletedConfiguration ? .done : .configuration
        case .done: return .done
        }
    }

    private static func retreat(from step: OnboardingStep) -> OnboardingStep {
        switch step {
        case .permissions: return .permissions
        case .shortcut: return .permissions
        case .license: return .shortcut
        case .configuration: return .license
        case .done: return .configuration
        }
    }
}



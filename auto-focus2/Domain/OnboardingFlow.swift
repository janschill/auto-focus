import Foundation

public enum OnboardingStep: String, Codable, Hashable, Sendable {
    case permissions
    case license
    case apps
    case domains
    case done
}

public struct OnboardingState: Codable, Hashable, Sendable {
    public var step: OnboardingStep
    public var hasPermissions: Bool
    public var hasAddedApps: Bool
    public var hasAddedDomains: Bool

    public init(
        step: OnboardingStep = .permissions,
        hasPermissions: Bool = false,
        hasAddedApps: Bool = false,
        hasAddedDomains: Bool = false
    ) {
        self.step = step
        self.hasPermissions = hasPermissions
        self.hasAddedApps = hasAddedApps
        self.hasAddedDomains = hasAddedDomains
    }
}

public enum OnboardingEvent: Sendable {
    case permissionsGranted(Bool)
    case appsAdded(Bool)
    case domainsAdded(Bool)
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
                next.step = .license
            }

        case .appsAdded(let added):
            next.hasAddedApps = added
            if added && next.step == .apps {
                next.step = .domains
            }

        case .domainsAdded(let added):
            next.hasAddedDomains = added
            if added && next.step == .domains {
                next.step = .done
            }

        case .next:
            next.step = advance(from: next.step, state: next)

        case .back:
            next.step = retreat(from: next.step)
        }

        // If prerequisites not met, clamp to earliest required step.
        if !next.hasPermissions { next.step = .permissions }

        return next
    }

    private static func advance(from step: OnboardingStep, state: OnboardingState) -> OnboardingStep {
        switch step {
        case .permissions: return state.hasPermissions ? .license : .permissions
        case .license: return .apps
        case .apps: return .domains
        case .domains: return .done
        case .done: return .done
        }
    }

    private static func retreat(from step: OnboardingStep) -> OnboardingStep {
        switch step {
        case .permissions: return .permissions
        case .license: return .permissions
        case .apps: return .license
        case .domains: return .apps
        case .done: return .domains
        }
    }
}



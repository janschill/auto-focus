import SwiftUI

enum OnboardingStep: Int, CaseIterable {
    case welcome = 0
    case howItWorks = 1
    case installShortcut = 2
    case addFocusApps = 3
    case browserIntegration = 4
    case slackIntegration = 5
    case license = 6
    case complete = 7

    var title: String {
        switch self {
        case .welcome:
            return "Welcome to Auto-Focus"
        case .howItWorks:
            return "How Auto-Focus Works"
        case .installShortcut:
            return "Install Shortcut"
        case .addFocusApps:
            return "Add Focus Apps"
        case .browserIntegration:
            return "Browser Integration"
        case .slackIntegration:
            return "Slack Integration"
        case .license:
            return "Get Auto-Focus+"
        case .complete:
            return "You're All Set!"
        }
    }
}

struct OnboardingView: View {
    @EnvironmentObject var focusManager: FocusManager
    @EnvironmentObject var licenseManager: LicenseManager
    @State private var currentStep: OnboardingStep = .welcome
    @State private var hasInstalledShortcut: Bool = false
    @State private var hasAddedApps: Bool = false
    @State private var hasSetupBrowser: Bool = false
    @State private var hasSetupSlack: Bool = false
    
    // Helper to determine which steps are available
    private var availableSteps: [OnboardingStep] {
        var steps: [OnboardingStep] = [.welcome, .howItWorks]
        
        // Add shortcut step only if system DND is enabled
        if focusManager.isSystemDNDEnabled {
            steps.append(.installShortcut)
        }
        
        steps.append(contentsOf: [.addFocusApps, .browserIntegration, .slackIntegration, .license, .complete])
        return steps
    }

    var body: some View {
        VStack(spacing: 0) {
            // Progress indicator
            ProgressIndicatorView(currentStep: currentStep, availableSteps: availableSteps)
                .padding(.top, 20)
                .padding(.bottom, 30)

            // Content area
            ScrollView {
                VStack(spacing: 30) {
                    stepContent
                        .padding(.horizontal, 40)
                        .frame(maxWidth: .infinity)
                }
                .padding(.bottom, 30)
            }

            // Navigation buttons
            NavigationButtonsView(
                currentStep: $currentStep,
                hasInstalledShortcut: $hasInstalledShortcut,
                hasAddedApps: $hasAddedApps,
                hasSetupBrowser: $hasSetupBrowser,
                hasSetupSlack: $hasSetupSlack
            )
            .padding(.horizontal, 40)
            .padding(.bottom, 30)
        }
        .frame(width: 600, height: 700)
        .onAppear {
            hasInstalledShortcut = focusManager.isShortcutInstalled
            hasAddedApps = !focusManager.focusApps.isEmpty
            hasSetupBrowser = !focusManager.focusURLs.isEmpty
            hasSetupSlack = focusManager.slackIntegration.connectedWorkspaceCount > 0
        }
    }

    @ViewBuilder
    private var stepContent: some View {
        switch currentStep {
        case .welcome:
            WelcomeStepView()
        case .howItWorks:
            HowItWorksStepView()
        case .installShortcut:
            InstallShortcutStepView(hasInstalled: $hasInstalledShortcut)
        case .addFocusApps:
            AddFocusAppsStepView(hasAddedApps: $hasAddedApps)
        case .browserIntegration:
            BrowserIntegrationStepView(hasSetupBrowser: $hasSetupBrowser)
        case .slackIntegration:
            SlackIntegrationStepView(hasSetupSlack: $hasSetupSlack)
        case .license:
            LicenseOnboardingStepView()
        case .complete:
            CompleteStepView()
        }
    }
}

struct ProgressIndicatorView: View {
    let currentStep: OnboardingStep
    let availableSteps: [OnboardingStep]

    var body: some View {
        HStack(spacing: 20) {
            ForEach(Array(availableSteps.enumerated()), id: \.offset) { index, step in
                HStack(spacing: 8) {
                    Circle()
                        .fill(availableSteps.firstIndex(of: step) ?? 0 <= availableSteps.firstIndex(of: currentStep) ?? 0 ? Color.accentColor : Color.gray.opacity(0.3))
                        .frame(width: 12, height: 12)

                    if index < availableSteps.count - 1 {
                        Rectangle()
                            .fill(index < availableSteps.firstIndex(of: currentStep) ?? 0 ? Color.accentColor : Color.gray.opacity(0.3))
                            .frame(width: 40, height: 2)
                    }
                }
            }
        }
    }
}

struct WelcomeStepView: View {
    var body: some View {
        VStack(spacing: 24) {
            Image(systemName: "brain.head.profile.fill")
                .font(.system(size: 80))
                .foregroundColor(.accentColor)

            VStack(spacing: 16) {
                Text("Welcome to Auto-Focus")
                    .font(.largeTitle)
                    .fontWeight(.bold)

                Text("Auto-Focus helps you maintain deep focus by automatically detecting when you're using your focus applications and blocking distracting notifications.")
                    .font(.title3)
                    .multilineTextAlignment(.center)
                    .foregroundColor(.secondary)
                    .lineLimit(nil)
            }

            VStack(spacing: 12) {
                FeatureRow(icon: "app.badge", text: "Automatically detects focus apps")
                FeatureRow(icon: "globe", text: "Track focus time on websites")
                FeatureRow(icon: "bell.slash", text: "Blocks notifications during focus")
                FeatureRow(icon: "bubble.left.and.bubble.right", text: "Slack status and DND sync")
                FeatureRow(icon: "chart.bar", text: "Tracks your focus sessions")
                FeatureRow(icon: "timer", text: "Customizable focus thresholds")
            }
            .padding(.top, 20)
        }
    }
}

struct FeatureRow: View {
    let icon: String
    let text: String

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.title3)
                .foregroundColor(.accentColor)
                .frame(width: 24)

            Text(text)
                .font(.body)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}

struct HowItWorksStepView: View {
    var body: some View {
        VStack(spacing: 24) {
            Image(systemName: "gearshape.2.fill")
                .font(.system(size: 60))
                .foregroundColor(.accentColor)

            VStack(spacing: 16) {
                Text("How Auto-Focus Works")
                    .font(.largeTitle)
                    .fontWeight(.bold)

                Text("Auto-Focus monitors your computer usage and automatically enters focus mode when you're working in your designated focus applications or websites. Each integration can be enabled or disabled independently.")
                    .font(.title3)
                    .multilineTextAlignment(.center)
                    .foregroundColor(.secondary)
            }

            VStack(spacing: 20) {
                WorkflowStep(number: 1, title: "You open a focus app", description: "Auto-Focus detects when you start using an app you've designated for focused work")

                WorkflowStep(number: 2, title: "Focus timer begins", description: "A timer starts counting how long you've been using the focus app")

                WorkflowStep(number: 3, title: "Focus mode activates", description: "After reaching your threshold (default: 12 minutes), notifications are automatically blocked")

                WorkflowStep(number: 4, title: "Stay focused", description: "Work distraction-free until you switch away from your focus apps")
            }
        }
    }
}

struct WorkflowStep: View {
    let number: Int
    let title: String
    let description: String

    var body: some View {
        HStack(alignment: .top, spacing: 16) {
            Circle()
                .fill(Color.accentColor)
                .frame(width: 32, height: 32)
                .overlay(
                    Text("\(number)")
                        .font(.headline)
                        .fontWeight(.bold)
                        .foregroundColor(.white)
                )

            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.headline)
                    .fontWeight(.semibold)

                Text(description)
                    .font(.body)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.leading)
            }

            Spacer()
        }
        .frame(maxWidth: .infinity)
    }
}

struct InstallShortcutStepView: View {
    @EnvironmentObject var focusManager: FocusManager
    @Binding var hasInstalled: Bool

    var body: some View {
        VStack(spacing: 24) {
            Image(systemName: hasInstalled ? "checkmark.circle.fill" : "exclamationmark.triangle")
                .font(.system(size: 60))
                .foregroundColor(hasInstalled ? .green : .orange)

            VStack(spacing: 16) {
                Text("Install Shortcut")
                    .font(.largeTitle)
                    .fontWeight(.bold)

                Text("Auto-Focus will install a system shortcut to control macOS Do Not Disturb mode. This is required for blocking system notifications during focus sessions.")
                    .font(.title3)
                    .multilineTextAlignment(.center)
                    .foregroundColor(.secondary)
            }

            VStack(spacing: 16) {
                HStack {
                    Image(systemName: hasInstalled ? "checkmark.circle.fill" : "circle")
                        .foregroundColor(hasInstalled ? .green : .gray)

                    Text(hasInstalled ? "Shortcut is installed!" : "Shortcut not installed")
                        .font(.headline)
                        .foregroundColor(hasInstalled ? .green : .primary)

                    Spacer()
                }

                if !hasInstalled {
                    Button("Install Shortcut") {
                        installShortcut()
                        // Use Task for proper async handling without forcing view updates
                        Task {
                            try await Task.sleep(nanoseconds: 1_000_000_000) // 1 second
                            await MainActor.run {
                                focusManager.refreshShortcutStatus()
                                hasInstalled = focusManager.isShortcutInstalled
                            }
                        }
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.large)
                }

                Text("Note: You'll be prompted to add the shortcut to your Shortcuts app. This allows Auto-Focus to toggle Do Not Disturb mode automatically.")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.top, 8)
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 20)
            .background(Color(.controlBackgroundColor))
            .cornerRadius(12)
        }
    }
}

struct AddFocusAppsStepView: View {
    @EnvironmentObject var focusManager: FocusManager
    @Binding var hasAddedApps: Bool

    var body: some View {
        VStack(spacing: 24) {
            Image(systemName: hasAddedApps ? "checkmark.circle.fill" : "plus.app")
                .font(.system(size: 60))
                .foregroundColor(hasAddedApps ? .green : .accentColor)

            VStack(spacing: 16) {
                Text("Add Focus Apps")
                    .font(.largeTitle)
                    .fontWeight(.bold)

                Text("Choose the applications where you do your most focused work. Auto-Focus will monitor these apps and activate focus mode when you use them. You can configure focus apps in the dedicated Focus Apps tab.")
                    .font(.title3)
                    .multilineTextAlignment(.center)
                    .foregroundColor(.secondary)
            }

            VStack(spacing: 16) {
                HStack {
                    Image(systemName: hasAddedApps ? "checkmark.circle.fill" : "circle")
                        .foregroundColor(hasAddedApps ? .green : .gray)

                    Text(hasAddedApps ? "\(focusManager.focusApps.count) focus app(s) added" : "No focus apps added yet")
                        .font(.headline)
                        .foregroundColor(hasAddedApps ? .green : .primary)

                    Spacer()
                }

                if !focusManager.focusApps.isEmpty {
                    VStack(alignment: .leading, spacing: 8) {
                        ForEach(focusManager.focusApps.prefix(3)) { app in
                            HStack {
                                Image(systemName: "app")
                                    .foregroundColor(.accentColor)
                                Text(app.name)
                                    .font(.body)
                                Spacer()
                            }
                        }

                        if focusManager.focusApps.count > 3 {
                            Text("... and \(focusManager.focusApps.count - 3) more")
                                .font(.caption)
                                .foregroundColor(.secondary)
                                .padding(.leading, 24)
                        }
                    }
                    .padding(.top, 8)
                }

                Button(hasAddedApps ? "Add More Apps" : "Add Focus Apps") {
                    focusManager.selectFocusApplication()
                    // Use Task for proper async handling
                    Task {
                        try await Task.sleep(nanoseconds: 500_000_000) // 0.5 seconds
                        await MainActor.run {
                            hasAddedApps = !focusManager.focusApps.isEmpty
                        }
                    }
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)

                VStack(spacing: 8) {
                    Text("Recommended focus apps:")
                        .font(.caption)
                        .fontWeight(.semibold)
                        .foregroundColor(.secondary)

                    HStack(spacing: 12) {
                        RecommendedAppTag(name: "Xcode")
                        RecommendedAppTag(name: "VS Code")
                        RecommendedAppTag(name: "Figma")
                        RecommendedAppTag(name: "Notion")
                    }
                }
                .padding(.top, 12)
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 20)
            .background(Color(.controlBackgroundColor))
            .cornerRadius(12)
        }
    }
}

struct RecommendedAppTag: View {
    let name: String

    var body: some View {
        Text(name)
            .font(.caption)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(Color.accentColor.opacity(0.1))
            .foregroundColor(.accentColor)
            .cornerRadius(6)
    }
}

struct BrowserIntegrationStepView: View {
    @EnvironmentObject var focusManager: FocusManager
    @EnvironmentObject var licenseManager: LicenseManager
    @Binding var hasSetupBrowser: Bool
    @State private var showingBrowserConfig = false
    @State private var hasInstalledExtension = false

    var body: some View {
        VStack(spacing: 24) {
            Image(systemName: hasSetupBrowser && hasInstalledExtension ? "checkmark.circle.fill" : "globe")
                .font(.system(size: 60))
                .foregroundColor(hasSetupBrowser && hasInstalledExtension ? .green : .accentColor)

            VStack(spacing: 16) {
                Text("Browser Integration")
                    .font(.largeTitle)
                    .fontWeight(.bold)

                Text("Track focus time on websites like GitHub, Notion, Google Docs, and more. Install the browser extension and configure your focus websites.")
                    .font(.title3)
                    .multilineTextAlignment(.center)
                    .foregroundColor(.secondary)
            }

            VStack(spacing: 20) {
                // Extension installation status
                GroupBox {
                    VStack(spacing: 12) {
                        HStack {
                            Image(systemName: hasInstalledExtension ? "checkmark.circle.fill" : "circle")
                                .foregroundColor(hasInstalledExtension ? .green : .gray)
                            
                            Text(hasInstalledExtension ? "Chrome extension installed" : "Chrome extension not installed")
                                .font(.headline)
                                .foregroundColor(hasInstalledExtension ? .green : .primary)
                            
                            Spacer()
                        }
                        
                        if !hasInstalledExtension {
                            Button("Install Extension") {
                                if let url = URL(string: "https://chromewebstore.google.com/detail/ncmjhohihnjjmkfpcibbafakmlbfifih") {
                                    NSWorkspace.shared.open(url)
                                    // Give user time to install before marking as complete
                                    Task {
                                        try await Task.sleep(nanoseconds: 5_000_000_000) // 5 seconds
                                        await MainActor.run {
                                            hasInstalledExtension = true
                                        }
                                    }
                                }
                            }
                            .buttonStyle(.borderedProminent)
                            .controlSize(.regular)
                        }
                        
                        Text("The extension enables Auto-Focus to monitor your browser tabs and track time on focus websites.")
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                    }
                    .padding()
                }
                
                // Website configuration status
                GroupBox {
                    VStack(spacing: 12) {
                        HStack {
                            Image(systemName: hasSetupBrowser ? "checkmark.circle.fill" : "circle")
                                .foregroundColor(hasSetupBrowser ? .green : .gray)

                            Text(hasSetupBrowser ? browserStatusText : "No focus websites configured")
                                .font(.headline)
                                .foregroundColor(hasSetupBrowser ? .green : .primary)

                            Spacer()
                        }

                        if !focusManager.focusURLs.isEmpty {
                            VStack(alignment: .leading, spacing: 8) {
                                ForEach(focusManager.focusURLs.prefix(3)) { url in
                                    HStack {
                                        Image(systemName: "globe")
                                            .foregroundColor(.accentColor)
                                        Text(url.name)
                                            .font(.body)
                                        Spacer()
                                    }
                                }

                                if focusManager.focusURLs.count > 3 {
                                    Text("... and \(focusManager.focusURLs.count - 3) more")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                        .padding(.leading, 24)
                                }
                            }
                            .padding(.top, 8)
                        }

                        Button(hasSetupBrowser ? "Configure More Websites" : "Configure Focus Websites") {
                            showingBrowserConfig = true
                        }
                        .buttonStyle(.borderedProminent)
                        .controlSize(.regular)

                        if !licenseManager.isLicensed {
                            HStack {
                                Image(systemName: "info.circle")
                                    .foregroundColor(.blue)
                                Text("Free tier: 3 focus websites • Auto-Focus+ unlocks unlimited websites")
                                    .font(.caption)
                                    .foregroundColor(.blue)
                            }
                            .padding(.horizontal, 12)
                            .padding(.vertical, 8)
                            .background(Color.blue.opacity(0.1))
                            .cornerRadius(8)
                        }
                    }
                    .padding()
                }
            }
        }
        .onAppear {
            // Check if extension is connected
            hasInstalledExtension = focusManager.isExtensionConnected
        }
        .sheet(isPresented: $showingBrowserConfig) {
            OnboardingBrowserConfigSheet(hasSetupBrowser: $hasSetupBrowser)
                .frame(minWidth: 700, minHeight: 600)
        }
    }

    private var browserStatusText: String {
        if !focusManager.focusURLs.isEmpty {
            return "\(focusManager.focusURLs.count) website(s) configured"
        } else {
            return "Ready to configure"
        }
    }
}

struct RecommendedWebsiteTag: View {
    let name: String

    var body: some View {
        Text(name)
            .font(.caption)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(Color.accentColor.opacity(0.1))
            .foregroundColor(.accentColor)
            .cornerRadius(6)
    }
}

struct SlackIntegrationStepView: View {
    @EnvironmentObject var focusManager: FocusManager
    @Binding var hasSetupSlack: Bool
    @State private var showingSlackSetup = false
    
    var body: some View {
        VStack(spacing: 24) {
            Image(systemName: hasSetupSlack ? "checkmark.circle.fill" : "bubble.left.and.bubble.right")
                .font(.system(size: 60))
                .foregroundColor(hasSetupSlack ? .green : .accentColor)
            
            VStack(spacing: 16) {
                Text("Slack Integration")
                    .font(.largeTitle)
                    .fontWeight(.bold)
                
                Text("Connect your Slack workspace to automatically update your status and enable Do Not Disturb during focus sessions. Keep your team informed while you focus.")
                    .font(.title3)
                    .multilineTextAlignment(.center)
                    .foregroundColor(.secondary)
            }
            
            VStack(spacing: 16) {
                HStack {
                    Image(systemName: hasSetupSlack ? "checkmark.circle.fill" : "circle")
                        .foregroundColor(hasSetupSlack ? .green : .gray)
                    
                    Text(hasSetupSlack ? slackStatusText : "No Slack workspace connected")
                        .font(.headline)
                        .foregroundColor(hasSetupSlack ? .green : .primary)
                    
                    Spacer()
                }
                
                if hasSetupSlack {
                    VStack(alignment: .leading, spacing: 8) {
                        let workspaces = focusManager.slackIntegration.workspaceManager.connectedWorkspaces
                        ForEach(workspaces.prefix(3)) { workspace in
                            HStack {
                                Image(systemName: "building.2")
                                    .foregroundColor(.accentColor)
                                Text(workspace.name)
                                    .font(.body)
                                Spacer()
                            }
                        }
                        
                        if workspaces.count > 3 {
                            Text("... and \(workspaces.count - 3) more")
                                .font(.caption)
                                .foregroundColor(.secondary)
                                .padding(.leading, 24)
                        }
                    }
                    .padding(.top, 8)
                }
                
                Button(hasSetupSlack ? "Manage Workspaces" : "Connect Slack") {
                    showingSlackSetup = true
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                
                VStack(spacing: 12) {
                    Text("Slack integration features:")
                        .font(.caption)
                        .fontWeight(.semibold)
                        .foregroundColor(.secondary)
                    
                    VStack(alignment: .leading, spacing: 8) {
                        SlackFeatureRow(icon: "pencil.circle", text: "Custom focus status")
                        SlackFeatureRow(icon: "bell.slash", text: "Auto-enable Do Not Disturb")
                        SlackFeatureRow(icon: "building.2", text: "Multiple workspace support")
                        SlackFeatureRow(icon: "arrow.triangle.2.circlepath", text: "Automatic status clearing")
                    }
                }
                .padding(.top, 8)
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 20)
            .background(Color(.controlBackgroundColor))
            .cornerRadius(12)
        }
        .sheet(isPresented: $showingSlackSetup) {
            OnboardingSlackSetupSheet(hasSetupSlack: $hasSetupSlack)
                .frame(minWidth: 600, minHeight: 500)
        }
    }
    
    private var slackStatusText: String {
        let count = focusManager.slackIntegration.connectedWorkspaceCount
        if count == 1 {
            return "1 workspace connected"
        } else {
            return "\(count) workspaces connected"
        }
    }
}

struct SlackFeatureRow: View {
    let icon: String
    let text: String
    
    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: icon)
                .foregroundColor(.accentColor)
                .frame(width: 16)
            Text(text)
                .font(.caption)
                .foregroundColor(.primary)
        }
    }
}

struct CompleteStepView: View {
    @EnvironmentObject var focusManager: FocusManager

    var body: some View {
        VStack(spacing: 24) {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 80))
                .foregroundColor(.green)

            VStack(spacing: 16) {
                Text("You're All Set!")
                    .font(.largeTitle)
                    .fontWeight(.bold)

                Text("Auto-Focus is now configured and ready to help you maintain deep focus. Start using your focus apps and let Auto-Focus handle the rest.")
                    .font(.title3)
                    .multilineTextAlignment(.center)
                    .foregroundColor(.secondary)
            }

            VStack(spacing: 16) {
                if focusManager.isSystemDNDEnabled {
                    CompletionRow(icon: "checkmark.circle.fill", text: "Shortcut installed", isComplete: focusManager.isShortcutInstalled)
                }
                CompletionRow(icon: "checkmark.circle.fill", text: "Focus apps configured", isComplete: !focusManager.focusApps.isEmpty)
                CompletionRow(icon: "checkmark.circle.fill", text: "Browser extension installed", isComplete: focusManager.isExtensionConnected)
                CompletionRow(icon: "checkmark.circle.fill", text: "Focus websites configured", isComplete: !focusManager.focusURLs.isEmpty)
                CompletionRow(icon: "checkmark.circle.fill", text: "Slack integration connected", isComplete: focusManager.slackIntegration.connectedWorkspaceCount > 0)

                Divider()
                    .padding(.vertical, 8)

                VStack(spacing: 12) {
                    Text("Next steps:")
                        .font(.headline)
                        .fontWeight(.semibold)

                    NextStepRow(icon: "gearshape", text: "Fine-tune your settings in the General tab")
                    NextStepRow(icon: "chart.bar", text: "View your focus insights in the Insights tab")
                    NextStepRow(icon: "star.circle", text: "Explore premium features in Auto-Focus+ tab")
                    NextStepRow(icon: "brain.head.profile", text: "Start focusing!")
                }
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 20)
            .background(Color(.controlBackgroundColor))
            .cornerRadius(12)
        }
    }
}

struct CompletionRow: View {
    let icon: String
    let text: String
    let isComplete: Bool

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .foregroundColor(isComplete ? .green : .gray)

            Text(text)
                .font(.body)
                .foregroundColor(isComplete ? .primary : .secondary)

            Spacer()
        }
    }
}

struct NextStepRow: View {
    let icon: String
    let text: String

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .foregroundColor(.accentColor)
                .frame(width: 16)

            Text(text)
                .font(.body)

            Spacer()
        }
    }
}

struct NavigationButtonsView: View {
    @EnvironmentObject var focusManager: FocusManager
    @Binding var currentStep: OnboardingStep
    @Binding var hasInstalledShortcut: Bool
    @Binding var hasAddedApps: Bool
    @Binding var hasSetupBrowser: Bool
    @Binding var hasSetupSlack: Bool
    
    // Helper to determine which steps are available
    private var availableSteps: [OnboardingStep] {
        var steps: [OnboardingStep] = [.welcome, .howItWorks]
        
        // Add shortcut step only if system DND is enabled
        if focusManager.isSystemDNDEnabled {
            steps.append(.installShortcut)
        }
        
        steps.append(contentsOf: [.addFocusApps, .browserIntegration, .slackIntegration, .license, .complete])
        return steps
    }

    private var canProceed: Bool {
        switch currentStep {
        case .installShortcut:
            return hasInstalledShortcut
        case .addFocusApps:
            return hasAddedApps
        case .browserIntegration:
            return true // Optional step, can always proceed
        case .slackIntegration:
            return true // Optional step, can always proceed
        default:
            return true
        }
    }

    private var isLastStep: Bool {
        currentStep == .complete
    }
    
    private var currentStepIndex: Int {
        availableSteps.firstIndex(of: currentStep) ?? 0
    }

    var body: some View {
        HStack {
            if currentStep != .welcome {
                Button("Back") {
                    withAnimation(.easeInOut(duration: 0.3)) {
                        let currentIndex = currentStepIndex
                        if currentIndex > 0 {
                            currentStep = availableSteps[currentIndex - 1]
                        }
                    }
                }
                .buttonStyle(.bordered)
            }

            Spacer()

            Button(isLastStep ? "Get Started" : "Continue") {
                if isLastStep {
                    focusManager.completeOnboarding()
                } else {
                    withAnimation(.easeInOut(duration: 0.3)) {
                        let currentIndex = currentStepIndex
                        if currentIndex < availableSteps.count - 1 {
                            currentStep = availableSteps[currentIndex + 1]
                        }
                    }
                }
            }
            .buttonStyle(.borderedProminent)
            .disabled(!canProceed)
        }
    }
}

struct LicenseOnboardingStepView: View {
    @EnvironmentObject var licenseManager: LicenseManager

    var body: some View {
        VStack(spacing: 24) {
            Image(systemName: "star.circle.fill")
                .font(.system(size: 60))
                .foregroundColor(.accentColor)

            VStack(spacing: 16) {
                Text("Get Auto-Focus+")
                    .font(.largeTitle)
                    .fontWeight(.bold)

                Text("Unlock unlimited focus apps, data export, and advanced insights. Currently in open beta - all features are free until August 31, 2025.")
                    .font(.title3)
                    .multilineTextAlignment(.center)
                    .foregroundColor(.secondary)
            }

            VStack(spacing: 20) {
                VStack(spacing: 12) {
                    Text("Premium Features")
                        .font(.headline)
                        .fontWeight(.semibold)

                    VStack(spacing: 10) {
                        OnboardingPremiumFeature(icon: "list.bullet", title: "Unlimited Focus Apps", description: "Add as many focus-triggering apps as you need")
                        OnboardingPremiumFeature(icon: "globe", title: "Unlimited Focus Websites", description: "Track unlimited websites with browser integration")
                        OnboardingPremiumFeature(icon: "externaldrive", title: "Data Export & Import", description: "Backup and transfer your focus data")
                        OnboardingPremiumFeature(icon: "chart.bar.fill", title: "Advanced Insights", description: "Detailed statistics about your focus habits")
                        OnboardingPremiumFeature(icon: "arrow.clockwise", title: "Future Updates", description: "Access to all new premium features")
                    }
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 16)
                .background(Color(.controlBackgroundColor))
                .cornerRadius(12)

                VStack(spacing: 16) {
                    Text("🎉 Open Beta")
                        .font(.headline)
                        .fontWeight(.bold)

                    Text("All premium features are currently free during our open beta period. After August 31, 2025, you'll need a license to continue using premium features.")
                        .font(.body)
                        .multilineTextAlignment(.center)
                        .foregroundColor(.secondary)

                    VStack(spacing: 12) {
                        Link(destination: URL(string: "https://auto-focus.app/plus")!) {
                            HStack {
                                Text("Get Auto-Focus+ License")
                                    .fontWeight(.medium)
                                Image(systemName: "arrow.up.forward.app")
                            }
                            .foregroundColor(.white)
                            .padding(.horizontal, 24)
                            .padding(.vertical, 12)
                            .background(Color.accentColor)
                            .cornerRadius(8)
                        }
                        .buttonStyle(.plain)

                        Text("OR")
                            .font(.caption)
                            .foregroundColor(.secondary)

                        OnboardingLicenseInputView()
                    }
                }
            }
        }
    }
}

struct OnboardingPremiumFeature: View {
    let icon: String
    let title: String
    let description: String

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: icon)
                .foregroundColor(.accentColor)
                .frame(width: 20, height: 20)

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.body)
                    .fontWeight(.medium)
                Text(description)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer()
        }
    }
}

struct OnboardingLicenseInputView: View {
    @EnvironmentObject var licenseManager: LicenseManager
    @State private var licenseInput: String = ""
    @State private var showingSuccess = false

    var body: some View {
        VStack(spacing: 12) {
            TextField("Enter License Key (Optional)", text: $licenseInput)
                .textFieldStyle(RoundedBorderTextFieldStyle())
                .frame(maxWidth: 300)

            if let error = licenseManager.validationError {
                Text(error)
                    .foregroundColor(.red)
                    .font(.caption)
            }

            if showingSuccess {
                HStack {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(.green)
                    Text("License activated successfully!")
                        .foregroundColor(.green)
                        .font(.caption)
                }
                .transition(.opacity)
            }

            if !licenseInput.isEmpty {
                Button(action: {
                    licenseManager.licenseKey = licenseInput
                    licenseManager.activateLicense()
                }) {
                    if licenseManager.isActivating {
                        HStack {
                            ProgressView()
                                .progressViewStyle(CircularProgressViewStyle())
                                .scaleEffect(0.8)
                            Text("Activating...")
                        }
                    } else {
                        Text("Activate License")
                    }
                }
                .disabled(licenseInput.count < 8 || licenseManager.isActivating)
                .buttonStyle(.bordered)
                .onChange(of: licenseManager.licenseStatus) { status in
                    if status == .valid && !licenseInput.isEmpty {
                        withAnimation {
                            showingSuccess = true
                        }
                        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                            withAnimation {
                                showingSuccess = false
                            }
                        }
                    }
                }
            }

            Text("You can also add your license later in the Auto-Focus+ tab")
                .font(.caption)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
    }
}

struct OnboardingBrowserConfigSheet: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var focusManager: FocusManager
    @EnvironmentObject var licenseManager: LicenseManager
    @Binding var hasSetupBrowser: Bool
    @State private var showingAddURLOptions = false
    @State private var showingAddURL = false
    @State private var showingPresets = false
    @State private var newURL = FocusURL(name: "", domain: "")
    @State private var selectedCategory: URLCategory = .work
    @State private var selectedURLId: UUID?

    var body: some View {
        NavigationView {
            VStack(spacing: 20) {
                // Focus URLs Management only
                GroupBox(label: Text("Add Focus URL").font(.headline)) {
                    VStack(alignment: .leading, spacing: 16) {
                        Text("Being on any of these websites will automatically activate focus mode.")
                            .font(.callout)
                            .foregroundColor(.secondary)

                        // Current URLs list
                        if !focusManager.focusURLs.isEmpty {
                            VStack(alignment: .leading, spacing: 8) {
                                Text("Current Focus URLs:")
                                    .font(.subheadline)
                                    .fontWeight(.medium)

                                ForEach(focusManager.focusURLs.prefix(5)) { url in
                                    HStack {
                                        Image(systemName: "globe")
                                            .foregroundColor(.blue)
                                            .frame(width: 16)
                                        Text(url.name)
                                            .font(.body)
                                        Spacer()
                                    }
                                }

                                if focusManager.focusURLs.count > 5 {
                                    Text("... and \(focusManager.focusURLs.count - 5) more")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                            }
                            .padding(.vertical, 8)
                        }

                        // Add URL options
                        VStack(spacing: 12) {
                            Button {
                                showingPresets = true
                            } label: {
                                HStack {
                                    Image(systemName: "list.bullet.rectangle")
                                        .font(.title3)
                                        .foregroundColor(.blue)

                                    VStack(alignment: .leading, spacing: 2) {
                                        Text("Choose from Presets")
                                            .font(.headline)
                                        Text("GitHub, Google Docs, Notion, and more")
                                            .font(.caption)
                                            .foregroundColor(.secondary)
                                    }

                                    Spacer()

                                    Image(systemName: "chevron.right")
                                        .foregroundColor(.secondary)
                                }
                                .padding()
                                .background(Color(.controlBackgroundColor))
                                .cornerRadius(8)
                            }
                            .buttonStyle(.plain)
                            .disabled(!focusManager.canAddMoreURLs)

                            Button {
                                showingAddURL = true
                            } label: {
                                HStack {
                                    Image(systemName: "plus.circle")
                                        .font(.title3)
                                        .foregroundColor(.green)

                                    VStack(alignment: .leading, spacing: 2) {
                                        Text("Add Custom URL")
                                            .font(.headline)
                                        Text("Enter your own domain to track")
                                            .font(.caption)
                                            .foregroundColor(.secondary)
                                    }

                                    Spacer()

                                    Image(systemName: "chevron.right")
                                        .foregroundColor(.secondary)
                                }
                                .padding()
                                .background(Color(.controlBackgroundColor))
                                .cornerRadius(8)
                            }
                            .buttonStyle(.plain)
                            .disabled(!focusManager.canAddMoreURLs)
                        }

                        // Free tier limitation
                        if !licenseManager.isLicensed {
                            HStack {
                                Image(systemName: "info.circle")
                                    .foregroundColor(.blue)
                                Text("Free tier: \(focusManager.focusURLs.count)/3 websites • Auto-Focus+ unlocks unlimited websites")
                                    .font(.caption)
                                    .foregroundColor(.blue)
                            }
                            .padding(.horizontal, 12)
                            .padding(.vertical, 8)
                            .background(Color.blue.opacity(0.1))
                            .cornerRadius(8)
                        }
                    }
                    .padding()
                }

                Spacer()
            }
            .padding()
            .navigationTitle("Configure Websites")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
        .sheet(isPresented: $showingAddURL) {
            OnboardingAddURLSheet(newURL: $newURL, selectedCategory: $selectedCategory)
                .frame(minWidth: 500, minHeight: 400)
        }
        .sheet(isPresented: $showingPresets) {
            OnboardingURLPresetsSheet()
                .frame(minWidth: 600, minHeight: 500)
        }
        .onDisappear {
            // Update status when sheet closes
            hasSetupBrowser = !focusManager.focusURLs.isEmpty
        }
    }
}

struct OnboardingAddURLSheet: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var focusManager: FocusManager
    @Binding var newURL: FocusURL
    @Binding var selectedCategory: URLCategory
    @State private var selectedMatchType: URLMatchType = .domain

    var body: some View {
        NavigationView {
            VStack(spacing: 20) {
                GroupBox("URL Information") {
                    VStack(spacing: 12) {
                        TextField("Name (e.g., 'GitHub')", text: $newURL.name)
                        TextField("Domain (e.g., 'github.com')", text: $newURL.domain)
                            .autocorrectionDisabled()
                    }
                    .padding(.vertical, 8)
                }

                GroupBox("Category") {
                    VStack(spacing: 12) {
                        Picker("Category", selection: $selectedCategory) {
                            ForEach(URLCategory.allCases, id: \.self) { category in
                                Label(category.displayName, systemImage: category.icon)
                                    .tag(category)
                            }
                        }
                        .pickerStyle(.menu)
                    }
                    .padding(.vertical, 8)
                }

                Spacer()
            }
            .padding()
            .navigationTitle("Add Custom URL")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }

                ToolbarItem(placement: .confirmationAction) {
                    Button("Add") {
                        addURL()
                    }
                    .disabled(newURL.name.isEmpty || newURL.domain.isEmpty)
                }
            }
        }
    }

    private func addURL() {
        var urlToAdd = newURL
        urlToAdd.category = selectedCategory
        urlToAdd.matchType = selectedMatchType
        urlToAdd.domain = urlToAdd.domain.lowercased()

        focusManager.addFocusURL(urlToAdd)

        // Reset form
        newURL = FocusURL(name: "", domain: "")
        selectedCategory = .work
        selectedMatchType = .domain

        dismiss()
    }
}

struct OnboardingURLPresetsSheet: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var focusManager: FocusManager
    @EnvironmentObject var licenseManager: LicenseManager
    @State private var selectedPresets: Set<UUID> = []

    var body: some View {
        NavigationView {
            List {
                ForEach(URLCategory.allCases, id: \.self) { category in
                    let presetsInCategory = focusManager.availableURLPresets.filter { $0.category == category }

                    if !presetsInCategory.isEmpty {
                        Section(category.displayName) {
                            ForEach(presetsInCategory) { preset in
                                OnboardingPresetRow(
                                    preset: preset,
                                    isSelected: selectedPresets.contains(preset.id),
                                    canSelect: !preset.isPremium || licenseManager.isLicensed,
                                    onToggle: { togglePreset(preset) }
                                )
                            }
                        }
                    }
                }
            }
            .navigationTitle("Choose Presets")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }

                ToolbarItem(placement: .confirmationAction) {
                    Button("Add Selected") {
                        addSelectedPresets()
                    }
                    .disabled(selectedPresets.isEmpty)
                }
            }
        }
    }

    private func togglePreset(_ preset: FocusURL) {
        if selectedPresets.contains(preset.id) {
            selectedPresets.remove(preset.id)
        } else {
            selectedPresets.insert(preset.id)
        }
    }

    private func addSelectedPresets() {
        let presetsToAdd = focusManager.availableURLPresets.filter { selectedPresets.contains($0.id) }
        focusManager.addPresetURLs(presetsToAdd)
        dismiss()
    }
}

struct OnboardingPresetRow: View {
    let preset: FocusURL
    let isSelected: Bool
    let canSelect: Bool
    let onToggle: () -> Void

    var body: some View {
        HStack {
            Button(action: onToggle) {
                HStack(spacing: 12) {
                    Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                        .foregroundColor(isSelected ? .blue : .gray)

                    Image(systemName: preset.category.icon)
                        .foregroundColor(.blue)
                        .frame(width: 20)

                    VStack(alignment: .leading, spacing: 2) {
                        HStack {
                            Text(preset.name)
                                .font(.headline)

                            if preset.isPremium {
                                Image(systemName: "crown.fill")
                                    .foregroundColor(.yellow)
                                    .font(.caption)
                            }
                        }

                        Text(preset.domain)
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }

                    Spacer()
                }
            }
            .buttonStyle(.plain)
            .disabled(!canSelect)
            .opacity(canSelect ? 1.0 : 0.6)
        }
    }
}

struct OnboardingSlackSetupSheet: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var focusManager: FocusManager
    @Binding var hasSetupSlack: Bool
    
    private var slackManager: SlackIntegrationManager {
        return focusManager.slackIntegration
    }
    
    var body: some View {
        NavigationView {
            VStack(spacing: 20) {
                if slackManager.connectedWorkspaceCount == 0 {
                    // Empty state
                    VStack(spacing: 24) {
                        Image(systemName: "bubble.left.and.bubble.right")
                            .font(.system(size: 60))
                            .foregroundColor(.accentColor)
                        
                        VStack(spacing: 16) {
                            Text("Connect Your Slack Workspace")
                                .font(.title2)
                                .fontWeight(.bold)
                            
                            Text("Authorize Auto-Focus to update your Slack status and enable Do Not Disturb during focus sessions.")
                                .font(.body)
                                .multilineTextAlignment(.center)
                                .foregroundColor(.secondary)
                                .padding(.horizontal, 40)
                        }
                        
                        Button {
                            slackManager.connectWorkspace()
                        } label: {
                            HStack {
                                Image(systemName: "plus.circle.fill")
                                Text("Connect Slack Workspace")
                            }
                            .fontWeight(.medium)
                        }
                        .buttonStyle(.borderedProminent)
                        .controlSize(.large)
                        .disabled(slackManager.oauthManager.isAuthenticating)
                    }
                } else {
                    // Connected workspaces
                    VStack(alignment: .leading, spacing: 16) {
                        Text("Connected Workspaces")
                            .font(.headline)
                        
                        ForEach(slackManager.workspaceManager.connectedWorkspaces) { workspace in
                            HStack {
                                Image(systemName: "building.2")
                                    .foregroundColor(.blue)
                                    .frame(width: 24, height: 24)
                                
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(workspace.name)
                                        .font(.headline)
                                    
                                    Text("Connected as \(workspace.userDisplayName)")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                                
                                Spacer()
                            }
                            .padding(.vertical, 8)
                            .padding(.horizontal)
                            .background(Color(.controlBackgroundColor))
                            .cornerRadius(8)
                        }
                        
                        Button {
                            slackManager.connectWorkspace()
                        } label: {
                            HStack {
                                Image(systemName: "plus.circle")
                                Text("Add Another Workspace")
                            }
                        }
                        .buttonStyle(.bordered)
                        .disabled(slackManager.oauthManager.isAuthenticating)
                    }
                    .padding()
                }
                
                // OAuth loading state
                if slackManager.oauthManager.isAuthenticating {
                    VStack(spacing: 8) {
                        HStack {
                            ProgressView()
                                .progressViewStyle(CircularProgressViewStyle(tint: .blue))
                                .scaleEffect(0.8)
                            Text("Connecting to Slack...")
                                .font(.callout)
                                .foregroundColor(.blue)
                        }
                        
                        Button("Cancel") {
                            slackManager.oauthManager.cancelAuthentication()
                        }
                        .buttonStyle(.bordered)
                        .controlSize(.small)
                    }
                    .padding(.top, 8)
                }
                
                Spacer()
            }
            .padding()
            .navigationTitle("Slack Integration")
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") {
                        hasSetupSlack = slackManager.connectedWorkspaceCount > 0
                        dismiss()
                    }
                }
            }
        }
    }
}

private func installShortcut() {
    guard let shortcutUrl = ResourceManager.copyShortcutToTemporary() else {
        print("Could not prepare shortcut for installation")
        return
    }

    NSWorkspace.shared.open(shortcutUrl)
}

#Preview {
    OnboardingView()
        .environmentObject(FocusManager.shared)
        .environmentObject(LicenseManager())
}

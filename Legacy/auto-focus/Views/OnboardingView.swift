import SwiftUI

enum OnboardingStep: Int, CaseIterable {
    case welcome = 0
    case license = 1
    case howItWorks = 2
    case installShortcut = 3
    case addFocusApps = 4
    case browserIntegration = 5
    case complete = 6

    var title: String {
        switch self {
        case .welcome:
            return "Welcome to Auto-Focus"
        case .license:
            return "Get Auto-Focus+"
        case .howItWorks:
            return "How Auto-Focus Works"
        case .installShortcut:
            return "Install Shortcut"
        case .addFocusApps:
            return "Add Focus Apps"
        case .browserIntegration:
            return "Browser Integration"
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

    var body: some View {
        VStack(spacing: 0) {
            // Progress indicator
            ProgressIndicatorView(currentStep: currentStep)
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
                hasSetupBrowser: $hasSetupBrowser
            )
            .padding(.horizontal, 40)
            .padding(.bottom, 30)
        }
        .frame(width: 600, height: 700)
        .onAppear {
            hasInstalledShortcut = focusManager.isShortcutInstalled
            hasAddedApps = !focusManager.focusApps.isEmpty
            hasSetupBrowser = !focusManager.focusURLs.isEmpty
        }
        .onChange(of: focusManager.focusApps.count) { _ in
            hasAddedApps = !focusManager.focusApps.isEmpty
        }
        .onChange(of: focusManager.focusURLs.count) { _ in
            hasSetupBrowser = !focusManager.focusURLs.isEmpty
        }
        .onChange(of: focusManager.isShortcutInstalled) { newValue in
            hasInstalledShortcut = newValue
        }
    }

    @ViewBuilder
    private var stepContent: some View {
        switch currentStep {
        case .welcome:
            WelcomeStepView()
        case .license:
            LicenseOnboardingStepView()
        case .howItWorks:
            HowItWorksStepView()
        case .installShortcut:
            InstallShortcutStepView(hasInstalled: $hasInstalledShortcut)
        case .addFocusApps:
            AddFocusAppsStepView(hasAddedApps: $hasAddedApps)
        case .browserIntegration:
            BrowserIntegrationStepView(hasSetupBrowser: $hasSetupBrowser)
        case .complete:
            CompleteStepView()
        }
    }
}

struct ProgressIndicatorView: View {
    let currentStep: OnboardingStep

    var body: some View {
        HStack(spacing: 20) {
            ForEach(OnboardingStep.allCases, id: \.rawValue) { step in
                HStack(spacing: 8) {
                    Circle()
                        .fill(step.rawValue <= currentStep.rawValue ? Color.accentColor : Color.gray.opacity(0.3))
                        .frame(width: 12, height: 12)

                    if step != OnboardingStep.allCases.last {
                        Rectangle()
                            .fill(step.rawValue < currentStep.rawValue ? Color.accentColor : Color.gray.opacity(0.3))
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

                Text("Auto-Focus monitors your computer usage and automatically enters focus mode when you're working in your designated focus applications.")
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

                Text("Auto-Focus needs to install a system shortcut to control Do Not Disturb mode. This is essential for blocking notifications during focus sessions.")
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
                        // Check shortcut status after a delay to allow user to complete installation
                        // The onChange handler will update hasInstalled when isShortcutInstalled changes
                        Task {
                            try? await Task.sleep(nanoseconds: 1_000_000_000) // 1 second
                            await MainActor.run {
                                focusManager.refreshShortcutStatus()
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
    @EnvironmentObject var licenseManager: LicenseManager
    @Binding var hasAddedApps: Bool

    private var actualHasApps: Bool {
        !focusManager.focusApps.isEmpty
    }

    var body: some View {
        VStack(spacing: 24) {
            Image(systemName: actualHasApps ? "checkmark.circle.fill" : "plus.app")
                .font(.system(size: 60))
                .foregroundColor(actualHasApps ? .green : .accentColor)

            VStack(spacing: 16) {
                Text("Add Focus Apps")
                    .font(.largeTitle)
                    .fontWeight(.bold)

                Text("Choose the applications where you do your most focused work. Auto-Focus will monitor these apps and activate focus mode when you use them.")
                    .font(.title3)
                    .multilineTextAlignment(.center)
                    .foregroundColor(.secondary)
            }

            VStack(spacing: 8) {
                HStack {
                    Image(systemName: actualHasApps ? "checkmark.circle.fill" : "circle")
                        .foregroundColor(actualHasApps ? .green : .gray)

                    Text(actualHasApps ? "\(focusManager.focusApps.count) focus app(s) added" : "No focus apps added yet")
                        .font(.headline)
                        .foregroundColor(actualHasApps ? .green : .primary)

                    Spacer()
                }

                AppsListView(selectedTab: .constant(nil))
                    .frame(minHeight: 200)

                HStack {
                    Button {
                        DispatchQueue.main.async {
                            focusManager.selectFocusApplication()
                        }
                    } label: {
                        Image(systemName: "plus")
                            .frame(width: 16, height: 16)
                    }
                    .disabled(!focusManager.canAddMoreApps)
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                    .frame(width: 28, height: 28)

                    Button {
                        DispatchQueue.main.async {
                            focusManager.removeSelectedApp()
                        }
                    } label: {
                        Image(systemName: "minus")
                            .frame(width: 16, height: 16)
                    }
                    .disabled(focusManager.selectedAppId == nil)
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                    .frame(width: 28, height: 28)

                    Spacer()
                }
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 20)
            .background(Color(.controlBackgroundColor))
            .cornerRadius(12)
            .onChange(of: focusManager.focusApps.count) { _ in
                hasAddedApps = actualHasApps
            }
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

    var body: some View {
        VStack(spacing: 24) {
            Image(systemName: hasSetupBrowser ? "checkmark.circle.fill" : "globe")
                .font(.system(size: 60))
                .foregroundColor(hasSetupBrowser ? .green : .accentColor)

            VStack(spacing: 16) {
                Text("Browser Integration")
                    .font(.largeTitle)
                    .fontWeight(.bold)

                Text("Track focus time on websites like GitHub, Notion, Google Docs, and more. Auto-Focus can monitor your browser tabs and activate focus mode when you're on designated websites.")
                    .font(.title3)
                    .multilineTextAlignment(.center)
                    .foregroundColor(.secondary)

                Text("Note: You don't need to add Chrome as a focus app. The extension handles website detection independently.")
                    .font(.callout)
                    .multilineTextAlignment(.center)
                    .foregroundColor(.orange)
                    .padding(.horizontal)
                    .padding(.vertical, 8)
                    .background(Color.orange.opacity(0.1))
                    .cornerRadius(8)
            }

            VStack(spacing: 16) {
                HStack {
                    Image(systemName: hasSetupBrowser ? "checkmark.circle.fill" : "circle")
                        .foregroundColor(hasSetupBrowser ? .green : .gray)

                    Text(hasSetupBrowser ? browserStatusText : "Browser integration not set up")
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

                Button(hasSetupBrowser ? "Configure Websites" : "Set Up Browser Integration") {
                    showingBrowserConfig = true
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)

                VStack(spacing: 12) {
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

                    VStack(spacing: 8) {
                        Text("Popular focus websites:")
                            .font(.caption)
                            .fontWeight(.semibold)
                            .foregroundColor(.secondary)

                        HStack(spacing: 12) {
                            RecommendedWebsiteTag(name: "GitHub")
                            RecommendedWebsiteTag(name: "Notion")
                            RecommendedWebsiteTag(name: "Google Docs")
                            RecommendedWebsiteTag(name: "Figma")
                        }
                    }
                    .padding(.top, 8)
                }
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 20)
            .background(Color(.controlBackgroundColor))
            .cornerRadius(12)
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
                CompletionRow(icon: "checkmark.circle.fill", text: "Shortcut installed", isComplete: focusManager.isShortcutInstalled)
                CompletionRow(icon: "checkmark.circle.fill", text: "Focus apps configured", isComplete: !focusManager.focusApps.isEmpty)
                CompletionRow(icon: "checkmark.circle.fill", text: "Browser integration ready", isComplete: !focusManager.focusURLs.isEmpty)

                Divider()
                    .padding(.vertical, 8)

                VStack(spacing: 12) {
                    Text("Next steps:")
                        .font(.headline)
                        .fontWeight(.semibold)

                    NextStepRow(icon: "globe", text: "Set up browser extension for website tracking")
                    NextStepRow(icon: "gearshape", text: "Adjust settings in Configuration tab")
                    NextStepRow(icon: "chart.bar", text: "View your focus insights")
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

    private var canProceed: Bool {
        switch currentStep {
        case .installShortcut:
            return hasInstalledShortcut
        case .addFocusApps:
            return hasAddedApps
        case .browserIntegration:
            return true // Optional step, can always proceed
        default:
            return true
        }
    }

    private var isLastStep: Bool {
        currentStep == .complete
    }

    var body: some View {
        HStack {
            if currentStep != .welcome {
                Button("Back") {
                    withAnimation(.easeInOut(duration: 0.3)) {
                        if currentStep.rawValue > 0 {
                            currentStep = OnboardingStep(rawValue: currentStep.rawValue - 1) ?? .welcome
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
                        if currentStep.rawValue < OnboardingStep.allCases.count - 1 {
                            currentStep = OnboardingStep(rawValue: currentStep.rawValue + 1) ?? .complete
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

                Text("Unlock unlimited focus apps, data export, and advanced insights.")
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
                    VStack(spacing: 12) {
                        Link(destination: URL(string: "https://auto-focus.app")!) {
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
        VStack(spacing: 0) {
            // Header with title and done button
            HStack {
                Text("Configure Websites")
                    .font(.title2)
                    .fontWeight(.bold)

                Spacer()

                Button("Done") {
                    dismiss()
                }
                .keyboardShortcut(.defaultAction)
            }
            .padding(.horizontal, 32)
            .padding(.top, 24)
            .padding(.bottom, 24)

            // Content area
            VStack(spacing: 24) {
                // Focus URLs Management
                VStack(alignment: .leading, spacing: 20) {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Focus Websites")
                            .font(.headline)
                            .fontWeight(.semibold)

                        Text("Being on any of these websites will automatically activate focus mode.")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }

                    // Current URLs list
                    if !focusManager.focusURLs.isEmpty {
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Current Focus URLs:")
                                .font(.subheadline)
                                .fontWeight(.medium)

                            VStack(spacing: 8) {
                                ForEach(focusManager.focusURLs.prefix(5)) { url in
                                    HStack {
                                        Image(systemName: "globe")
                                            .foregroundColor(.blue)
                                            .frame(width: 20, height: 20)
                                        Text(url.name)
                                            .font(.body)
                                        Spacer()
                                    }
                                    .padding(.vertical, 4)
                                }

                                if focusManager.focusURLs.count > 5 {
                                    Text("... and \(focusManager.focusURLs.count - 5) more")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                        .padding(.leading, 24)
                                }
                            }
                            .padding(16)
                            .background(Color(.controlBackgroundColor))
                            .cornerRadius(12)
                        }
                    }

                    // Add URL options
                    VStack(spacing: 16) {
                        Button {
                            showingPresets = true
                        } label: {
                            HStack(spacing: 16) {
                                Image(systemName: "list.bullet.rectangle")
                                    .font(.title2)
                                    .foregroundColor(.blue)
                                    .frame(width: 32, height: 32)

                                VStack(alignment: .leading, spacing: 6) {
                                    Text("Choose from Presets")
                                        .font(.headline)
                                        .foregroundColor(.primary)

                                    Text("GitHub, Google Docs, Notion, and more")
                                        .font(.subheadline)
                                        .foregroundColor(.secondary)
                                }

                                Spacer()

                                Image(systemName: "chevron.right")
                                    .foregroundColor(.secondary)
                                    .font(.system(size: 14, weight: .medium))
                            }
                            .padding(20)
                            .background(Color(.controlBackgroundColor))
                            .cornerRadius(12)
                        }
                        .buttonStyle(.plain)
                        .disabled(!focusManager.canAddMoreURLs)

                        Button {
                            showingAddURL = true
                        } label: {
                            HStack(spacing: 16) {
                                Image(systemName: "plus.circle")
                                    .font(.title2)
                                    .foregroundColor(.green)
                                    .frame(width: 32, height: 32)

                                VStack(alignment: .leading, spacing: 6) {
                                    Text("Add Custom URL")
                                        .font(.headline)
                                        .foregroundColor(.primary)

                                    Text("Enter your own domain to track")
                                        .font(.subheadline)
                                        .foregroundColor(.secondary)
                                }

                                Spacer()

                                Image(systemName: "chevron.right")
                                    .foregroundColor(.secondary)
                                    .font(.system(size: 14, weight: .medium))
                            }
                            .padding(20)
                            .background(Color(.controlBackgroundColor))
                            .cornerRadius(12)
                        }
                        .buttonStyle(.plain)
                        .disabled(!focusManager.canAddMoreURLs)
                    }

                    // Free tier limitation
                    if !licenseManager.isLicensed {
                        HStack(spacing: 12) {
                            Image(systemName: "info.circle")
                                .foregroundColor(.blue)
                                .font(.system(size: 16))
                            Text("Free tier: \(focusManager.focusURLs.count)/3 websites • Auto-Focus+ unlocks unlimited websites")
                                .font(.subheadline)
                                .foregroundColor(.blue)
                        }
                        .padding(16)
                        .background(Color.blue.opacity(0.1))
                        .cornerRadius(12)
                    }
                }
                .padding(.horizontal, 32)

                Spacer()
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(.windowBackgroundColor))
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

private func installShortcut() {
    guard let shortcutUrl = ResourceManager.copyShortcutToTemporary() else {
        AppLogger.ui.error("Could not prepare shortcut for installation")
        return
    }

    NSWorkspace.shared.open(shortcutUrl)
}

#Preview {
    OnboardingView()
        .environmentObject(FocusManager.shared)
        .environmentObject(LicenseManager())
}

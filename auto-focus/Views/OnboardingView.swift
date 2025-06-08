import SwiftUI

enum OnboardingStep: Int, CaseIterable {
    case welcome = 0
    case howItWorks = 1
    case installShortcut = 2
    case addFocusApps = 3
    case license = 4
    case complete = 5
    
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
                hasAddedApps: $hasAddedApps
            )
            .padding(.horizontal, 40)
            .padding(.bottom, 30)
        }
        .frame(width: 600, height: 700)
        .onAppear {
            hasInstalledShortcut = focusManager.isShortcutInstalled
            hasAddedApps = !focusManager.focusApps.isEmpty
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
        case .license:
            LicenseOnboardingStepView()
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
                        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                            focusManager.refreshShortcutStatus()
                            hasInstalled = focusManager.isShortcutInstalled
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
                
                Text("Choose the applications where you do your most focused work. Auto-Focus will monitor these apps and activate focus mode when you use them.")
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
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                        hasAddedApps = !focusManager.focusApps.isEmpty
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
                
                Divider()
                    .padding(.vertical, 8)
                
                VStack(spacing: 12) {
                    Text("Next steps:")
                        .font(.headline)
                        .fontWeight(.semibold)
                    
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
    
    private var canProceed: Bool {
        switch currentStep {
        case .installShortcut:
            return hasInstalledShortcut
        case .addFocusApps:
            return hasAddedApps
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
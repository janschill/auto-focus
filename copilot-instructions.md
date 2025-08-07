# Auto-Focus GitHub Copilot Instructions

## Project Overview

Auto-Focus is a macOS app and browser extension designed to enhance productivity by automatically managing Do Not Disturb (DND) settings based on user activity. The system detects when users are in "flow state" working with designated applications and automatically enables focus mode to minimize interruptions.

### Core Concept

The app monitors active applications and uses timers to determine when a user has been focusing on work. When sustained focus is detected (default: 12 minutes), it automatically activates macOS Focus/Do Not Disturb mode. It includes a configurable buffer period to prevent losing focus during quick context switches.

### Key Components

1. **macOS App**: Swift/SwiftUI application that runs as a menu bar utility
2. **Browser Extension**: Chrome extension that communicates with the main app via HTTP
3. **License Management**: Integration with external license validation API
4. **Focus Analytics**: Session tracking and productivity insights

## Project Structure

```
auto-focus/
├── auto-focus/                    # Main macOS application (Swift/SwiftUI)
│   ├── AutoFocusApp.swift        # Main app entry point
│   ├── AppMonitor.swift          # Core app monitoring functionality
│   ├── AppDelegate.swift         # App lifecycle management
│   ├── Features/                 # Feature-based architecture
│   │   ├── FocusControl/         # Core focus management
│   │   │   ├── Models/           # Focus session data models
│   │   │   └── Services/         # Focus logic and managers
│   │   ├── LicenseManagement/    # License validation
│   │   │   ├── Services/         # License API integration
│   │   │   └── Views/            # License UI components
│   │   └── UserInterface/        # UI components
│   │       ├── Views/            # SwiftUI views
│   │       └── ViewModels/       # MVVM view models
│   ├── Managers/                 # Core service managers
│   │   ├── BrowserManager.swift  # Browser extension communication
│   │   ├── BufferManager.swift   # Buffer period management
│   │   ├── SessionManager.swift  # Focus session management
│   │   └── UserDefaultsManager.swift # Settings persistence
│   ├── Models/                   # Data models and providers
│   ├── Protocols/                # Swift protocols
│   └── Shared/                   # Shared utilities and resources
├── auto-focus-browser-extension/ # Chrome extension
│   └── chrome/
│       ├── manifest.json         # Extension configuration
│       ├── background.js         # Service worker
│       └── popup/                # Extension popup UI
├── auto-focusTests/              # Unit tests
├── auto-focusUITests/            # UI automation tests
└── Makefile                      # Build automation
```

## Architecture & Core Components

### 1. Feature-Based Architecture

The app uses a feature-based architecture where major functionality is organized into distinct modules:

**FocusControl**: Core focus detection and management
- `FocusManager`: Orchestrates focus detection and mode transitions
- `FocusModeManager`: Interfaces with macOS Focus/DND APIs
- `FocusSession`: Models individual focus sessions

**LicenseManagement**: Handles license validation and premium features
- `LicenseManager`: Communicates with external licensing API
- Premium feature gating and validation

**UserInterface**: SwiftUI-based UI components following MVVM pattern
- Views: SwiftUI views for settings, onboarding, menu bar
- ViewModels: ObservableObject classes managing UI state

### 2. App Monitoring System

**AppMonitor**: Core monitoring service that:
- Polls active application every 2 seconds (configurable)
- Detects when focus apps are active
- Triggers focus session start/stop events
- Communicates state changes via delegate pattern

**Focus Detection Logic**:
1. Monitor active app bundle identifiers
2. Compare against user-configured focus apps
3. Start timer when focus app becomes active
4. Trigger focus mode after threshold (default: 12 minutes)
5. Manage buffer period during app switches

### 3. Browser Integration

**HTTP Communication**: Extension communicates via localhost:8942
- Browser extension sends tab activity to macOS app
- App can detect focus websites (GitHub, Linear, Figma, etc.)
- Bidirectional state synchronization

**BrowserManager**: Handles HTTP server and extension communication
- Lightweight HTTP server for extension API
- Tab activity processing and focus detection
- Browser state integration with main focus logic

### 4. Session Management

**SessionManager**: Tracks and persists focus sessions
- Session start/end times and durations
- Focus app and browser activity correlation
- Data export capabilities for analytics
- Integration with insights and reporting

## Development Guidelines

### SwiftUI & MVVM Patterns

**View Structure**:
```swift
struct SettingsView: View {
    @EnvironmentObject private var focusManager: FocusManager
    @EnvironmentObject private var licenseManager: LicenseManager
    
    var body: some Scene {
        // UI implementation
    }
}
```

**ViewModel Pattern**:
```swift
class ConfigurationViewModel: ObservableObject {
    @Published var isLoading = false
    @Published var selectedApps: [AppInfo] = []
    
    // Business logic methods
}
```

### Dependency Injection

The app uses a simple DI pattern:
- `FocusManager.shared` as primary singleton
- Environment objects for SwiftUI views
- Manager classes injected into view models

### State Management

**ObservableObject Classes**: 
- `FocusManager`: Central state for focus detection
- `LicenseManager`: License and premium feature state
- ViewModels: UI-specific state management

**Published Properties**: Use `@Published` for reactive UI updates
```swift
@Published var isFocusAppActive: Bool = false
@Published var timeSpent: TimeInterval = 0
@Published var isInFocusMode: Bool = false
```

### Configuration Management

**UserDefaultsManager**: Centralized settings storage
- Focus app configurations
- Timing thresholds and buffer periods  
- UI preferences and onboarding state
- License information

**AppConfiguration**: Static configuration constants
- Default timer intervals
- API endpoints and ports
- Feature flags and limits

## Coding Standards

### Swift Style Guidelines

**Naming Conventions**:
- Classes: `PascalCase` (e.g., `FocusManager`, `AppMonitor`)
- Properties/Methods: `camelCase` (e.g., `isFocusAppActive`, `startSession()`)
- Constants: `camelCase` with descriptive names
- Protocol names: End with `-ing` for capabilities (e.g., `AppMonitoring`)

**Code Organization**:
- Group related functionality into extensions
- Use MARK comments for section organization
- Keep view files focused on UI, logic in ViewModels
- Separate models, views, and business logic

**SwiftUI Specific**:
- Use `@StateObject` for owned objects, `@ObservableObject` for injected
- Prefer `@EnvironmentObject` for passing managers through view hierarchy
- Extract complex views into separate components
- Use computed properties for derived UI state

### Error Handling

**Graceful Degradation**: Handle errors without crashing
```swift
func detectFocusApps() {
    do {
        let apps = try AppDetector.getRunningApplications()
        // Process apps
    } catch {
        print("Failed to detect apps: \(error)")
        // Fallback behavior
    }
}
```

**User-Facing Errors**: Show meaningful messages in UI
- Network errors for license validation
- Permission errors for focus mode access
- Configuration validation errors

### Testing Guidelines

**Unit Testing**: Focus on business logic
- Manager classes and their core functionality
- Data models and transformations
- View model business logic

**UI Testing**: Critical user workflows
- Onboarding flow completion
- Settings configuration
- Focus session lifecycle

**Test Structure**:
```swift
class FocusManagerTests: XCTestCase {
    var focusManager: FocusManager!
    
    override func setUp() {
        super.setUp()
        focusManager = FocusManager()
    }
    
    func testFocusDetection() {
        // Test implementation
    }
}
```

## Browser Extension Development

### Manifest V3 Architecture

**Background Service Worker**: `background.js`
- Monitors tab changes and activity
- Communicates with macOS app via HTTP
- Manages extension state and timers

**Popup Interface**: Optional UI for manual control
- Focus session status display
- Quick settings and controls
- Integration with main app state

**Communication Protocol**:
```javascript
// Send tab activity to macOS app
fetch('http://localhost:8942/api/tab-activity', {
    method: 'POST',
    body: JSON.stringify({
        url: tab.url,
        title: tab.title,
        active: true
    })
});
```

### Focus Website Detection

**URL Pattern Matching**: Detect productivity websites
- Development tools: GitHub, GitLab, VS Code Web
- Design tools: Figma, Sketch Cloud
- Project management: Linear, Notion, Jira

**Activity Tracking**: 
- Tab focus/blur events
- URL changes and navigation
- Time spent on focus sites

## Build & Release Process

### Development Workflow

**Local Development**:
1. Open `auto-focus.xcodeproj` in Xcode
2. Run `make build` for command-line builds
3. Use `make test` for running tests (requires Xcode CLI tools)
4. `make lint` for SwiftLint checking (requires SwiftLint installation)

**Dependencies**:
- Xcode 14.0+ for Swift/SwiftUI development
- macOS 14.0+ target for Focus API compatibility
- SwiftLint for code style enforcement

### Release Management

**Automated Release Process**:
```bash
# Complete release workflow
make prepare-release    # Build, sign, and notarize
make complete-release   # Package and deploy
```

**Version Management**:
- Date-based versioning: `YYYY.MM.DD` format
- Git tags: `v2025.06.15`
- Single source of truth in git with GitHub releases as backup

**Distribution**:
- Primary: Direct downloads from https://auto-focus.app/downloads/
- Backup: GitHub releases for version history
- Notarized .app bundles in ZIP format

### Code Signing & Notarization

**Developer ID Signing**: Required for distribution outside App Store
- Developer ID certificates stored in Keychain
- Automatic code signing during build process
- Notarization via `notarytool` for macOS security compliance

**Release Checklist**:
- [ ] Code committed and tests passing
- [ ] Version bumped in project settings
- [ ] App builds and runs correctly locally
- [ ] Browser extension tested (if changed)
- [ ] Automated release process completed
- [ ] Download links verified on website
- [ ] GitHub release created with assets

## Common Operations

### Adding New Focus Apps

1. **App Detection**: Modify `AppMonitor` to detect new bundle identifiers
2. **Configuration**: Update settings UI to allow user selection
3. **Validation**: Add validation for app existence and permissions
4. **Testing**: Create test cases for new app detection logic

### Integrating New Browser Sites

1. **Pattern Matching**: Add URL patterns to browser extension
2. **Activity Detection**: Implement site-specific activity tracking
3. **Communication**: Update API to handle new site data
4. **Configuration**: Allow user customization of site detection

### Adding Premium Features

1. **License Gating**: Check license status before enabling features
2. **UI Updates**: Add premium indicators and upgrade prompts
3. **Analytics**: Track premium feature usage
4. **Testing**: Validate feature gating and license integration

### Focus Mode Customization

1. **macOS Integration**: Extend `FocusModeManager` for new focus types
2. **Settings UI**: Add configuration options for customization
3. **State Management**: Update focus state tracking
4. **Persistence**: Save custom configurations to UserDefaults

## Performance Considerations

### Monitoring Efficiency

**Polling Strategy**: Balance accuracy vs. resource usage
- Default 2-second intervals for app detection
- Adaptive polling based on activity levels
- Efficient app state caching and change detection

**Memory Management**: 
- Use weak references in delegate patterns
- Proper timer cleanup and lifecycle management
- Efficient data structures for app tracking

### Background Processing

**Menu Bar App**: Designed for always-on background operation
- Minimal CPU usage during monitoring
- Efficient state updates and UI refresh
- Proper handling of system sleep/wake cycles

### Network Efficiency

**Browser Communication**: Lightweight HTTP API
- JSON payloads for tab activity
- Connection pooling and reuse
- Graceful handling of network failures

## Integration Points

### macOS System Integration

**Focus/Do Not Disturb**: Uses macOS Focus API
- Requires user permission for automation
- Integration with system focus modes
- Respect for manual user overrides

**Application Monitoring**: Uses macOS accessibility APIs
- Bundle identifier detection
- Active app tracking
- Respects user privacy settings

### External License API

**Remote License Validation**: 
- RESTful API integration for license checking
- Secure token-based authentication
- Offline grace period for network issues
- Privacy-conscious data transmission

## Troubleshooting Common Issues

### App Monitoring Problems

**Permission Issues**: 
- Ensure accessibility permissions granted
- Verify automation permissions for Focus
- Check system preferences for app access

**Detection Accuracy**:
- Validate app bundle identifiers
- Test with various app configurations
- Monitor system logs for detection issues

### Browser Extension Issues

**Communication Failures**:
- Verify macOS app is running and HTTP server active
- Check localhost port availability (8942)
- Test extension permissions for local connections

**State Synchronization**:
- Monitor API communication logs
- Verify browser and app state consistency
- Handle extension reload and recovery scenarios

This architecture provides a robust foundation for productivity-focused automatic focus management across macOS and browser environments.
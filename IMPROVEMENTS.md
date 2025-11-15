# Auto-Focus: Code Review & Improvement Suggestions

## Executive Summary

Auto-Focus is a well-architected macOS productivity app with a solid foundation. This document outlines opportunities for improvement across project structure, code quality, and product features.

---

## 1. Project Structure Improvements

### 1.1 Consolidate ViewModels Location
**Current State:** ViewModels are split between:
- `auto-focus/ViewModels/` (InsightsViewModel, DebugViewModel)
- `auto-focus/Features/UserInterface/ViewModels/` (ConfigurationViewModel)

**Recommendation:** Consolidate all ViewModels under `Features/UserInterface/ViewModels/` for consistency.

```bash
# Proposed structure:
Features/UserInterface/
├── ViewModels/
│   ├── ConfigurationViewModel.swift
│   ├── InsightsViewModel.swift
│   ├── DebugViewModel.swift
│   └── MenuBarViewModel.swift (if exists)
└── Views/
    └── ...
```

### 1.2 Extract Focus State Machine
**Current State:** Complex state management logic is embedded in `FocusManager` (873 lines).

**Recommendation:** Create a dedicated state machine for focus transitions:

```
Features/FocusControl/
├── StateMachine/
│   ├── FocusStateMachine.swift
│   ├── FocusState.swift (enum)
│   └── FocusTransition.swift
└── Services/
    └── FocusManager.swift (simplified)
```

**Benefits:**
- Clearer state transitions
- Easier to test
- Better documentation of valid state changes
- Reduces complexity in FocusManager

### 1.3 Separate Data Layer
**Current State:** Persistence is mixed with business logic.

**Recommendation:** Create a dedicated data layer:

```
auto-focus/
├── Data/
│   ├── Repositories/
│   │   ├── SessionRepository.swift
│   │   ├── AppRepository.swift
│   │   └── SettingsRepository.swift
│   ├── Storage/
│   │   ├── UserDefaultsStorage.swift (implements PersistenceManaging)
│   │   └── SQLiteStorage.swift (future: for better session storage)
│   └── Models/
│       └── (move from Models/ if needed)
```

### 1.4 Organize Network Layer
**Current State:** HTTP server is a single large file (440 lines).

**Recommendation:** Split into smaller, focused components:

```
Shared/NetworkLayer/
├── HTTPServer.swift (orchestrator)
├── Handlers/
│   ├── TabChangeHandler.swift
│   ├── HandshakeHandler.swift
│   ├── HeartbeatHandler.swift
│   └── FocusURLHandler.swift
├── Models/
│   └── BrowserMessage.swift
└── Middleware/
    └── ConnectionQualityMiddleware.swift
```

---

## 2. Source Code Refactoring

### 2.1 Replace print() with Structured Logging

**Current State:** 89 `print()` statements across 11 files, but a sophisticated `AppLogger` exists.

**Recommendation:** Migrate all `print()` calls to use `AppLogger`:

```swift
// Before:
print("FocusManager: Browser focus deactivated")

// After:
AppLogger.focus.info("Browser focus deactivated", metadata: [
    "previous_state": "active",
    "current_state": "inactive"
])
```

**Priority Files:**
1. `FocusManager.swift` (21 print statements)
2. `HTTPServer.swift` (21 print statements)
3. `BrowserManager.swift` (22 print statements)
4. `SessionManager.swift` (13 print statements)

**Migration Strategy:**
- Create a script to identify all print statements
- Replace with appropriate logger (focus, browser, session, etc.)
- Add contextual metadata for better debugging

### 2.2 Extract Timer Management Logic

**Current State:** Timer logic is scattered throughout `FocusManager`.

**Recommendation:** Create a dedicated `FocusTimer` class:

```swift
class FocusTimer {
    private var timer: Timer?
    private let interval: TimeInterval
    private var elapsedTime: TimeInterval = 0
    private var isPaused: Bool = false

    var onTick: ((TimeInterval) -> Void)?
    var onThresholdReached: (() -> Void)?

    func start(preserveTime: Bool = false)
    func pause()
    func resume()
    func reset()
    func stop()
}
```

**Benefits:**
- Single responsibility
- Easier to test
- Clearer API
- Reduces FocusManager complexity

### 2.3 Standardize Error Handling

**Current State:** Inconsistent error handling:
- `LicenseManager` has proper `LicenseError` enum
- `FocusManager` uses print statements
- `HTTPServer` returns HTTP status codes

**Recommendation:** Create domain-specific error types:

```swift
enum FocusError: LocalizedError {
    case shortcutNotFound
    case focusModeActivationFailed(String)
    case sessionStartFailed
    case invalidStateTransition(from: FocusState, to: FocusState)

    var errorDescription: String? { ... }
}

enum BrowserError: LocalizedError {
    case extensionNotConnected
    case serverStartFailed(Error)
    case invalidMessageFormat
    ...
}
```

### 2.4 Reduce FocusManager Size

**Current State:** `FocusManager.swift` is 873 lines with multiple responsibilities.

**Recommendation:** Extract responsibilities:

1. **Focus Detection Logic** → `FocusDetector`
   - Handles app/browser focus detection
   - Determines when to start/stop tracking

2. **Session Coordination** → `SessionCoordinator`
   - Coordinates between SessionManager and FocusManager
   - Handles session lifecycle

3. **Export/Import Logic** → `DataManager`
   - Handles data export/import
   - Manages data validation

**Target:** Reduce `FocusManager` to ~300-400 lines focused on orchestration.

### 2.5 Improve Dependency Injection

**Current State:** Mixed patterns:
- `FocusManager.shared` singleton
- `ServiceRegistry` exists but not fully utilized
- Direct instantiation in some places

**Recommendation:** Standardize on dependency injection:

```swift
// Use ServiceRegistry consistently
class FocusManager {
    init(
        userDefaultsManager: any PersistenceManaging,
        sessionManager: any SessionManaging,
        // ... other dependencies
    ) {
        // ...
    }
}

// In AutoFocusApp.swift:
@main
struct AutoFocusApp: App {
    @StateObject private var focusManager = ServiceRegistry.shared.focusManager()
    @StateObject private var licenseManager = LicenseManager()
    // ...
}
```

**Benefits:**
- Easier testing
- Better separation of concerns
- More flexible architecture

### 2.6 Add Result Types for Async Operations

**Current State:** Some async operations use try/catch, others use callbacks.

**Recommendation:** Standardize on `Result` types or async/await:

```swift
// Before:
func exportDataToFile(options: ExportOptions = .default) {
    // Uses completion handlers and print statements
}

// After:
func exportDataToFile(options: ExportOptions = .default) async throws -> URL {
    // Returns URL or throws error
    // Caller can handle with do/catch or Result
}
```

### 2.7 Extract Constants

**Current State:** Magic numbers and strings scattered throughout code.

**Recommendation:** Create centralized constants:

```swift
enum FocusConstants {
    enum Timing {
        static let defaultCheckInterval: TimeInterval = 2.0
        static let defaultFocusThreshold: TimeInterval = 12 * 60
        static let defaultBufferTime: TimeInterval = 2 * 60
        static let connectionTimeout: TimeInterval = 90.0
        static let serverHealthCheckInterval: TimeInterval = 300.0
    }

    enum Limits {
        static let freeAppLimit = 3
        static let freeURLLimit = 3
        static let unlimited = -1
    }

    enum Network {
        static let serverPort: UInt16 = 8942
        static let maxStartupRetries = 3
    }
}
```

---

## 3. Testing Improvements

### 3.1 Increase Test Coverage

**Current State:** Tests exist but coverage could be improved.

**Recommendation:** Add tests for:

1. **Focus State Transitions**
   ```swift
   func testTimerPreservationWhenSwitchingContexts()
   func testTimerResetWhenLeavingFocus()
   func testBufferPeriodBehavior()
   ```

2. **Browser Integration**
   ```swift
   func testTabSwitchingDetection()
   func testFocusURLMatching()
   func testConnectionTimeoutHandling()
   ```

3. **Session Management**
   ```swift
   func testSessionStartEnd()
   func testSessionImportWithDuplicates()
   func testSessionValidation()
   ```

### 3.2 Add Integration Tests

**Recommendation:** Create integration tests for:
- End-to-end focus detection flow
- Browser extension communication
- Data export/import cycle

### 3.3 Add UI Tests

**Current State:** UI tests exist but could be expanded.

**Recommendation:** Add tests for:
- Onboarding flow
- Settings configuration
- Focus session editing
- License activation flow

---

## 4. Product Ideas & Feature Enhancements

### 4.1 Focus Analytics & Insights

**Enhancement:** Advanced analytics dashboard

**Features:**
- **Focus Streaks:** Track consecutive days of focus
- **Productivity Score:** Calculate based on focus time, consistency, and goals
- **Time-of-Day Analysis:** Show when user is most productive
- **App/URL Breakdown:** See which apps/URLs contribute most to focus time
- **Weekly/Monthly Reports:** Email or export summaries
- **Goal Setting:** Set daily/weekly focus time goals

**Implementation:**
```swift
Features/Analytics/
├── Services/
│   ├── AnalyticsEngine.swift
│   ├── StreakCalculator.swift
│   └── ProductivityScorer.swift
├── Models/
│   ├── FocusStreak.swift
│   ├── ProductivityScore.swift
│   └── FocusReport.swift
└── Views/
    └── AdvancedInsightsView.swift
```

### 4.2 Smart Focus Suggestions

**Enhancement:** AI-powered focus recommendations

**Features:**
- **Optimal Focus Times:** Suggest best times based on historical data
- **App Recommendations:** Suggest focus apps based on usage patterns
- **Distraction Detection:** Identify apps that frequently interrupt focus
- **Focus Reminders:** Gentle notifications when it's a good time to focus

### 4.3 Focus Modes & Profiles

**Enhancement:** Multiple focus profiles for different work types

**Features:**
- **Work Profile:** Apps/URLs for work tasks
- **Learning Profile:** Apps/URLs for studying
- **Creative Profile:** Apps/URLs for creative work
- **Quick Switch:** Toggle between profiles
- **Profile-Specific Settings:** Different thresholds/buffers per profile

**Implementation:**
```swift
struct FocusProfile {
    let id: UUID
    let name: String
    let focusApps: [AppInfo]
    let focusURLs: [FocusURL]
    let threshold: TimeInterval
    let bufferTime: TimeInterval
    let icon: String
}
```

### 4.4 Team/Workspace Features (Premium)

**Enhancement:** Collaborative focus tracking

**Features:**
- **Team Focus Sessions:** Coordinate focus time with team
- **Focus Status Sharing:** Show when team members are in focus
- **Team Analytics:** Aggregate team productivity metrics
- **Focus Challenges:** Team-wide focus goals and competitions

### 4.5 Advanced Browser Integration

**Enhancement:** Enhanced browser features

**Features:**
- **Safari Support:** Extend beyond Chrome
- **Firefox Support:** Add Firefox extension
- **Tab Group Detection:** Detect Safari tab groups
- **Incognito Mode Support:** Track focus in private browsing
- **Browser History Integration:** Analyze browsing patterns

### 4.6 Focus Break Management

**Enhancement:** Built-in break reminders

**Features:**
- **Pomodoro Integration:** Automatic break reminders
- **Break Suggestions:** Suggest breaks based on focus duration
- **Break Types:** Short break, long break, lunch break
- **Break Activities:** Suggest activities during breaks
- **Break Tracking:** Track break frequency and duration

### 4.7 Calendar Integration

**Enhancement:** Sync with calendar apps

**Features:**
- **Calendar Event Detection:** Auto-detect focus time from calendar
- **Meeting Detection:** Pause focus during meetings
- **Schedule-Aware Focus:** Adjust focus mode based on calendar
- **Focus Time Blocking:** Block calendar time for focus

### 4.8 Advanced Notifications

**Enhancement:** Smarter notification management

**Features:**
- **Notification Categories:** Allow certain notification types during focus
- **Priority Contacts:** Allow notifications from specific contacts
- **Notification Summary:** Show summary after focus session
- **Smart Filtering:** AI-powered notification filtering

### 4.9 Export & Integration

**Enhancement:** Better data export and third-party integration

**Features:**
- **CSV Export:** Export sessions as CSV for spreadsheet analysis
- **API Access:** REST API for third-party integrations
- **Webhook Support:** Send focus events to external services
- **IFTTT/Zapier Integration:** Connect with automation platforms
- **RescueTime Integration:** Sync with RescueTime
- **Toggl Integration:** Export to Toggl time tracking

### 4.10 Accessibility Improvements

**Enhancement:** Better accessibility support

**Features:**
- **VoiceOver Support:** Full VoiceOver compatibility
- **Keyboard Shortcuts:** Comprehensive keyboard navigation
- **High Contrast Mode:** Support for high contrast displays
- **Text Size Scaling:** Support for larger text sizes
- **Reduced Motion:** Respect system reduced motion preference

### 4.11 Widget Support

**Enhancement:** macOS widgets for quick access

**Features:**
- **Focus Status Widget:** Show current focus status
- **Today's Focus Widget:** Display today's focus time
- **Quick Toggle Widget:** Toggle focus mode from widget
- **Streak Widget:** Show current focus streak

### 4.12 Machine Learning Features

**Enhancement:** ML-powered features

**Features:**
- **Focus Prediction:** Predict when user will enter focus
- **Distraction Prevention:** Predict and prevent distractions
- **Optimal Schedule:** Learn optimal focus schedule
- **App Usage Patterns:** Identify patterns in app usage

---

## 5. Technical Debt & Maintenance

### 5.1 Migrate to SQLite for Sessions

**Current State:** Sessions stored in UserDefaults (noted in code comments).

**Recommendation:** Migrate to SQLite for:
- Better performance with large datasets
- More robust data integrity
- Easier querying and analytics
- Better handling of concurrent access

**Implementation:**
```swift
Data/Storage/
├── SQLiteStorage.swift
├── Migrations/
│   └── Migration001_CreateSessionsTable.swift
└── Repositories/
    └── SessionRepository.swift
```

### 5.2 Add Performance Monitoring

**Recommendation:** Add performance monitoring:

```swift
Features/Monitoring/
├── Services/
│   ├── PerformanceMonitor.swift
│   └── MetricsCollector.swift
└── Models/
    └── PerformanceMetric.swift
```

**Track:**
- App launch time
- Focus detection latency
- HTTP server response times
- Memory usage
- CPU usage

### 5.3 Add Crash Reporting

**Recommendation:** Integrate crash reporting (e.g., Sentry, Firebase Crashlytics):

```swift
Shared/Utilities/
└── CrashReporter.swift
```

### 5.4 Improve Documentation

**Recommendation:**
- Add DocC documentation for public APIs
- Create architecture decision records (ADRs)
- Document state machine transitions
- Add inline documentation for complex logic

### 5.5 Add CI/CD Improvements

**Recommendation:**
- Add code coverage reporting
- Add automated performance benchmarks
- Add dependency vulnerability scanning
- Add automated changelog generation

---

## 6. Security & Privacy

### 6.1 Data Encryption

**Enhancement:** Encrypt sensitive data at rest

**Features:**
- Encrypt session data
- Encrypt license keys
- Use Keychain for sensitive credentials

### 6.2 Privacy Enhancements

**Enhancement:** Better privacy controls

**Features:**
- **Data Retention Settings:** Allow users to set data retention period
- **Anonymization:** Option to anonymize exported data
- **Local-Only Mode:** Option to disable all network features
- **Privacy Policy:** Clear privacy policy and data handling

---

## 7. Prioritization Recommendations

### High Priority (Quick Wins)
1. ✅ Replace `print()` with `AppLogger` (2-3 days)
2. ✅ Extract timer management logic (1-2 days)
3. ✅ Consolidate ViewModels location (1 day)
4. ✅ Extract constants (1 day)
5. ✅ Add focus state machine tests (2-3 days)

### Medium Priority (Significant Impact)
1. ✅ Reduce FocusManager size (3-5 days)
2. ✅ Migrate to SQLite for sessions (5-7 days)
3. ✅ Standardize error handling (3-4 days)
4. ✅ Add advanced analytics (7-10 days)
5. ✅ Add focus profiles feature (5-7 days)

### Low Priority (Nice to Have)
1. ✅ Team features (2-3 weeks)
2. ✅ ML-powered features (3-4 weeks)
3. ✅ Calendar integration (1-2 weeks)
4. ✅ Widget support (1 week)

---

## 8. Code Quality Metrics

### Current State
- **Lines of Code:** ~8,000+ Swift lines
- **Test Coverage:** ~30-40% (estimated)
- **Cyclomatic Complexity:** High in FocusManager
- **Code Duplication:** Low (good)
- **Documentation:** Moderate

### Target State
- **Test Coverage:** >70%
- **Cyclomatic Complexity:** Reduce FocusManager complexity by 50%
- **Documentation:** >80% of public APIs documented
- **Code Smells:** Zero critical issues

---

## Conclusion

Auto-Focus has a solid foundation with good architecture patterns. The main opportunities are:

1. **Code Organization:** Better separation of concerns, especially in FocusManager
2. **Logging:** Consistent use of structured logging
3. **Testing:** Increased test coverage, especially for state transitions
4. **Features:** Rich opportunities for analytics and productivity features

Focus on high-priority refactoring first, then build out the feature enhancements that will differentiate Auto-Focus in the market.


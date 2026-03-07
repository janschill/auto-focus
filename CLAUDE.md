# Auto-Focus Agent Guide

This document helps AI assistants understand the Auto-Focus codebase structure, patterns, and common tasks.

## Quick Reference

### Key Files & Locations

**Core Focus Logic:**

- `auto-focus/Services/FocusManager.swift` - Main orchestrator for focus detection
- `auto-focus/Services/AppMonitor.swift` - Monitors active applications
- `auto-focus/Services/BufferManager.swift` - Handles buffer periods
- `auto-focus/Services/SessionManager.swift` - Tracks focus sessions

**Browser Integration:**

- `auto-focus/Services/BrowserManager.swift` - Manages browser extension communication
- `auto-focus/Services/HTTPServer.swift` - HTTP server for extension API
- `auto-focus-browser-extension/chrome/background.js` - Extension service worker

**License & Premium:**

- `auto-focus/Services/LicenseManager.swift` - License validation

**UI Components:**

- `auto-focus/Views/` - All SwiftUI views

## Architecture Patterns

### State Management

**FocusManager** is the central state manager:

```swift
@Published var timeSpent: TimeInterval = 0
@Published var isFocusAppActive = false
@Published var isBrowserInFocus: Bool = false
@Published var isInFocusMode = false
```

**Key State Transitions:**

1. User opens focus app → `handleFocusAppInFront()` → starts timer
2. Timer reaches threshold → `shouldEnterFocusMode` → activates DND
3. User switches to non-focus app → `handleNonFocusAppInFront()` → buffer period or reset
4. Browser focus activates → `handleBrowserFocusActivated()` → preserves time if switching from app focus

### Focus Session Lifecycle

**Before Session Starts (Counting Up):**

- `timeSpent` increments every `checkInterval` (default: 2 seconds)
- Timer continues when switching between focus contexts (app ↔ browser)
- Timer resets when leaving focus entirely (focus → non-focus)

**During Active Session:**

- `isInFocusMode = true` → DND is active
- Buffer period if user switches to non-focus app
- Session ends if buffer times out

**Key Methods:**

- `startFocusSession(preserveTime:)` - Starts tracking, optionally preserving time
- `resetFocusState()` - Resets timer and state
- `handleBrowserFocusActivated()` - Handles browser focus activation
- `handleFocusAppInFront()` - Handles app focus activation

### Browser Integration Flow

1. Extension detects tab change → sends `tab_changed` to `localhost:8942`
2. `HTTPServer` receives message → calls `BrowserManager.updateFromExtension()`
3. `BrowserManager` checks if URL matches focus URLs → updates `isBrowserInFocus`
4. `BrowserManagerDelegate` notifies `FocusManager` → `handleBrowserFocusActivated()` or `handleBrowserFocusDeactivated()`

**Important:** Browser focus and app focus share the same timer (`timeSpent`). When switching between them, time is preserved.

## Common Tasks & Patterns

### Adding a New Focus App

1. User selects app via `FocusManager.selectFocusApplication()`
2. App info extracted from bundle → `AppInfo` created
3. Added to `focusApps` array → persisted via `UserDefaultsManager`
4. `AppMonitor` automatically picks up new apps via `updateFocusApps()`

### Modifying Focus Detection Logic

**Timer Reset Logic:**

- Reset when: leaving focus entirely (focus → non-focus)
- Preserve when: switching between focus contexts (app ↔ browser, app ↔ app, browser ↔ browser)

**Key Check:** Use `isChromeBrowserFrontmost()` to distinguish:

- Tab switching (Chrome still frontmost) → reset
- App switching (Chrome not frontmost) → preserve if switching to focus app

### Browser Focus State Management

**Critical Pattern:** When browser focus deactivates:

```swift
if isChromeStillFrontmost {
    // Just switching tabs → reset timer
    resetFocusState()
} else if isSwitchingToFocusApp {
    // Switching to focus app → preserve time
    // Don't reset
} else {
    // Leaving focus entirely → reset
    resetFocusState()
}
```

### License Management

**Checking Premium Features:**

```swift
if licenseManager.isLicensed {
    // Premium feature available
    // Check maxAppsAllowed for limits (-1 = unlimited)
} else {
    // Free tier limits apply
}
```

**Default Limits:**

- Free: 3 focus apps, 3 focus URLs
- Licensed: Unlimited (or `maxAppsAllowed` from license)

## Code Style Guidelines

### Naming Conventions

- Managers: `*Manager` (e.g., `FocusManager`, `BrowserManager`)
- Protocols: `*Managing` or `*Protocol` (e.g., `BrowserManaging`, `AppMonitoring`)
- Views: `*View` (e.g., `ConfigurationView`, `InsightsView`)
- ViewModels: `*ViewModel` (e.g., `ConfigurationViewModel`)

### State Updates

- Use `batchUpdate()` for multiple `@Published` property updates
- Defer delegate notifications to avoid publishing during view updates
- Use `DispatchQueue.main.async` for UI updates from background threads

### Error Handling

- Log errors with context: `print("FocusManager: Error message - \(error)")`
- Graceful degradation: Don't crash on non-critical errors
- User-facing errors: Show in UI, log details to console

## Testing Patterns

### Unit Tests

- Test managers with mock dependencies
- Test state transitions (focus → non-focus, buffer periods)
- Test timer preservation logic

### Common Test Scenarios

1. Switching between focus apps → timer continues
2. Switching focus app → browser focus → timer continues
3. Switching focus tab → non-focus tab → timer resets
4. Buffer period timeout → session ends

## Debugging Tips

### Focus State Issues

- Check `isFocusAppActive` vs `isBrowserInFocus` vs `isInOverallFocus`
- Verify `timeSpent` is preserved when switching contexts
- Check if `timeTrackingTimer` is running

### Browser Integration Issues

- Verify HTTP server is running on port 8942
- Check extension connection state: `isExtensionConnected`
- Monitor `BrowserManager` logs for tab updates

### License Issues

- Check `licenseManager.isLicensed` state
- Verify `maxAppsAllowed` is set correctly (-1 for unlimited)
- Check license validation errors in logs

## File Organization

```
App/          # Entry points (AutoFocusApp, AppDelegate, AppConfiguration)
Services/     # All managers and services (FocusManager, BrowserManager, etc.)
Database/     # SQLite/GRDB persistence layer
Models/       # Data structures (FocusSession, BrowserModels, ExportData, etc.)
Views/        # All SwiftUI views
Utilities/    # Logger, SafeImageLoader, TimeFormatter, ResourceManager
Mocks/        # Test doubles
Protocols/    # Manager protocols for dependency injection
```

## Quick Commands

```bash
# Build
make build

# Test
make test

# Release (manual)
make manual-release

# Clean
make clean
```

## When Making Changes

1. **Focus Logic Changes:** Update `FocusManager` and test state transitions
2. **Browser Changes:** Update `BrowserManager` and `HTTPServer`, test extension communication
3. **UI Changes:** Update SwiftUI views, ensure `@Published` properties trigger updates
4. **License Changes:** Update `LicenseManager`, test free vs. premium behavior

## Questions to Ask

Before making changes, consider:

- Does this affect timer preservation logic?
- Should this reset or preserve `timeSpent`?
- Is Chrome still the frontmost app?
- Are we switching between focus contexts or leaving focus?
- Does this require license checking?

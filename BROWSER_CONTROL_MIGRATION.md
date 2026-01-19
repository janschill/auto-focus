# Browser Extension to Accessibility API Migration

## Overview

This PR migrates Auto-Focus from using a browser extension to using macOS's native Accessibility API for browser URL tracking. This eliminates the need for users to install a browser extension while maintaining all functionality.

## Key Changes

### 1. New Browser URL Monitor (`BrowserURLMonitor.swift`)
- **Purpose**: Monitors browser URL using macOS Accessibility API (AXUIElement)
- **Supported Browsers**: Chrome, Safari, Edge, Brave, Arc, Opera, Vivaldi, and other Chromium-based browsers
- **How it Works**:
  - Polls the frontmost browser application every 2 seconds
  - Uses AXUIElement API to extract URL from browser's accessibility tree
  - Different strategies for different browsers:
    - Safari: Uses `AXDocument` attribute
    - Chrome/Chromium: Searches for address bar text field
  - Notifies BrowserManager when URL changes

### 2. Updated Browser Manager (`BrowserManager.swift`)
- **Removed**: HTTPServer and all browser extension communication code
- **Added**:
  - Integration with BrowserURLMonitor
  - Accessibility permission checking and requesting
  - `hasAccessibilityPermission` property
  - `requestAccessibilityPermission()` method
  - `checkAccessibilityPermission()` method
- **Simplified**: No more connection timeouts, heartbeats, or extension health monitoring

### 3. Updated Onboarding (`OnboardingView.swift`)
- **Changed Browser Integration Step**:
  - Renamed to "Website Context & URL (Browser Control)"
  - Requests Accessibility permission instead of extension installation
  - Added clear privacy messaging: "Your browsing data never leaves your computer"
  - Shows permission status and guides users to System Settings
  - Only shows website configuration after permission is granted

### 4. Updated Browser Config View (`BrowserConfigView.swift`)
- **Replaced Extension Installation Section** with Accessibility Permission Section:
  - Shows permission status (Granted/Not granted)
  - Button to open System Settings for permission grant
  - Clear privacy messaging with lock shield icon
  - Step-by-step instructions for granting permission
- **Updated Header**: Emphasizes local processing and privacy

### 5. Updated Focus Manager (`FocusManager.swift`)
- **Removed Properties**:
  - `isExtensionConnected`
  - `extensionHealth`
  - `connectionQuality`
- **Added Methods**:
  - `hasBrowserAccessibilityPermission` (computed property)
  - `requestBrowserAccessibilityPermission()`
  - `checkBrowserAccessibilityPermission()`
- **Removed Delegate Methods**:
  - `didChangeConnectionState`
  - `didUpdateExtensionHealth`
  - `didUpdateConnectionQuality`

### 6. Updated Info.plist
- **Added Privacy Description**:
  - `NSAccessibilityUsageDescription`: Clear message explaining URL monitoring is local-only

## Privacy & Security

### Privacy-First Approach
- ✅ **No external dependencies**: No browser extension to install
- ✅ **100% local processing**: All URL checking happens on the user's computer
- ✅ **No network requests**: Unlike the extension which communicated via HTTP, Accessibility API is entirely local
- ✅ **Clear messaging**: UI explicitly states data never leaves the computer
- ✅ **Native permissions**: Uses standard macOS permission system users are familiar with

### Permission Requirements
- **Accessibility Permission**: Required for reading browser URL
  - User grants via System Settings → Privacy & Security → Accessibility
  - Standard macOS permission dialog
  - Can be revoked at any time

## Technical Details

### Accessibility API Approach

The implementation uses several strategies to extract URLs from browsers:

1. **Safari**: 
   ```swift
   AXUIElementCopyAttributeValue(window, "AXDocument" as CFString, &document)
   ```

2. **Chrome/Chromium-based**:
   - Searches accessibility tree for address bar (AXTextField with specific role)
   - Extracts value from the text field
   - Falls back to multiple strategies if primary method fails

3. **Polling Interval**: 2 seconds (configurable via `AppConfiguration.checkInterval`)

### Error Handling
- Gracefully handles missing permissions
- Falls back silently if browser doesn't expose URL via Accessibility API
- Logs errors for debugging but doesn't crash

### Performance
- Minimal CPU usage: Only polls when browser is frontmost
- Stops monitoring when system sleeps
- No network overhead (unlike HTTP server approach)

## Migration Path

### For Users
1. Update app
2. Go through new onboarding or visit Browser Configuration
3. Grant Accessibility permission when prompted
4. Configure focus URLs as before
5. Browser extension is no longer needed (can be uninstalled)

### For Developers
- HTTPServer code remains in repo (may be used elsewhere) but is not instantiated
- BrowserManager.swift.bak contains old implementation for reference
- All tests should pass with new implementation

## Benefits

1. **Simpler Setup**: No browser extension to install
2. **Better Privacy**: No HTTP communication, all local
3. **Native Integration**: Uses standard macOS permissions
4. **Cross-Browser**: Works with Safari, Chrome, Edge, Brave, Arc, etc.
5. **More Reliable**: No connection issues, heartbeats, or timeouts to manage
6. **Reduced Attack Surface**: No HTTP server listening on localhost

## Known Limitations

1. **Requires Accessibility Permission**: Users must grant this in System Settings
2. **Browser-Specific**: Different browsers expose URLs differently; some may not work
3. **Polling-Based**: 2-second delay before URL changes are detected (vs instant with extension)
4. **macOS Only**: Accessibility API is macOS-specific

## Testing Recommendations

1. Test with multiple browsers (Safari, Chrome, Edge, Brave, Arc)
2. Verify permission request flow works correctly
3. Test URL detection with various websites
4. Verify focus detection works when switching tabs
5. Test system sleep/wake behavior
6. Verify onboarding guides users properly

## Future Improvements

1. Consider using `FSEventStreamCreate` or similar for more efficient detection
2. Add support for Firefox (different accessibility structure)
3. Implement caching to reduce Accessibility API calls
4. Add telemetry to understand which browsers work best

## Questions for Review

1. Should we keep HTTPServer.swift or remove it completely?
2. Should we remove the browser-extension directory from the repo?
3. Do we need to update README with new setup instructions?
4. Should we add a migration notice for existing users?

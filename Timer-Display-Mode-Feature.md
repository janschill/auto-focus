# Timer Display Mode Feature

This feature addresses [Issue #41](https://github.com/janschill/auto-focus/issues/41) where users requested the ability to hide or make the menu bar timer less distracting.

## Problem
Users found the constantly updating timer in the menu bar (showing "12:34" format that updates every second) to be distracting while working.

## Solution
Added a configurable timer display mode preference with three options:

### 1. Hidden Mode 🚫
- **Purpose**: Complete elimination of timer distraction
- **Display**: No timer shown in menu bar, only the brain icon
- **Use case**: Users who want zero visual distraction

### 2. Simplified Mode 📊
- **Purpose**: Minimal distraction with basic time awareness
- **Display**: Shows minutes only (e.g., "12m")
- **Updates**: Only once per minute instead of every second
- **Use case**: Users who want some time awareness but less frequent updates

### 3. Full Mode (Default) ⏱️
- **Purpose**: Precise timing information
- **Display**: Shows full timer format (e.g., "12:34")
- **Updates**: Every second (current behavior)
- **Use case**: Users who prefer detailed timing information

## Implementation Details

### Files Modified
- `TimerDisplayMode.swift` - New enum with three display options
- `FocusManager.swift` - Added timerDisplayMode property with persistence
- `UserDefaultsManager.swift` - Added new preference key
- `ConfigurationView.swift` - Added UI control in General settings
- `AutoFocusApp.swift` - Updated menu bar logic to respect preference

### Technical Features
- **Persistence**: Setting is saved to UserDefaults and persists across app restarts
- **Real-time Updates**: Changes take effect immediately without restart
- **Backward Compatibility**: Defaults to "Full" mode for existing users
- **Type Safety**: Uses enum with proper Codable support

### Testing
- Comprehensive unit tests in `TimerDisplayModeTests.swift`
- Validation of enum properties, persistence, and default behavior
- Manual testing with verification script

## User Experience
1. User opens Auto-Focus settings
2. Navigates to Configuration tab
3. Finds "Timer Display" setting in General section
4. Selects preferred option from dropdown
5. Timer display in menu bar updates immediately

This feature directly addresses the user feedback: *"I think the second timer is a bit distracting, so I would love an option to hide the timer, or change it to '1min' or something that don't update so frequently"*

## Screenshots
- `timer-display-mode-feature-demo.png` - Complete feature overview
- `menubar-timer-comparison.png` - Visual comparison of all three modes
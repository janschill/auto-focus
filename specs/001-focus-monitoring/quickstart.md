# Quickstart: Foreground Focus Monitoring

**Feature**: `specs/001-focus-monitoring/spec.md`
**Created**: 2025-12-16

## What you’re building
A macOS SwiftUI app that:

- Monitors the foreground application
- When the foreground app is a browser, derives the active **domain**
- Counts time spent in configured focus entities (apps + domains)
- After the configured duration, silently disables notifications by running a provided Shortcut
- Records sessions/events into SQLite and shows insights

## Build & run (developer)

1. Open `auto-focus.xcodeproj` in Xcode.
2. Build and run the app target for the new implementation (planned target: `AutoFocus2`).
3. Ensure the app has a visible menu bar entry for status + settings.

## Required setup (user/dev machine)

### 1) Install the provided Shortcut
- Import the Shortcut file you provide into the macOS Shortcuts app.
- In the app settings, select or confirm the Shortcut name used for notification toggling.

### 2) Grant permissions
The app MUST guide the user through permission prompts and show clear “blocked/unavailable” states.

- **Apple Events / Automation** (needed for running Shortcuts and possibly reading browser URL):
  - Allow control of `System Events`
  - Allow control of `Shortcuts` / `Shortcuts Events`
  - (If domain extraction uses Apple Events) allow control of the browser (Safari/Chrome)
- **Accessibility**: only required if we adopt an accessibility-based fallback. Prefer avoiding it.

### 3) Configure focus entities and timers
- Add focus applications (bundle-based selection)
- Add focus domains (domain strings)
- Set:
  - Activation duration (minutes)
  - Focus-loss buffer (seconds)

### 4) Enable Launch on Login (optional)
- Toggle “Launch on login” in settings.

## Verification checklist (manual smoke)

- Foreground app changes are reflected in the app state quickly (within ~2 seconds).
- When staying within focus entities long enough, notifications disable without UI activation.
- Leaving focus entities ends focus mode; buffer prevents immediate session loss while buffering.
- Domain tracking shows “unavailable” rather than wrong data if permissions are missing.
- Insights persist across app restarts (SQLite).



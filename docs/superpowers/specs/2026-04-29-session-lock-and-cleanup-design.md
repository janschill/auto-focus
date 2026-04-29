# End sessions on screen lock & improve session cleanup

**Date:** 2026-04-29

## Problem

Two related issues with focus session lifecycle and management:

1. **Sessions don't end when the Mac sleeps or locks.** `AppMonitor` listens for screen-lock and sleep notifications and sets `isScreenLocked = true`, which only suppresses its app-activity check. The independent `FocusTimer` keeps ticking, so timer state and the active session persist across an indefinite lock. When the user unlocks (potentially hours later), the session continues as if no time had passed, polluting session data with phantom focus time.

2. **No bulk cleanup of short sessions.** The data tab and `SessionListView` support filtering and per-row deletion, but there's no way to delete all sessions matching a filter (e.g., the many sub-1-minute sessions that exist today, partly as a side effect of issue #1). Removing them one by one is impractical.

## Goals

- Ending the session deterministically when the screen locks or the system sleeps.
- Treating unlock as a fresh start — no automatic resumption.
- Letting the user clean up many short sessions at once with a small, targeted UI addition.

Non-goals:

- Multi-select / checkbox UI in the session list.
- Automatic deletion of short sessions on save.
- A separate "Cleanup" tab.

## Part 1 — End session on screen lock/sleep

### Behavior

When any of these notifications fires:

- `NSWorkspace.screensDidSleepNotification`
- `NSWorkspace.willSleepNotification`
- `com.apple.screenIsLocked` (DistributedNotificationCenter)

Auto-Focus runs the same lifecycle decision used by buffer timeout and pause:

- If `didReachFocusThreshold == true` → `sessionManager.endSession()` (saves the session ending at the moment of lock/sleep).
- Otherwise → `sessionManager.cancelCurrentSession()` (discard pre-threshold accumulated time).
- Reset focus state (`resetFocusState()`).
- If focus mode (DND) is currently on, turn it off (`focusModeController.setFocusMode(enabled: false)`), matching the existing buffer-timeout path.
- Cancel any active buffer (`bufferManager.cancelBuffer()`) so a stale buffer doesn't fire after lock.

On `NSWorkspace.screensDidWakeNotification` and `com.apple.screenIsUnlocked` → no automatic restart. Normal `AppMonitor` activity continues; if the user is on a focus app, a new session begins from zero on the next tick.

### Where the change lives

Move screen-lock/sleep observation out of `AppMonitor` and into `FocusManager`. Rationale: `AppMonitor`'s job is detecting which app is frontmost; session lifecycle is owned by `FocusManager`. Today's coupling — `AppMonitor` setting a flag that gates `checkActiveApp()` — is incomplete (it doesn't end the session) and split across the wrong abstraction.

Concrete changes:

- **`FocusManager`:**
  - New private `setUpScreenLockObservers()` called from `init`, plus a corresponding teardown in `deinit`.
  - New private `handleScreenInactive()` method implementing the behavior above.
  - Observers wired to: `NSWorkspace.screensDidSleepNotification`, `NSWorkspace.willSleepNotification`, and the distributed `com.apple.screenIsLocked` notification — all routing to `handleScreenInactive()`.
  - No wake/unlock observer needed — there's nothing to do.
  - Respect `isPaused`: if the user has manually paused, lock is a no-op (the session is already cancelled).

- **`AppMonitor`:**
  - Remove `isScreenLocked` field and the `observeScreenLockState()` / `removeScreenLockObservers()` / four `@objc handleScreen*` methods.
  - Remove the `guard !isScreenLocked else { return }` from `checkActiveApp()`.
  - Once `FocusManager` ends the session on lock, there's no live session for `AppMonitor` to corrupt; if a focus app happens to be frontmost when the screen locks, `AppMonitor` won't start a new session because the user's bundle didn't change (`didChangeToApp` only fires on transitions).

### Edge cases

- **Lock during buffer period.** Buffer is cancelled by `handleScreenInactive()`. The same `didReachFocusThreshold` check decides save vs. discard. No double-save (the buffer's own `bufferManagerDidTimeout` callback is cancelled with the buffer).
- **Sleep without lock** (rare on macOS but possible). `screensDidSleepNotification` and `willSleepNotification` both route to the same handler; whichever fires first wins, the second is a no-op because the session is already gone.
- **App quits while locked.** Existing `deinit` paths still apply — no new behavior needed.
- **User has manually paused.** `handleScreenInactive()` returns early when `isPaused` is true; nothing to end.

## Part 2 — Bulk session cleanup

### Data tab — cleanup hint

Inside `DataSessionManagementView`'s GroupBox, when `focusManager.focusSessions.contains(where: { $0.duration < 60 })`, show a single row beneath the existing stats:

```
⚠  N sessions under 1 minute       [Review & clean up]
```

Where `N` is the count. The button opens the existing `SessionListView` sheet with `filterDuration` pre-set to `.veryShort` and `sortOrder` pre-set to `.oldest`. When the count is zero, the row is hidden entirely.

Implementation: pass two optional initial values into `SessionListView` (`initialFilter`, `initialSort`) used to seed `@State` on first render. Existing callers from elsewhere don't need to change.

### Session List — bulk delete by filter

In `SessionListView.sessionControlsHeader`, when `filterDuration != .all` and `filteredAndSortedSessions.count > 0`, show a destructive button on the trailing edge of the filter row:

```
[Filter: Very Short (<1m) ▼]  [Sort: Oldest First ▼]    [Delete N sessions]
```

When `filterDuration == .all`, the button is hidden — bulk delete is intentionally gated behind picking a filter, to prevent accidental "delete everything."

Click flow:

1. Click → SwiftUI alert: "Delete N sessions matching '<filter name>'? This cannot be undone." with Cancel / Delete (destructive) buttons.
2. Confirm → call `focusManager.deleteSessions(filteredAndSortedSessions)`.
3. The existing GRDB observer in `SessionManager` updates `focusSessions`, which re-renders the list (now empty for the filter, falling back to `emptyStateView`).

Reuse the existing `showingDeleteConfirmation` infrastructure if convenient, or add a separate `showingBulkDeleteConfirmation` state — the latter is cleaner because the message text differs.

### SessionManager — bulk delete API

```swift
func deleteSessions(_ sessions: [FocusSession])
```

Wraps the deletes in a single GRDB write transaction (via `SessionRepository`). Logs count and any error. `FocusManager.deleteSessions(_:)` is a thin pass-through.

`SessionRepository` gets a `deleteAll(_ sessions: [FocusSession]) throws` method using GRDB's `deleteAll(_:keys:)` (or equivalent batch path) so the delete is atomic.

## Testing

- **Lock-end behavior:** Manual test — start a focus session, reach threshold, lock the screen (Ctrl+Cmd+Q), unlock, verify session was saved with end time at lock moment. Repeat without reaching threshold; verify no session was saved.
- **Sleep-end behavior:** Same as above but trigger sleep instead of lock.
- **Lock during buffer:** Start session, switch to non-focus app to enter buffer, lock; verify session ends correctly.
- **Bulk delete:** With a populated session list, filter to Very Short, click Delete N; verify count decreases and DB no longer has those rows.
- **Bulk delete confirmation cancel:** Verify cancel doesn't delete anything.
- **Cleanup hint visibility:** With zero short sessions, hint is absent. Add one, hint appears with count "1".
- **Existing unit tests:** Anything testing `AppMonitor`'s `isScreenLocked` gating needs to be removed (the field is gone). `FocusManager` tests gain coverage for `handleScreenInactive()`.

## Out of scope

- A retroactive one-time cleanup migration. The new bulk-delete UI handles existing phantom sessions naturally — sort by longest, identify suspicious entries, delete.
- Persisting filter/sort state across app launches.
- Selecting individual sessions across multiple filters in one operation.

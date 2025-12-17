# Contract: Shortcut Toggle (Notifications)

**Feature**: `specs/001-focus-monitoring/spec.md`
**Created**: 2025-12-16

## Purpose
Define the contract for how the app triggers notification suppression via a user-provided Shortcut.

## Inputs
- **Shortcut name**: A human-readable Shortcut name configured in the app (default can be provided).
- **Desired state**: `enabled` / `disabled` for notifications (internally may be represented as “focus mode on/off”).

## Behavior requirements
- The app MUST execute the Shortcut **without activating** any UI (silent execution).
- The app MUST handle missing Shortcuts app and missing Shortcut name gracefully (user-visible error state).
- The app MUST NOT assume the Shortcut “toggles” correctly unless it can track state; if state cannot be verified, the app MUST fail safe (avoid repeated toggles that could flip the wrong way).

## Execution mechanism
AppleScript via Apple Events, conceptually:

- `System Events` → `Shortcuts Events` → `run shortcut "<ShortcutName>" without activating`

## Permissions
- The app will require Apple Events permission to control:
  - `System Events`
  - `Shortcuts Events` (and/or `Shortcuts`)

## Observability
- Log success/failure with error messages, but do not log sensitive user data.



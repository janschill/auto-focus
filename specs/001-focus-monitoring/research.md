# Research: Foreground Focus Monitoring

**Feature**: `specs/001-focus-monitoring/spec.md`
**Plan**: `specs/001-focus-monitoring/plan.md`
**Created**: 2025-12-16

This document records key technical decisions and tradeoffs needed to implement the spec while
conforming to the constitution (deterministic core, isolated side-effects, test discipline, UX,
privacy).

## Decision: Foreground application detection

- **Decision**: Use `NSWorkspace.shared.frontmostApplication` polling with a small interval (e.g. ~1–2s) and a “changed app” event.
- **Rationale**: Simple, reliable, low dependency, and already proven in the legacy code.
- **Alternatives considered**:
  - Accessibility-based foreground/window queries: more powerful but heavier permissions and more complexity.
  - NSWorkspace notifications only: can be incomplete across edge cases; polling is simpler and predictable.

**Reference behavior**: Legacy implementation polls `NSWorkspace.shared.frontmostApplication` and emits app-change + focus-app-change events (see `Legacy/auto-focus/AppMonitor.swift`).

## Decision: Browser domain extraction

- **Decision**: Prefer a browser-domain provider with multiple strategies, ordered by reliability:
  1. Apple Events (AppleScript / ScriptingBridge) for Safari + Chrome to read the active tab URL and derive domain.
  2. Fallback to “domain unavailable” state when extraction fails or permission is missing.
- **Rationale**: Meets the product need (domain-level), aligns with privacy constraints (domain only), and matches the user’s desired “Browser control / website context” permission model.
- **Alternatives considered**:
  - Browser extension + localhost bridge: higher reliability for Chromium, but adds an extension distribution and an HTTP surface.
  - AX (Accessibility) scraping of address bar: fragile across browser updates and UI states.

**Privacy rule**: Store domain only, never full URL or page title (spec FR-013).

## Decision: Focus mode toggling (Disable notifications)

- **Decision**: Use AppleScript with `System Events` to run a provided Shortcut “without activating” (silent).
- **Rationale**: Simple, user-provided automation, avoids deep integration with notification APIs, matches existing working approach.
- **Alternatives considered**:
  - Direct Focus/Do Not Disturb APIs: constrained/unsupported depending on macOS version and entitlements.
  - Running `shortcuts` CLI: can work but still requires automation permissions and is less “silent” in some cases.

**Reference behavior**: Legacy `FocusModeManager` runs:
`tell application "System Events" → tell application "Shortcuts Events" → run shortcut "<name>" without activating`.

## Decision: Launch on login

- **Decision**: Implement “Launch on Login” via the platform mechanism (ServiceManagement / login item).
- **Rationale**: Standard macOS behavior, good UX, minimal dependencies.
- **Alternatives considered**:
  - Manual LaunchAgent plist: harder UX and less aligned with user expectations.

## Decision: Permissions & user messaging

- **Decision**: Treat permissions as first-class state with explicit UX:
  - Foreground app detection: typically no special permission beyond normal app execution.
  - Apple Events permissions: required for controlling Shortcuts (and potentially browsers for URL extraction).
  - Accessibility (“Detecting Activity”): MAY be required if we add deeper activity/window title tracking. For domain-only, prefer not requiring AX unless unavoidable.
- **Rationale**: Prevent false activations; make failures understandable; align with “fail safe” constitution gate.

## Decision: Persistence (SQLite) and data retention

- **Decision**: Use SQLite for all focus events/sessions/entities and keep a schema version for migration.
- **Rationale**: Durable, fast, queryable for “rich insights”; minimal dependencies (use system SQLite).
- **Alternatives considered**:
  - Core Data: stronger tooling but heavier and less transparent for custom analytics queries.
  - Flat files: simple but becomes difficult for insights queries and migrations.

## Decision: Deterministic domain/state machine core

- **Decision**: Implement a pure-ish state machine driven by events:
  - `foregroundAppChanged`
  - `foregroundDomainChanged` (only when browser + domain resolvable)
  - time ticks (from a controllable clock)
  - configuration updates
- **Rationale**: Enables unit testing of buffer behavior and uninterrupted timing without wall-clock flakiness.

## Decision: Licensing (license key + API validation)

- **Decision**: Use a license key entered by the user and validated via an API call. Cache the last-known-good license status and treat offline/validation failures as non-blocking (core focus still works, premium gates do not unlock).
- **Rationale**: Matches previously working behavior and enables day-1 premium gating without App Store complexity.
- **Alternatives considered**:
  - App Store subscription/receipt: different distribution model and significantly more integration work.
  - Local-only “license file”: easier but weaker controls and harder to manage revocations.

**UX requirement**: Validation status must be visible and actionable (e.g., “offline”, “invalid key”, “service unavailable”).



# Implementation Plan: Foreground Focus Monitoring

**Branch**: `001-focus-monitoring` | **Date**: 2025-12-16 | **Spec**: `specs/001-focus-monitoring/spec.md`
**Input**: Feature specification from `specs/001-focus-monitoring/spec.md`

**Note**: This template is filled in by the `/speckit.plan` command. In this repo, the supporting workflow lives in `.specify/scripts/bash/setup-plan.sh` (and related scripts in `.specify/scripts/bash/`).

## Summary

Build a macOS menu bar app that monitors the foreground application and (when the foreground app
is a browser) the active domain. Users configure a set of “focus entities” (apps + domains), a
global focus activation duration (minutes), and a focus-loss buffer (seconds). When uninterrupted
time spent within the configured focus entities reaches the duration, the app silently disables
notifications (via running a provided Shortcuts automation through AppleScript). The app records
focus sessions and events in SQLite to power insights (daily totals, per-entity breakdowns, and
session history).

Premium (day 1): enforce free-tier limits (max focus entities, limited insights depth, no export)
and support license-key validation via API to unlock premium immediately.

## Technical Context

<!--
  ACTION REQUIRED: Replace the content in this section with the technical details
  for the project. The structure here is presented in advisory capacity to guide
  the iteration process.
-->

**Language/Version**: Swift 5.9+ (Xcode-managed; exact version pinned by Xcode project)
**Primary Dependencies**: SwiftUI (minimal dependencies; prefer system frameworks)
**Storage**: SQLite (local file DB; schema versioned and migrated)
**Testing**: XCTest (unit tests for state machine + persistence + adapters via mocks)
**Target Platform**: macOS 13+ (assumption; adjust if the Xcode project targets a different minimum)
**Project Type**: single (macOS app + tests)
**Performance Goals**: Near-real-time status updates (foreground changes reflected within ~2s; focus activation within 5s of threshold)
**Constraints**: Offline-capable; no sensitive browsing content stored (domain only); minimal CPU usage while monitoring; license validation failures must not block core focus functionality
**Scale/Scope**: Single-user local app; months/years of events; thousands of sessions and entities without noticeable UI lag

## Constitution Check

*GATE: Must pass before Phase 0 research. Re-check after Phase 1 design.*

- GATE: Business logic MUST be deterministic and independently unit-testable (pure-ish state machine + controllable clock).
- GATE: macOS APIs (foreground app detection, AppleScript/Shortcuts invocation, accessibility, browser queries) MUST be behind protocols/adapters.
- GATE: Any behavior change MUST be protected by tests; bug fixes MUST include regression tests.
- GATE: UX MUST be consistent and accessible; user-visible states/errors must be explicit and non-confusing.
- GATE: Privacy: store domain only (no full URLs, page titles, or content); logs MUST NOT include sensitive data.
- GATE: Fail safe: no crashes on missing permissions; no false focus activations on unknown browser/domain state.

## Project Structure

### Documentation (this feature)

```text
specs/001-focus-monitoring/
├── plan.md              # This file (/speckit.plan command output)
├── research.md          # Phase 0 output (/speckit.plan command)
├── data-model.md        # Phase 1 output (/speckit.plan command)
├── quickstart.md        # Phase 1 output (/speckit.plan command)
├── contracts/           # Phase 1 output (/speckit.plan command)
└── tasks.md             # Phase 2 output (/speckit.tasks command - NOT created by /speckit.plan)
```

### Source Code (repository root)
<!--
  ACTION REQUIRED: Replace the placeholder tree below with the concrete layout
  for this feature. Delete unused options and expand the chosen structure with
  real paths (e.g., apps/admin, packages/something). The delivered plan must
  not include Option labels.
-->

```text
auto-focus2/                       # New greenfield macOS app implementation (SwiftUI)
├── App/                           # App entry + composition root
├── Domain/                        # Pure-ish state machine + entities (testable)
├── Adapters/                      # Foreground monitoring, browser domain provider, shortcut runner
├── Persistence/                   # SQLite schema + repositories
├── UI/                            # SwiftUI views + view models
└── Resources/                     # Assets / misc

├── Tests/                         # XCTest unit tests
│   ├── DomainTests/
│   ├── PersistenceTests/
│   └── AdapterTests/
└── AutoFocus2.xcodeproj/          # New Xcode project for the rewrite
```

**Structure Decision**: Create a new greenfield module tree under `auto-focus2/` with a separate test target `auto-focus2Tests/`. The existing codebase remains as reference; new implementation uses protocol-driven adapters and a deterministic core to satisfy the constitution gates.

## Complexity Tracking

> **Fill ONLY if Constitution Check has violations that must be justified**

| Violation | Why Needed | Simpler Alternative Rejected Because |
|-----------|------------|-------------------------------------|
| [e.g., 4th project] | [current need] | [why 3 projects insufficient] |
| [e.g., Repository pattern] | [specific problem] | [why direct DB access insufficient] |

---

description: "Task list for Foreground Focus Monitoring"
---

# Tasks: Foreground Focus Monitoring

**Input**: Design documents from `specs/001-focus-monitoring/`
**Prerequisites**: `plan.md` (required), `spec.md` (required for user stories), plus `research.md`, `data-model.md`, `contracts/`, `quickstart.md`

**Tests**: Tests are REQUIRED for behavior changes unless explicitly waived with a rationale (constitution).

**Organization**: Tasks are grouped by user story to enable independent implementation and testing of each story.

## Format: `[ID] [P?] [Story] Description`

- **[P]**: Can run in parallel (different files, no dependencies)
- **[Story]**: Which user story this task belongs to (e.g., US1, US2, US3)
- Include exact file paths in descriptions

## Phase 1: Setup (Shared Infrastructure)

**Purpose**: Create the greenfield code layout and Xcode targets per plan.

- [x] T001 Create feature code directories per plan at auto-focus2/{App,Domain,Adapters,Persistence,UI,Resources}/
- [x] T002 Create test target directories per plan at auto-focus2/Tests/{DomainTests,PersistenceTests,AdapterTests}/
- [x] T003 Ensure AutoFocus2 app target exists and is wired to auto-focus2/{App,Domain,Adapters,Persistence,UI,Resources}/ (auto-focus2/AutoFocus2.xcodeproj/project.pbxproj)
- [x] T004 Add new Xcode test target for greenfield tests and connect it to auto-focus2/Tests/ (auto-focus2/AutoFocus2.xcodeproj/project.pbxproj)
- [x] T005 [P] Add a minimal `auto-focus2/App/AutoFocus2App.swift` SwiftUI entrypoint with a menu bar UI shell
- [x] T006 [P] Add build/test Makefile targets (or document Xcode equivalents) for the new targets in Makefile

---

## Phase 2: Foundational (Blocking Prerequisites)

**Purpose**: Implement the deterministic core + adapters + persistence seams that every story depends on.

**⚠️ CRITICAL**: No user story work can begin until this phase is complete.

- [x] T007 Create domain models in auto-focus2/Domain/FocusModels.swift (FocusEntity, FocusSettings, FocusEvent, FocusSession)
- [x] T008 Create domain state machine in auto-focus2/Domain/FocusStateMachine.swift (counting → focusMode → buffer → idle)
- [x] T009 Create controllable clock/ticker abstraction in auto-focus2/Domain/Clock.swift (testable time progression)
- [x] T010 Create protocols for side effects in auto-focus2/Domain/Ports.swift (ForegroundProvider, BrowserDomainProvider, NotificationsController, Persistence)
- [x] T011 Create app composition root wiring in auto-focus2/App/CompositionRoot.swift (dependency injection)
- [x] T012 Create logging façade in auto-focus2/App/Logging.swift (no sensitive data, domain-only)

- [x] T013 Create SQLite database wrapper and migration runner in auto-focus2/Persistence/SQLite/SQLiteDatabase.swift
- [x] T014 Create schema + migrations in auto-focus2/Persistence/SQLite/Migrations.swift (PRAGMA user_version, forward-only migrations)
- [x] T015 Create repositories in auto-focus2/Persistence/Repositories/ (FocusSettingsRepository, FocusEntityRepository, FocusEventRepository, FocusSessionRepository)

- [x] T016 Create “Launch on Login” service interface + implementation in auto-focus2/Adapters/LaunchOnLogin/LaunchOnLoginService.swift
- [x] T017 Create AppleScript shortcut runner in auto-focus2/Adapters/Shortcuts/ShortcutRunner.swift (per specs/001-focus-monitoring/contracts/shortcut-toggle.md)
- [x] T018 Create foreground app monitor adapter in auto-focus2/Adapters/Foreground/ForegroundAppMonitor.swift (polling NSWorkspace)
- [x] T019 Create browser domain provider adapter in auto-focus2/Adapters/Browser/BrowserDomainProvider.swift (Safari + Chrome strategy + unavailable states; per specs/001-focus-monitoring/contracts/browser-domain.md)

**Checkpoint**: Foundation ready — the app can observe current context, simulate time in tests, persist, and toggle notifications via the shortcut adapter.

---

## Phase 3: User Story 1 - Onboarding, setup, and licensing (Priority: P1) 🎯 MVP

**Goal**: Users can complete onboarding to set up permissions + Shortcut, configure focus entities and timers, and enter a license key to unlock premium gates. Free-tier limits apply day 1.

**Independent Test**: From a fresh install: complete onboarding, configure entities/timers, verify free-tier max-entities enforcement, enter a valid license key and verify premium unlocks immediately.

### Tests for User Story 1 (REQUIRED unless explicitly waived) ⚠️

> NOTE: Write these tests FIRST, ensure they FAIL before implementation.

- [x] T020 [P] [US1] Add license validation client tests (success/invalid/offline) in auto-focus2/Tests/AdapterTests/LicenseClientTests.swift
- [x] T021 [P] [US1] Add premium gating tests for max focus entities in auto-focus2/Tests/DomainTests/PremiumGating_MaxEntitiesTests.swift
- [x] T022 [P] [US1] Add ShortcutRunner adapter tests with a mock runner in auto-focus2/Tests/AdapterTests/ShortcutRunnerTests.swift
- [x] T023 [P] [US1] Add onboarding state machine/view model tests in auto-focus2/Tests/DomainTests/OnboardingFlowTests.swift

### Implementation for User Story 1

- [x] T024 [US1] Implement configuration storage for activationMinutes + bufferSeconds in auto-focus2/Persistence/Repositories/FocusSettingsRepository.swift
- [x] T025 [US1] Implement focus entity CRUD (apps + domains) with max-entities enforcement in auto-focus2/Persistence/Repositories/FocusEntityRepository.swift
- [x] T026 [US1] Implement LicenseService + local secure key storage + cached status in auto-focus2/App/LicenseService.swift
- [x] T027 [US1] Implement license validation API client adapter per specs/001-focus-monitoring/contracts/license-api.md in auto-focus2/Adapters/License/LicenseClient.swift
- [x] T028 [US1] Add Settings UI sections for license key + premium status in auto-focus2/UI/Settings/LicenseView.swift
- [x] T029 [US1] Build onboarding flow UI in auto-focus2/UI/Onboarding/OnboardingView.swift (permissions + shortcut + license + initial config)

- [x] T030 [US1] Build Settings UI for focus entities and timers in auto-focus2/UI/Settings/SettingsView.swift
- [x] T031 [US1] Build ViewModel for Settings UI in auto-focus2/UI/Settings/SettingsViewModel.swift (binds to repositories + license status)
- [x] T032 [US1] Add “Launch on Login” toggle UI and wiring in auto-focus2/UI/Settings/LaunchOnLoginRow.swift

**Checkpoint**: User Story 1 works independently — onboarding + configuration works, free-tier limits enforced, license validation unlocks premium immediately.

---

## Phase 4: User Story 2 - Automatic focus mode from configured entities + buffer (Priority: P2)

**Goal**: The app counts uninterrupted time within configured focus entities and silently disables notifications at the threshold; leaving focus ends focus mode with a buffer window during active sessions.

**Independent Test**: Configure one focus entity and timers; simulate uninterrupted time reaching threshold and verify notifications disable; verify buffer behavior when leaving focus during an active session.

### Tests for User Story 2 (REQUIRED unless explicitly waived) ⚠️

- [x] T033 [P] [US2] Add FocusStateMachine unit tests for threshold activation in auto-focus2/Tests/DomainTests/FocusStateMachine_ActivationTests.swift
- [x] T034 [P] [US2] Add FocusStateMachine unit tests for leaving focus during countdown (resets) in auto-focus2/Tests/DomainTests/FocusStateMachine_CountdownResetTests.swift
- [x] T035 [P] [US2] Add FocusStateMachine unit tests for buffer behavior during active focus session in auto-focus2/Tests/DomainTests/FocusStateMachine_BufferTests.swift

### Implementation for User Story 2

- [x] T036 [US2] Implement orchestrator/service that binds adapters → domain → persistence in auto-focus2/App/FocusOrchestrator.swift
- [x] T037 [US2] Wire shortcut notifications toggling into orchestrator in auto-focus2/App/FocusOrchestrator.swift (calls ShortcutRunner)
- [x] T038 [US2] Record focus events (app/domain changes and state transitions) in auto-focus2/Persistence/Repositories/FocusEventRepository.swift
- [x] T039 [US2] Record focus sessions start/end in auto-focus2/Persistence/Repositories/FocusSessionRepository.swift
- [x] T040 [US2] Build Menu bar status UI in auto-focus2/UI/MenuBar/MenuBarView.swift (shows counting/focus/buffer/unavailable)

**Checkpoint**: User Stories 1 and 2 both work; focus automation + buffer works with shortcut-based notifications control.

---

## Phase 5: User Story 3 - Browser domain-based focus entities (Priority: P3)

**Goal**: When the foreground app is a supported browser, derive the active domain and count it as a focus entity when configured; fail safe when unavailable.

**Independent Test**: With a configured focus domain, switch the browser between a focus domain and a non-focus domain and verify state transitions; verify “domain unavailable” is explicit and fail-safe.

### Tests for User Story 3 (REQUIRED unless explicitly waived) ⚠️

- [ ] T041 [P] [US3] Add BrowserDomainProvider contract tests (domain only + unavailable reasons) in auto-focus2/Tests/AdapterTests/BrowserDomainProviderTests.swift
- [ ] T042 [P] [US3] Add orchestrator tests for domain focus driving the state machine using a fake provider in auto-focus2/Tests/DomainTests/DomainDrivenFocusTests.swift

### Implementation for User Story 3

- [ ] T043 [US3] Implement Safari domain extraction strategy in auto-focus2/Adapters/Browser/SafariDomainProvider.swift
- [ ] T044 [US3] Implement Chrome domain extraction strategy in auto-focus2/Adapters/Browser/ChromeDomainProvider.swift
- [ ] T045 [US3] Implement domain normalization helper (domain-only, lowercased) in auto-focus2/Domain/DomainNormalization.swift
- [ ] T046 [US3] Connect BrowserDomainProvider into FocusOrchestrator so domain updates become domain events in auto-focus2/App/FocusOrchestrator.swift
- [ ] T047 [US3] Add UI state and messaging for “domain tracking unavailable” in auto-focus2/UI/MenuBar/MenuBarView.swift

**Checkpoint**: User Stories 1–3 work; browser domains participate as focus entities with fail-safe behavior.

---

## Phase 6: User Story 4 - Insights + export (with premium depth) (Priority: P4)

**Goal**: Provide insights (daily totals, per-entity breakdowns, recent sessions) with free-tier limits on depth/breakdowns and premium unlock for full depth. Provide export for licensed users.

**Independent Test**: Generate sessions/events in a test DB; verify free-tier limits and premium unlock; verify export is blocked when unlicensed and succeeds when licensed.

### Tests for User Story 4 (REQUIRED unless explicitly waived) ⚠️

- [ ] T048 [P] [US4] Add SQLite migration + repository tests for sessions/events in auto-focus2/Tests/PersistenceTests/PersistenceMigrationTests.swift
- [ ] T049 [P] [US4] Add insights query tests (daily totals + per-entity breakdown) in auto-focus2/Tests/PersistenceTests/InsightsQueryTests.swift
- [ ] T050 [P] [US4] Add export tests (unlicensed blocked, licensed succeeds) in auto-focus2/Tests/PersistenceTests/ExportTests.swift

### Implementation for User Story 4

- [ ] T051 [US4] Implement insights query layer in auto-focus2/Persistence/Queries/InsightsQueries.swift
- [ ] T052 [US4] Implement InsightsViewModel with premium depth gating in auto-focus2/UI/Insights/InsightsViewModel.swift
- [ ] T053 [US4] Implement InsightsView with upgrade messaging in auto-focus2/UI/Insights/InsightsView.swift
- [ ] T054 [US4] Implement export generator per specs/001-focus-monitoring/contracts/export.md in auto-focus2/Persistence/Export/ExportService.swift
- [ ] T055 [US4] Add export UI entry point (licensed only) in auto-focus2/UI/Insights/ExportView.swift
- [ ] T056 [US4] Add navigation from menu bar/settings into insights UI in auto-focus2/UI/Navigation/AppNavigation.swift

**Checkpoint**: Insights and export are usable and stable; free vs premium behavior matches requirements.

---

## Phase 7: Polish & Cross-Cutting Concerns

**Purpose**: Tighten UX, stability, privacy, and operational readiness.

- [ ] T057 [P] Add permission UX flows + help text (Automation/Apple Events, optional Accessibility) in auto-focus2/UI/Permissions/PermissionsView.swift
- [ ] T058 Add error handling and user-facing error states for missing shortcut / script errors in auto-focus2/UI/Settings/ShortcutStatusView.swift
- [ ] T059 [P] Add privacy documentation note in specs/001-focus-monitoring/quickstart.md (domain-only, no titles/URLs stored)
- [ ] T060 Run quickstart verification steps and update specs/001-focus-monitoring/quickstart.md with any adjustments

---

## Dependencies & Execution Order

### Phase Dependencies

- **Setup (Phase 1)**: No dependencies
- **Foundational (Phase 2)**: Depends on Setup completion — BLOCKS all user stories
- **User Stories (Phase 3+)**: Depend on Foundational completion; implement in priority order P1 → P2 → P3
- **Polish (Phase 6)**: After core stories; can be done incrementally

### User Story Dependencies

- **User Story 1 (P1)**: Foundation only
- **User Story 2 (P2)**: Depends on US1 orchestrator/state machine + browser adapter scaffolding
- **User Story 3 (P3)**: Depends on persistence + event/session recording from US1/US2

### Parallel Opportunities

- [P] tasks can be done in parallel (different files, no dependencies).

---

## Parallel Example: User Story 1

```bash
Task: "T020 FocusStateMachine_ActivationTests.swift"
Task: "T021 FocusStateMachine_CountdownResetTests.swift"
Task: "T022 FocusStateMachine_BufferTests.swift"
Task: "T023 ShortcutRunnerTests.swift"
```

---

## Implementation Strategy

### MVP First (User Story 1 Only)

1. Complete Phase 1 + Phase 2
2. Implement Phase 3 (US1) including tests
3. STOP and validate with the quickstart smoke checklist

### Incremental Delivery

1. Add US2 (browser domain)
2. Add US3 (insights)
3. Polish permissions + UX



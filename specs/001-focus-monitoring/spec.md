# Feature Specification: Foreground Focus Monitoring

**Feature Branch**: `janschill/second-system-syndrom`
**Created**: 2025-12-16
**Status**: Draft
**Input**: User description: "Build a macOS application that monitors the most foreground application, when its a browser, also the domain. A user can configure applications and domains that act as \"Focus entities\" and a time in minutes. When the user has been uninterupted in their apps/domains for the configured amount of time, the app should silently disable notifications. The application should track all entitities and store it to provide rich insights."

## User Scenarios & Testing *(mandatory)*

### User Story 1 - Onboarding, setup, and licensing (Priority: P1)

As a user, I can complete onboarding to set up permissions, install/select the Shortcut used for
silently toggling notifications, configure focus entities, and (optionally) enter a license key to
unlock premium functionality.

**Why this priority**: This is the core value proposition: eliminate interruptions during deep work without manual toggles.

**Independent Test**: Can be fully tested by starting from a clean install, completing onboarding,
and confirming the app reports a “ready” state (or clear “blocked” state) and enforces free vs
premium limits correctly.

**Acceptance Scenarios**:

1. **Given** this is my first launch, **When** I open the app, **Then** I am guided through onboarding steps needed to make the app work (permissions + Shortcut setup).
2. **Given** I have not granted required permissions, **When** I attempt to enable the app, **Then** the app clearly indicates what’s missing and how to fix it (without crashing).
3. **Given** I am unlicensed, **When** I try to add more focus entities than the free limit, **Then** the UI blocks the action and explains the upgrade path.
4. **Given** I enter a valid license key, **When** validation succeeds, **Then** premium is unlocked immediately and limits are lifted.

---

### User Story 2 - Automatic focus mode from configured entities + buffer (Priority: P2)

As a user, I can choose which applications and/or website domains count as “focus entities” and
set a global focus activation in minutes, so the system automatically (and silently) disables
notifications once I’ve stayed within any focus entity for that time. A focus buffer time is given
to the user, once entered a focus session, such that the session is not immediately lost when
unfocussing.

**Why this priority**: This is the core automation behavior: it replaces manual “focus mode” toggling and protects deep work.

**Independent Test**: Can be fully tested by configuring 1–2 focus entities and verifying that notifications are disabled only after continuous time spent within those entities reaches the configured duration, and buffer behaves correctly.

**Acceptance Scenarios**:

1. **Given** focus entities are configured and notifications are currently enabled, **When** I remain within the configured focus entities continuously for the configured duration, **Then** the system disables notifications without prompting me.
2. **Given** the system is counting focus time, **When** I switch to a non-focus entity before the duration is reached, **Then** the focus timer resets (or otherwise no longer counts toward activation) and notifications remain enabled.
3. **Given** notifications have been disabled due to focus mode, **When** I leave focus entities, **Then** the system re-enables notifications within a short, consistent time window.
4. **Given** I am in an active focus session, **When** I briefly switch to a non-focus entity and return within the configured buffer time, **Then** the focus session continues without ending.
5. **Given** I am in an active focus session, **When** I leave focus entities and do not return before the buffer time expires, **Then** the focus session ends and notifications are re-enabled.

---

### User Story 3 - Browser domain-based focus entities (Priority: P3)

As a user, when I’m working in a browser, the system recognizes the active website domain so I can
treat specific domains as focus entities.

**Why this priority**: Many work contexts live in the browser; domain-level tracking enables accurate focus detection for web-based tools.

**Independent Test**: Can be fully tested by adding a domain as a focus entity, then switching between a focus domain and a non-focus domain and observing focus counting and activation behavior.

**Acceptance Scenarios**:

1. **Given** my foreground app is a supported browser and the active tab’s domain is configured as a focus entity, **When** I remain on that domain continuously for the configured duration, **Then** notifications are disabled.
2. **Given** my foreground app is a supported browser, **When** I switch from a focus domain to a non-focus domain, **Then** focus counting stops and (if already enabled) focus mode ends consistently.
3. **Given** the system cannot determine the active domain (temporary failure), **When** this occurs, **Then** the system does not incorrectly count focus time and provides a clear status indicator that domain tracking is unavailable.

---

### User Story 4 - Insights + export (with premium depth) (Priority: P4)

As a user, I can review insights about my focus activity (time spent, sessions, trends) so I understand where my time goes and how consistently I enter deep work.

**Why this priority**: Insights turn the focus automation into a feedback loop and make the product sticky.

**Independent Test**: Can be fully tested by generating a small amount of tracked activity and verifying that the insights view reflects it accurately and consistently across restarts.

**Acceptance Scenarios**:

1. **Given** I have used the system for at least one day, **When** I open the insights view, **Then** I can see total focus time per day and a breakdown by focus entity.
2. **Given** the app is restarted, **When** I open insights again, **Then** previously recorded sessions and totals are still present.
3. **Given** I have multiple focus sessions, **When** I review details, **Then** I can see session start/end times and the entities involved.
4. **Given** I am unlicensed, **When** I open insights, **Then** the app limits insights depth/breakdowns according to the free tier and clearly communicates the limitation.
5. **Given** I am licensed, **When** I open insights, **Then** I can access the full insights depth/breakdowns.
6. **Given** I am licensed, **When** I export my data, **Then** the export completes successfully and contains the expected sessions and aggregates.

---

### Edge Cases

- What happens when the system lacks required permissions to observe the foreground app?
- What happens when a browser is foreground but the system cannot determine the active domain?
- How does the system handle rapid app switching (e.g., within a few seconds)?
- How does the system handle multiple browser windows and private/incognito windows?
- What happens across sleep/wake, user logout/login, or when the system clock changes?
- What happens if notifications were already disabled before focus mode activates?
- How does the system behave if the configured focus duration is changed while counting is in progress?

## Requirements *(mandatory)*

### Functional Requirements

- **FR-001**: System MUST continuously identify the current foreground application while running.
- **FR-002**: System MUST allow users to configure a set of “focus entities” consisting of:
  - Applications, and
  - Website domains (when the foreground application is a supported browser).
- **FR-003**: System MUST allow users to configure a focus duration in whole minutes (minimum 1 minute).
- **FR-004**: System MUST allow users to configure a focus buffer in whole seconds.
- **FR-005**: System MUST measure “uninterrupted focus time” as continuous time where the user remains within configured focus entities.
- **FR-006**: System MUST disable notifications silently once uninterrupted focus time reaches the configured duration.
- **FR-007**: System MUST end focus mode when the user leaves focus entities (i.e., notifications are re-enabled consistently).
- **FR-008**: System MUST provide a clear indication of current state (e.g., “counting”, “in focus mode”, “not in focus”, “domain tracking unavailable”).
- **FR-009**: System MUST persist the user’s configured focus entities and focus duration.
- **FR-010**: System MUST record focus activity over time in a way that supports insights (sessions, totals, breakdowns).
- **FR-011**: System MUST show insights including at minimum:
  - Daily total focus time
  - Breakdown by focus entity
  - A list of recent focus sessions with start/end times
- **FR-012**: System MUST handle missing permissions and external failures gracefully (no crashes, no incorrect focus activations).
- **FR-013**: System MUST avoid collecting or storing sensitive content (e.g., full URLs, page titles, typed text); domain-level tracking MUST be the maximum granularity for browser activity.
- **FR-014**: System MUST support a license key entered by the user and validated against a remote service.
- **FR-015**: System MUST cache and display the current license status (e.g., unlicensed, licensed, validation failed, offline) with clear messaging.
- **FR-016**: System MUST enforce free-tier limits on day 1:
  - Maximum number of focus entities (apps + domains)
  - Limited insights depth/breakdowns
  - No export
- **FR-017**: System MUST unlock premium functionality immediately after successful license validation.
- **FR-018**: System MUST support exporting focus data for licensed users.
- **FR-019**: System MUST provide an onboarding flow to guide initial setup (permissions + Shortcut setup + configuration).

### Key Entities *(include if feature involves data)*

- **FocusEntity**: A user-configured item that can count toward focus (Application or Domain), with a display name and enabled/disabled state.
- **FocusSettings**: The configured focus duration (minutes), focus buffer time, and the list of focus entities.
- **FocusEvent**: A timestamped record of the current observed entity context (e.g., app change, domain change, state transitions).
- **FocusSession**: A period of time where the user was in focus mode (start time, end time, entities involved, totals).
- **LicenseStatus**: The current license state (licensed/unlicensed/unknown) and relevant metadata needed to enforce limits and show UX state.
- **ExportJob**: A record of export operations (timestamp, range, result) to support user-visible history and debugging.

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: A new user can complete onboarding (permissions + Shortcut setup) and configure at least one focus entity and a focus duration in under 3 minutes without guidance.
- **SC-002**: Focus mode activates consistently after uninterrupted focus time reaches the configured duration (activation occurs within 5 seconds of reaching the threshold).
- **SC-003**: Focus mode ends consistently after leaving focus entities (within 5 seconds of leaving).
- **SC-004**: After 7 days of use, the insights view can display daily totals and per-entity breakdowns for those 7 days without data loss across restarts.
- **SC-005**: License validation completes within 10 seconds in normal conditions and clearly reports failure/offline states without blocking the rest of the app.
- **SC-006**: Free-tier limits are enforced consistently (cannot exceed entity limit; export is unavailable) and premium unlocks immediately after validation.

## Assumptions

- Notifications “disabled/enabled” refers to the macOS user-visible notifications suppression mode (commonly called Do Not Disturb / Focus).
- “Supported browser” initially targets commonly used macOS browsers (at least Safari and Chrome), and the product may expand support over time.
- “Uninterrupted” means the user may switch between configured focus entities without breaking the timer; leaving the configured set breaks uninterrupted time.

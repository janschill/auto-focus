# Data Model: Foreground Focus Monitoring

**Feature**: `specs/001-focus-monitoring/spec.md`
**Created**: 2025-12-16
**Storage**: SQLite

This is a logical + physical (SQLite) model to support configuration, session tracking, and rich
insights.

## Entities

### FocusEntity
Represents a configured “focus entity” the user wants to count toward focus.

- **id**: UUID (primary identifier)
- **type**: enum `{app, domain}`
- **displayName**: string
- **matchValue**:
  - for `app`: bundle identifier (e.g., `com.apple.dt.Xcode`)
  - for `domain`: normalized domain (lowercased; e.g., `linear.app`)
- **isEnabled**: boolean
- **createdAt**: timestamp
- **updatedAt**: timestamp

### FocusSettings
Singleton user settings.

- **id**: integer (single row, e.g. `1`)
- **activationMinutes**: integer (FR-003)
- **bufferSeconds**: integer (FR-004)
- **createdAt**: timestamp
- **updatedAt**: timestamp

### FocusEvent
Append-only event stream used for debugging, analytics, and backfilling sessions.

- **id**: UUID
- **timestamp**: timestamp
- **kind**: enum `{foregroundChanged, domainChanged, enteredCounting, enteredFocusMode, enteredBuffer, exitedFocusMode, permissionChanged, error}`
- **appBundleId**: nullable string
- **domain**: nullable string (domain only, never full URL)
- **focusEntityId**: nullable UUID (if event maps to a configured entity)
- **details**: nullable string (non-sensitive; no URLs/titles)

### FocusSession
Represents one focus mode session (notifications disabled), including buffer behavior.

- **id**: UUID
- **startedAt**: timestamp
- **endedAt**: nullable timestamp
- **activationMinutes**: integer (copied from settings at session start)
- **bufferSeconds**: integer (copied from settings at session start)
- **endedReason**: enum `{leftFocusEntities, bufferTimeout, userDisabled, error}` (extend as needed)
- **totalSecondsInFocusMode**: integer (derived at end; used for fast insights)

### FocusSessionEntity (join)
Optional join table allowing many-to-many between sessions and entities involved.

- **sessionId**: UUID
- **focusEntityId**: UUID
- **secondsAttributed**: integer (optional; computed or updated over time)

### LicenseStatus
Represents the current license state used for premium gating.

- **state**: enum `{unlicensed, licensed, unknown, validationFailed, offline}`
- **lastValidatedAt**: nullable timestamp
- **expiresAt**: nullable timestamp (if the licensing model includes expiry)
- **entitlements**: logical set (e.g., maxEntities, exportEnabled, insightsDepthDays)

**Note**: The license key itself should be treated as sensitive and should be stored securely (not in plain SQLite). The database may store derived, non-sensitive license status for UX and offline behavior.

### ExportJob
Represents an export operation (primarily for user-facing history and debugging).

- **id**: UUID
- **createdAt**: timestamp
- **status**: enum `{started, succeeded, failed}`
- **rangeStartAt** / **rangeEndAt**: nullable timestamps
- **format**: enum `{csv, json}` (extend as needed)
- **outputLocation**: string (path or bookmark reference; avoid storing file contents in DB)

## SQLite schema (proposed)

### Table: focus_settings
- `id INTEGER PRIMARY KEY CHECK(id = 1)`
- `activation_minutes INTEGER NOT NULL`
- `buffer_seconds INTEGER NOT NULL`
- `created_at INTEGER NOT NULL` (unix epoch seconds)
- `updated_at INTEGER NOT NULL`

### Table: focus_entities
- `id TEXT PRIMARY KEY` (uuid string)
- `type TEXT NOT NULL` (`app` or `domain`)
- `display_name TEXT NOT NULL`
- `match_value TEXT NOT NULL`
- `is_enabled INTEGER NOT NULL` (0/1)
- `created_at INTEGER NOT NULL`
- `updated_at INTEGER NOT NULL`

**Indexes**
- `idx_focus_entities_type_match_value` on `(type, match_value)`
- `idx_focus_entities_enabled` on `(is_enabled)`

### Table: focus_events
- `id TEXT PRIMARY KEY`
- `timestamp INTEGER NOT NULL`
- `kind TEXT NOT NULL`
- `app_bundle_id TEXT NULL`
- `domain TEXT NULL`
- `focus_entity_id TEXT NULL`
- `details TEXT NULL`

**Indexes**
- `idx_focus_events_timestamp` on `(timestamp)`
- `idx_focus_events_kind_timestamp` on `(kind, timestamp)`
- `idx_focus_events_entity_timestamp` on `(focus_entity_id, timestamp)`

### Table: focus_sessions
- `id TEXT PRIMARY KEY`
- `started_at INTEGER NOT NULL`
- `ended_at INTEGER NULL`
- `activation_minutes INTEGER NOT NULL`
- `buffer_seconds INTEGER NOT NULL`
- `ended_reason TEXT NULL`
- `total_seconds_in_focus_mode INTEGER NOT NULL DEFAULT 0`

**Indexes**
- `idx_focus_sessions_started_at` on `(started_at)`
- `idx_focus_sessions_ended_at` on `(ended_at)`

### Table: focus_session_entities
- `session_id TEXT NOT NULL`
- `focus_entity_id TEXT NOT NULL`
- `seconds_attributed INTEGER NOT NULL DEFAULT 0`
- `PRIMARY KEY(session_id, focus_entity_id)`
- foreign keys (optional in SQLite, but recommended if enabled)

### Table: license_status (optional, single row)
- `id INTEGER PRIMARY KEY CHECK(id = 1)`
- `state TEXT NOT NULL`
- `last_validated_at INTEGER NULL`
- `expires_at INTEGER NULL`
- `entitlements_json TEXT NULL` (non-sensitive derived entitlements)

### Table: export_jobs
- `id TEXT PRIMARY KEY`
- `created_at INTEGER NOT NULL`
- `status TEXT NOT NULL`
- `range_start_at INTEGER NULL`
- `range_end_at INTEGER NULL`
- `format TEXT NOT NULL`
- `output_location TEXT NULL`

**Indexes**
- `idx_export_jobs_created_at` on `(created_at)`

## Insight queries (examples, not implementation)

- Daily total focus time:
  - Sum `total_seconds_in_focus_mode` grouped by day of `started_at`.
- Per-entity breakdown:
  - Aggregate `seconds_attributed` by `focus_entity_id` for a date range.
- Recent sessions:
  - `focus_sessions` ordered by `started_at` desc, limited.

## Migration strategy

- Maintain a schema version in `PRAGMA user_version`.
- Provide forward-only migrations; on migration failure, do not lose data and show an actionable error state.



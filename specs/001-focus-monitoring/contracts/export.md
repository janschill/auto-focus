# Contract: Data Export (Premium)

**Feature**: `specs/001-focus-monitoring/spec.md`
**Created**: 2025-12-16

## Purpose
Define what “export” means for focus data and the constraints for a privacy-safe export.

## Eligibility
- Export MUST be available to licensed users only (FR-018).

## Export contents
- Focus sessions: start/end timestamps, duration, ended reason
- Aggregates: daily totals, per-entity totals for the exported date range
- Focus entities metadata (type + match value + display name)

## Privacy constraints
- Browser data MUST be **domain-only** (no full URLs, no titles).
- Export MUST not include sensitive content (no clipboard, keystrokes, window titles unless explicitly in scope).

## Output formats (initial)
- CSV (for sessions + per-entity aggregates)
- JSON (optional; if included, provide a stable schema version)

## Behavior requirements
- Export MUST be explicit user action (no automatic exports).
- Export MUST clearly indicate the exported range.
- Errors MUST be user-visible and actionable.



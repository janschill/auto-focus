<!--
Sync Impact Report

- Version change: (new file; placeholders only) → 1.0.0
- Modified principles: N/A (initial constitution content)
- Added sections: Core Principles (filled), Quality Gates, Workflow & Review, Governance (filled)
- Removed sections: N/A
- Templates requiring updates:
  - ✅ updated: .specify/templates/plan-template.md
  - ✅ updated: .specify/templates/tasks-template.md
  - ✅ no change needed: .specify/templates/spec-template.md
  - ✅ no change needed: .specify/templates/checklist-template.md
  - ✅ no change needed: .specify/templates/agent-file-template.md
- Follow-up TODOs:
  - TODO(RATIFICATION_DATE): Set the original adoption date once you decide what “ratified” means for this repo.
-->

# Auto-Focus Constitution

## Core Principles

### I. Code Quality Is a Feature
Code MUST be readable, maintainable, and intentionally structured.

- Prefer small, cohesive types and functions with clear names.
- Avoid “clever” code; optimize for the next engineer reading it.
- Follow Swift conventions and the repository’s patterns (SwiftUI + MVVM, `MARK:` sections).
- Keep responsibilities separated: Views render; ViewModels manage UI state; services/managers do work.
- Remove dead code and unused abstractions; do not “future-proof” without a concrete need.

### II. Deterministic Core, Isolated Side Effects
Core focus logic MUST be deterministic and testable, with macOS APIs and I/O isolated behind adapters.

- Domain/state-machine logic MUST be pure (or near-pure) and independently unit-testable.
- Interactions with macOS (frontmost app detection, Do Not Disturb, timers, networking) MUST live behind protocols.
- UI MUST NOT contain business logic; it binds to published state and delegates actions to ViewModels/services.

### III. Testing Discipline (NON-NEGOTIABLE)
Every behavior change MUST be protected by tests, and regressions MUST be prevented with a failing test first.

- For any change that affects focus/session/buffer behavior, add or update XCTest unit tests.
- Bug fixes MUST include a regression test that fails before the fix and passes after.
- New public behaviors MUST include acceptance scenarios in the spec and corresponding tests where feasible.
- Tests MUST be deterministic (no reliance on wall-clock timing without a controllable clock/test seam).

### IV. UX Consistency and Accessibility
The user experience MUST be consistent, predictable, and accessible across the app.

- Use native SwiftUI controls and follow macOS Human Interface Guidelines.
- Maintain consistent terminology, layout patterns, and interaction rules across screens.
- All user-facing states MUST be understandable (loading, disconnected, errors) with clear messaging.
- Accessibility is required: meaningful labels, keyboard navigation, and no critical information conveyed by color alone.

### V. Safe Failure, Privacy, and Observability
The app MUST fail safely, respect user privacy, and be diagnosable in production-like environments.

- Errors MUST be handled without crashing for non-critical failures; degrade gracefully.
- Logging MUST be useful (state transitions, adapter failures) and MUST NOT include sensitive user data.
- Prefer explicit state transitions over implicit flags; avoid “mystery meat” behavior.

## Quality Gates

These are the minimum quality gates for changes merged to the mainline:

- Code compiles without introducing new warnings.
- Relevant unit tests are added/updated and all tests pass.
- UI changes include updated screenshots or a short verification note (what you clicked, what you observed).
- No TODOs left behind without an explicit tracking reference (issue/link) and a rationale.

## Workflow & Review

Changes MUST be spec-driven and reviewable:

- Every non-trivial change MUST have a spec (or an update to an existing spec) that includes acceptance scenarios.
- PRs MUST describe the user-visible impact and how it was verified (tests + manual steps).
- Reviewers MUST check constitution compliance (quality, tests, UX consistency) before approval.

## Governance

This constitution supersedes other informal practices. If another document conflicts with it, the constitution wins.

### Amendments
- Amendments MUST be made via PR that includes rationale and updates any dependent templates/docs.
- Versioning MUST follow semantic versioning:
  - MAJOR: Principle removals or backward-incompatible governance changes
  - MINOR: New principles/sections or materially expanded requirements
  - PATCH: Clarifications and wording improvements only

### Compliance expectations
- New feature work MUST include acceptance scenarios and an implementation plan that references the constitution gates.
- Behavior changes MUST be covered by tests; waivers MUST be explicit and justified in the PR.

**Version**: 1.0.0 | **Ratified**: TODO(RATIFICATION_DATE) | **Last Amended**: 2025-12-16

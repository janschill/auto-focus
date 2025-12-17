# Contract: Browser Domain Provider

**Feature**: `specs/001-focus-monitoring/spec.md`
**Created**: 2025-12-16

## Purpose
Define the contract for obtaining the current active browser domain when the foreground app is a
supported browser.

## Inputs
- Foreground application identity (bundle identifier)

## Outputs
- **domain**: a normalized domain string (lowercased), e.g. `github.com`
- **availability**: `{available, unavailable}`
- **reason** (when unavailable): `{permissionDenied, unsupportedBrowser, noActiveTab, scriptError, unknown}`

## Behavior requirements
- MUST return **domain only** (no full URL, no path/query, no page title).
- MUST treat failures as **unavailable** and never “guess” (fail safe).
- SHOULD update quickly after tab changes, but correctness > speed.

## Supported browsers (initial expectation)
- Safari
- Chrome

## Permissions
- Apple Events permissions may be required for browser scripting.
- Accessibility permissions should be avoided unless required by a chosen strategy.



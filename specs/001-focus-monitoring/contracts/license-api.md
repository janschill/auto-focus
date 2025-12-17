# Contract: License Validation API (Existing)

**Feature**: `specs/001-focus-monitoring/spec.md`
**Created**: 2025-12-16

## Purpose
Define how the app validates a user-entered license key and receives premium entitlements.

This contract matches the existing production API used by the previous version of Auto-Focus.

## Endpoint

- **Method**: `POST`
- **URL**: `https://auto-focus.app/api/v1/licenses/validate`
- **Content-Type**: `application/json`

## Request body

```json
{
  "license_key": "XXXX-XXXX-XXXX",
  "app_version": "1.12.0"
}
```

## Response body (200 OK)

```json
{
  "valid": true,
  "message": "License valid",
  "timestamp": 1734370000,
  "signature": "BASE64_HMAC_SHA256_SIGNATURE"
}
```

## Signature verification (required)

- The app MUST verify the response signature using HMAC-SHA256 over the payload:

\(payload = \"{valid}|{message}|{timestamp}\"\)

- `signature` is the Base64 encoding of the HMAC digest.
- The app MUST also verify `timestamp` freshness (previous app used a 5-minute window) to prevent replay.

## Errors

- Non-200 responses indicate validation failure; the previous app treated the response body as an error message.
- The app MUST surface actionable error states (invalid key vs offline vs server error).

## Behavior requirements
- Validation MUST not block the core focus functionality (the app can operate unlicensed).
- The app MUST cache last-known-good license state for offline UX (premium remains locked unless a valid cached license is present).
- The app MUST surface actionable error messages (invalid key vs offline vs service error).

## Security & privacy
- The app MUST treat license keys as sensitive and avoid logging them.
- Requests MUST use secure transport; responses MUST not include PII.

## Entitlements note (important)

The existing API response does **not** return entitlements (max entities, export, insights depth).
For day-1 premium gating, entitlements MUST be determined client-side based on “licensed vs not”
until/unless the API is extended later.



# Auto-Focus

Automatically enable Do Not Disturb mode when you're in deep work.

Auto-Focus periodically checks what application is in the front and enables Do Not Disturb mode after 12 minutes of focused work in your chosen applications. A quick glance at another app doesn't count as leaving focus.

## How Does It Work?

Auto-Focus runs as a menu bar app that monitors which application is currently active. When you're using one of your designated focus applications (like VSCode, Xcode, or any other app you choose), it starts a timer. Once you've been focused for 12 minutes (configurable), it automatically enables Do Not Disturb mode.

To prevent losing focus during quick context switches (like checking Slack, an agent, or documentation), Auto-Focus has a configurable glance tolerance (30 seconds by default). Look away for less than that and your countdown or focus session simply pauses; stay away longer and it counts as leaving focus.

## Getting Started

1. Download the latest version of Auto-Focus from the releases page
2. Install the required Shortcut:
   - Open the Shortcuts folder in the downloaded ZIP and install the Shortcut
   - or later through Settings of the app itself
3. Launch Auto-Focus and configure your focus applications
4. Enjoy your uninterrupted work sessions! 🚀

## Features

- **Automatic Focus Detection**: Detects when you're in deep work and enables focus mode automatically
- **Glance Tolerance**: Quick looks at other apps pause your focus instead of ending it
- **Flow State**: See in the menu bar when you're in flow or scattered, based on how often you switch apps
- **Focus Insights**: Track your focus sessions and productivity patterns
- **Browser Integration**: Built-in URL tracking for Safari, Chrome, Brave, Edge, Arc, and more
- **Menu Bar Interface**: Quick access to your focus status and settings
- **Multiple Apps Support**: Choose which applications should trigger focus mode
- **Configurable Thresholds**: Customize how long before focus mode activates
- **Data Export**: Export focus session data (Premium feature)

---

## 🚀 Release Process

### Automated Releases

Releases are fully automated via GitHub Actions. **The release workflow only runs when `MARKETING_VERSION` changes in `auto-focus.xcodeproj/project.pbxproj`.**

**To create a new release:**

1. Bump `MARKETING_VERSION` in `auto-focus.xcodeproj/project.pbxproj` (e.g., `1.2.0` → `1.2.1`)
2. Commit and push to `main`
3. The workflow automatically:
   - Builds and archives the app
   - Code signs with Developer ID certificate
   - Notarizes with Apple
   - Packages app for distribution
   - Creates git tag (e.g., `v1.2.1`)
   - Creates GitHub release with assets
   - Updates distribution files

**Note**: The workflow checks if the version actually changed. If `MARKETING_VERSION` matches the latest tag, the release is skipped (no duplicate tags).

### GitHub Secrets Required

Configure these secrets in **Settings → Secrets and variables → Actions**:

- `APPLE_CERTIFICATE`: Base64-encoded .p12 certificate file
- `APPLE_CERTIFICATE_PASSWORD`: Password for the .p12 certificate
- `APPLE_ID`: Your Apple ID email
- `APPLE_APP_SPECIFIC_PASSWORD`: App-specific password from https://appleid.apple.com/account/manage
- `APPLE_TEAM_ID`: Your Apple Developer Team ID (`LKQJ2JG34Y`)
- `HMAC_SECRET`: (optional) HMAC secret for license validation

### Manual Release (Testing Only)

For local testing or manual releases:

```bash
make manual-release
```

This will guide you through the notarization process step-by-step.

### Version Strategy

- **Semantic versioning**: `v1.MINOR.PATCH` (e.g., v1.2.0, v1.2.1)
- **Manual version bump**: Update `MARKETING_VERSION` in `project.pbxproj` before releasing
- **Git tags**: Created automatically with each release
- **Distribution**: Files served from `docs/downloads/` and GitHub releases

### Troubleshooting

**Notarization fails**: Check logs with:
```bash
xcrun notarytool log <submission-id> --keychain-profile 'Developer'
```

**Build issues**: Clean and retry:
```bash
make clean
make manual-release
```

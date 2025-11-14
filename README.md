# Auto-Focus

Automatically enable Do Not Disturb mode when you're in deep work.

Auto-Focus periodically checks what application is in the front and enables Do Not Disturb mode after 12 minutes of focused work in your chosen applications. When you switch to non-work apps, it gives you a buffer period before re-enabling notifications.

## How Does It Work?

Auto-Focus runs as a menu bar app that monitors which application is currently active. When you're using one of your designated focus applications (like VSCode, Xcode, or any other app you choose), it starts a timer. Once you've been focused for 12 minutes (configurable), it automatically enables Do Not Disturb mode.

To prevent losing focus during quick context switches (like checking documentation), Auto-Focus includes a configurable buffer period. This means your focus session won't end immediately when you switch apps - you have a grace period to switch back to your work.

## Getting Started

1. Download the latest version of Auto-Focus from the releases page
2. Install the required Shortcut:
   - Open the Shortcuts folder in the downloaded DMG and install the Shortcut
   - or later through Settings of the app iteself
3. Launch Auto-Focus and configure your focus applications
4. Enjoy your uninterrupted work sessions! 🚀

## Features

- **Automatic Focus Detection**: Detects when you're in deep work and enables focus mode automatically
- **Smart Buffer**: Configurable buffer time prevents losing focus during quick switches
- **Focus Insights**: Track your focus sessions and productivity patterns
- **Browser Integration**: Chrome extension for tracking focus URLs (GitHub, Linear, Figma, etc.)
- **Menu Bar Interface**: Quick access to your focus status and settings
- **Multiple Apps Support**: Choose which applications should trigger focus mode
- **Configurable Thresholds**: Customize how long before focus mode activates
- **Data Export**: Export focus session data (Premium feature)

## Future Plans

### Export/Import of Data

- Maybe use the cloud, maybe not

### Auto-Focus+

- Hide some features behind a paywall

### More Integrations

- **Slack Integration**: Set Slack status automatically and manage notifications
- **Calendar Integration**: Respect your meeting schedule and adjust focus mode accordingly
- **Browser Extension**: Detect protective websites
- **More Focus Providers**: Support for other focus/DND implementations beyond macOS Focus

### Enhanced Detection

- **Activity Detection**: Smarter detection of actual work vs. idle time
- **Context Awareness**: Better understanding of work contexts and patterns
- **Custom Rules**: Allow users to create their own rules for when to enable/disable focus mode

---

## 🚀 Release Guide

### Automated Releases (Recommended)

**Releases are now fully automated!** Every merge to `main` automatically triggers:

1. ✅ Build and archive the app
2. ✅ Code sign with Developer ID certificate
3. ✅ Notarize with Apple
4. ✅ Package app and extension
5. ✅ Generate version.json
6. ✅ Create git tag (semantic versioning: v1.0.0, v1.0.1, etc.)
7. ✅ Update GitHub Pages (docs/downloads/)
8. ✅ Create GitHub release with assets
9. ✅ Push tag and commits

**No manual steps required!** Just merge your PR to `main` and the release happens automatically.

### GitHub Secrets Setup

For automated releases to work, configure these secrets in your GitHub repository:

**Settings → Secrets and variables → Actions → New repository secret**

1. **`APPLE_CERTIFICATE`**: Base64-encoded .p12 certificate file
   ```bash
   # Export certificate from Keychain Access as .p12
   # Then encode it:
   base64 -i certificate.p12 | pbcopy
   # Paste the output as the secret value
   ```

2. **`APPLE_CERTIFICATE_PASSWORD`**: Password used when exporting the .p12 certificate

3. **`APPLE_ID`**: Your Apple ID email (e.g., `apple@janschill.de`)

4. **`APPLE_APP_SPECIFIC_PASSWORD`**: App-specific password for notarization
   - Generate at: https://appleid.apple.com/account/manage
   - Select "App-Specific Passwords" → Generate new password
   - Use this password (not your Apple ID password)

5. **`APPLE_TEAM_ID`**: Your Apple Developer Team ID (`LKQJ2JG34Y`)

6. **`HMAC_SECRET`** (optional): HMAC secret for license validation (if used)

### Manual Release Workflow (Legacy)

If you need to create a release manually (e.g., for testing):

```bash
# ⚠️  One-command release (does everything!)
make manual-release
```

This command will:
1. ✅ Build and archive the app
2. ✅ Prepare app for notarization
3. ✅ Create notarization ZIP
4. ⚠️  **PAUSE** - You must manually notarize (see output)
5. ✅ Package extension and generate version metadata
6. ✅ Update website download links
7. ✅ Stage files in git
8. ✅ Create git tag with semantic version (e.g., v1.0.1)
9. ✅ Create GitHub release with assets
10. ✅ Provide final push instructions

### Manual Step-by-Step (if needed)

If you prefer to control each step:

```bash
# 1. Prepare app for notarization
make prepare-app-for-notarization

# 2. Notarize (follow the output instructions)
xcrun notarytool submit 'build/auto-focus_notarization.zip' --keychain-profile 'Developer' --wait
xcrun stapler staple 'build/auto-focus_temp.app'

# 3. Package and deploy
make package-app
make deploy-downloads

# 4. Create git tag and GitHub release
make create-github-release

# 5. Push to deploy
git push origin main
```

### Notarization Process

When you see "⚠️ IMPORTANT: Ensure the app is notarized", run:

```bash
# Submit for notarization (this takes 1-5 minutes)
xcrun notarytool submit 'build/auto-focus_notarization.zip' --keychain-profile 'Developer' --wait

# If successful, staple the notarization ticket
xcrun stapler staple 'build/auto-focus_temp.app'
```

### Version Strategy

- **Semantic versioning**: `v1.MINOR.PATCH` (e.g., v1.0.0, v1.0.1, v1.1.0)
- **Auto-increment**: Patch version increments automatically on each release (v1.0.0 → v1.0.1 → v1.0.2)
- **Major version**: Stays at v1 until manually bumped (v2 would require new license)
- **Git tags**: Created automatically with each release (e.g., v1.0.1)
- **Version file**: `docs/downloads/version.json` updated automatically
- **Xcode project**: `MARKETING_VERSION` updated automatically during build

### Distribution Strategy

- **Primary**: Direct downloads from https://auto-focus.app/downloads/
- **Backup**: GitHub releases for version history
- **Formats**: ZIP (primary), DMG (optional with `make create-dmg`)

### Troubleshooting

**Notarization fails**: Check logs with:
```bash
xcrun notarytool log <submission-id> --keychain-profile 'Developer'
```

**GitHub CLI issues**: Re-authenticate:
```bash
gh auth login --scopes repo
```

**Build issues**: Clean and retry:
```bash
make clean
make manual-release
```

### Release Checklist

**For Automated Releases (Default):**
- [ ] Code is committed and pushed to main
- [ ] Tests pass (CI runs automatically)
- [ ] GitHub Secrets are configured (see above)
- [ ] Merge PR to main
- [ ] Monitor GitHub Actions workflow
- [ ] Verify release appears at https://github.com/janschill/auto-focus/releases
- [ ] Verify website updates at auto-focus.app/downloads/
- [ ] Test download and installation

**For Manual Releases (Legacy):**
- [ ] Code is committed and pushed to main
- [ ] Tests pass locally (`make test`)
- [ ] App builds and runs correctly
- [ ] Browser extension works (if changed)
- [ ] Run `make manual-release`
- [ ] Follow notarization instructions
- [ ] Verify website updates at auto-focus.app
- [ ] Test download links work
- [ ] Push final changes: `git push origin main`

### Post-Release

After automated release:
- [ ] Verify GitHub Actions workflow completed successfully
- [ ] Check GitHub release page for new version
- [ ] Verify auto-focus.app/downloads/ serves new files
- [ ] Test download and installation
- [ ] Verify version.json is updated correctly
- [ ] Check that app shows update notification (if applicable)

**Note**: Releases are now fully automated! Just merge to `main` and the workflow handles everything. 🎉

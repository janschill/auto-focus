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

This section is for the developer (future me) to remember how to create new releases.

### Prerequisites

1. **Code Signing Setup**: Ensure you have Developer ID certificates in Keychain
2. **Notarization Setup**: Configure notarytool credentials
   ```bash
   xcrun notarytool store-credentials "Developer" --apple-id "apple@janschill.de" --team-id "LKQJ2JG34Y"
   ```
3. **GitHub CLI**: Install and authenticate
   ```bash
   brew install gh
   gh auth login
   ```

### Complete Release Workflow

The entire release process is automated with a single command:

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
8. ✅ Create git tag with date-based version (e.g., v2025.06.15)
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

- **Date-based versions**: `2025.06.15` (year.month.day)
- **Git tags**: `v2025.06.15`
- **Single version tracking**: Only latest version in git, older versions in GitHub releases
- **Backward compatibility**: App handles version management internally

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

After release:
- [ ] Verify auto-focus.app serves new files
- [ ] Check GitHub release page
- [ ] Test download and installation
- [ ] Update any documentation if needed

**Remember**: The `manual-release` command does most of the work. Just follow the notarization steps when prompted! 🎉

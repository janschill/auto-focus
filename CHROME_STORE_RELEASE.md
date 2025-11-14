# Chrome Web Store Release Guide

This guide explains how to release a new version of the Auto-Focus browser extension to the Chrome Web Store.

## Quick Start

1. **Bump the extension version:**
   ```bash
   make build-extension BUMP=patch   # For patch releases (1.2.2 -> 1.2.3)
   make build-extension BUMP=minor   # For minor releases (1.2.2 -> 1.3.0)
   make build-extension BUMP=major   # For major releases (1.2.2 -> 2.0.0)
   ```

2. **Review the generated ZIP:**
   - Location: `docs/downloads/auto-focus-extension.zip`
   - Verify it contains the `chrome/` directory with all files

3. **Submit to Chrome Web Store:**
   - Go to [Chrome Web Store Developer Dashboard](https://chrome.google.com/webstore/devconsole)
   - Select your extension
   - Click "Upload Updated Package"
   - Upload `docs/downloads/auto-focus-extension.zip`
   - Fill in release notes
   - Submit for review

## Detailed Steps

### Step 1: Update Extension Version

The `build-extension` Makefile target automatically:
- Reads current version from `manifest.json`
- Bumps version based on `BUMP` parameter
- Updates `manifest.json` with new version
- Creates a ZIP file ready for Chrome Web Store

**Current version:** Check `auto-focus-browser-extension/chrome/manifest.json`

**Version bump types:**
- `patch`: Bug fixes (1.2.2 → 1.2.3)
- `minor`: New features (1.2.2 → 1.3.0)
- `major`: Breaking changes (1.2.2 → 2.0.0)

### Step 2: Test the Extension Locally

Before submitting, test the extension:

1. **Load unpacked extension in Chrome:**
   - Open Chrome and go to `chrome://extensions/`
   - Enable "Developer mode" (top right)
   - Click "Load unpacked"
   - Select the `auto-focus-browser-extension/chrome/` directory
   - Verify it works correctly

2. **Test the changes:**
   - Test all functionality that was modified
   - Verify connection to the Auto-Focus app
   - Check that focus detection works correctly

### Step 3: Prepare Release Notes

Create release notes describing:
- What changed in this version
- Bug fixes
- New features
- Any breaking changes

Example:
```
Version 1.2.3

Bug Fixes:
- Fixed browser focus detection when switching between apps
- Improved connection reliability with Auto-Focus app

Improvements:
- Better handling of Chrome window focus events
- More accurate focus state synchronization
```

### Step 4: Submit to Chrome Web Store

1. **Go to Developer Dashboard:**
   - Visit: https://chrome.google.com/webstore/devconsole
   - Sign in with your Google account

2. **Select Your Extension:**
   - Find "Auto-Focus Browser Integration" in your extensions list
   - Click on it to open the extension details

3. **Upload New Version:**
   - Click "Upload Updated Package" button
   - Select `docs/downloads/auto-focus-extension.zip`
   - Wait for upload to complete

4. **Fill in Release Information:**
   - **What's new:** Paste your release notes
   - **Privacy practices:** Review and update if needed
   - **Pricing:** Verify pricing is correct (if applicable)

5. **Submit for Review:**
   - Review all information
   - Click "Submit for Review"
   - Note: Review typically takes 1-3 business days

### Step 5: Monitor Review Status

- Check the Developer Dashboard for review status
- Google will email you when the review is complete
- If rejected, address the issues and resubmit

## Troubleshooting

### ZIP File Issues

If the ZIP doesn't work:
```bash
# Rebuild the extension
make build-extension BUMP=patch

# Verify ZIP contents
unzip -l docs/downloads/auto-focus-extension.zip
```

### Version Already Exists

If Chrome Web Store says version already exists:
- Check current version in `manifest.json`
- Bump to a higher version
- Rebuild and resubmit

### Review Rejection

Common reasons for rejection:
- Missing privacy policy (if required)
- Permissions not properly explained
- Violation of Chrome Web Store policies

Check the rejection email for specific issues and address them.

## Version Alignment

The extension version doesn't need to match the app version exactly, but it's good practice to:
- Keep them roughly aligned (e.g., app 1.2.0, extension 1.2.x)
- Bump extension version when app version changes significantly
- Document version compatibility if needed

## Automation (Future)

Consider automating Chrome Web Store submission using:
- [Chrome Web Store API](https://developer.chrome.com/docs/webstore/api/)
- GitHub Actions workflow
- CI/CD pipeline integration

For now, manual submission is recommended for better control over release timing.

## Checklist

Before submitting:
- [ ] Extension version bumped in `manifest.json`
- [ ] Extension tested locally in Chrome
- [ ] ZIP file created and verified
- [ ] Release notes prepared
- [ ] All changes committed to git
- [ ] Ready to submit to Chrome Web Store

After submission:
- [ ] Monitor review status
- [ ] Update documentation if needed
- [ ] Announce release to users (if applicable)


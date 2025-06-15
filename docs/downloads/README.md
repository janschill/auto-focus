# Auto-Focus Downloads

This directory contains the latest stable releases of Auto-Focus and the browser extension.

## Files

- `Auto-Focus.zip` - Latest notarized macOS app (ignored by git)
- `auto-focus-extension.zip` - Latest browser extension (ignored by git)  
- `version.json` - Version metadata for update checking

## Building for Distribution

Use the Makefile commands to prepare distribution files:

```bash
# Complete workflow
make archive-mac                 # Build and archive
# [Manually notarize the app - see Makefile output]
make package-app                 # Package after notarization
make deploy-downloads            # Update website links

# Or step by step
make prepare-downloads           # Create directory
make package-extension          # Package browser extension
make generate-version           # Create version.json
```

## Important Notes

⚠️ **Notarization Required**: The app MUST be notarized before distribution. The Makefile will guide you through this process.

🔄 **Single Version Strategy**: We maintain one current version for simplicity. The app handles backward compatibility internally.

📦 **GitHub Releases**: Keep using GitHub releases for version history and developer audience, but serve downloads directly from the website for better user experience.

## Website Integration

The `deploy-downloads` target automatically updates `docs/index.html` to use local downloads instead of GitHub releases.
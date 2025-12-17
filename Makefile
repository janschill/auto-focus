.PHONY: build test clean lint format ai-context swift-package-update codesign-check archive-mac notarize prepare-downloads prepare-app-for-notarization package-app package-extension generate-version prepare-distribution deploy-downloads create-dmg tag-release create-github-release manual-release

# Project configuration
PROJECT_NAME = auto-focus
SCHEME = auto-focus
APP_IDENTIFIER = auto-focus.auto-focus
CONFIGURATION = Release
BUILD_DIR = build
ARCHIVE_PATH = $(BUILD_DIR)/$(PROJECT_NAME).xcarchive
APP_PATH = $(BUILD_DIR)/$(PROJECT_NAME).app

# Distribution configuration
DOWNLOADS_DIR = docs/downloads
APP_ZIP = $(DOWNLOADS_DIR)/Auto-Focus.zip
EXTENSION_ZIP = $(DOWNLOADS_DIR)/auto-focus-extension.zip
VERSION_FILE = $(DOWNLOADS_DIR)/version.json

# Swift targets
build-swift:
	@echo "Building Swift project..."
	swift build -c release

test:
	@echo "Running Swift tests..."
	@xcodebuild test \
		-project $(PROJECT_NAME).xcodeproj \
		-scheme $(SCHEME) \
		-destination 'platform=macOS' \
		CODE_SIGN_IDENTITY="-" \
		CODE_SIGNING_ALLOWED=NO \
		-only-testing:auto-focusTests || exit $$?

test-swift: test

test-coverage:
	@echo "Running tests with code coverage..."
	@xcodebuild test \
		-project $(PROJECT_NAME).xcodeproj \
		-scheme $(SCHEME) \
		-destination 'platform=macOS' \
		CODE_SIGN_IDENTITY="-" \
		CODE_SIGNING_ALLOWED=NO \
		-enableCodeCoverage YES \
		-only-testing:auto-focusTests || exit $$?
	@echo "Coverage report generated in DerivedData"

swift-package-update:
	@echo "Updating Swift packages..."
	swift package update

# Xcode build targets
build:
	@echo "Building $(PROJECT_NAME) for $(CONFIGURATION)..."
	@if [ -f ".hmac_secret" ]; then \
		echo "✅ Loading HMAC secret from .hmac_secret file"; \
		xcodebuild -scheme $(SCHEME) -configuration $(CONFIGURATION) -derivedDataPath $(BUILD_DIR) build HMAC_SECRET="$$(cat .hmac_secret)"; \
	else \
		echo "⚠️  .hmac_secret file not found - using development secret"; \
		xcodebuild -scheme $(SCHEME) -configuration $(CONFIGURATION) -derivedDataPath $(BUILD_DIR) build; \
	fi

.PHONY: build-autofocus2 test-autofocus2

build-autofocus2:
	@echo "Building AutoFocus2 (project: auto-focus2/AutoFocus2.xcodeproj, scheme: AutoFocus2)..."
	xcodebuild -project auto-focus2/AutoFocus2.xcodeproj -scheme AutoFocus2 -configuration Release build

test-autofocus2:
	@echo "Testing AutoFocus2 (project: auto-focus2/AutoFocus2.xcodeproj, scheme: AutoFocus2Tests)..."
	xcodebuild -project auto-focus2/AutoFocus2.xcodeproj -scheme AutoFocus2Tests -configuration Debug test

clean:
	@echo "Cleaning build artifacts..."
	rm -rf $(BUILD_DIR)
	xcodebuild -scheme $(SCHEME) clean
	@echo "Clearing Xcode derived data..."
	rm -rf ~/Library/Developer/Xcode/DerivedData/auto-focus-*

# Deep clean for release builds
deep-clean: clean
	@echo "🧹 Deep cleaning for fresh release build..."
	@echo "Resolving package dependencies..."
	@xcodebuild -resolvePackageDependencies -project auto-focus.xcodeproj
	@echo "Clearing module cache..."
	@rm -rf ~/Library/Developer/Xcode/DerivedData/ModuleCache.noindex
	@echo "Clearing build cache..."
	@defaults delete com.apple.dt.Xcode DVTSourceControlWorkspaceBlueprintWorkingCopyPathsKey 2>/dev/null || true
	@echo "✅ Deep clean complete - ready for fresh build"

# Archive and signing
archive-mac:
	@echo "Creating archive for $(PROJECT_NAME)..."
	@if [ -f ".hmac_secret" ]; then \
		echo "✅ Loading HMAC secret from .hmac_secret file"; \
		HMAC_SECRET=$$(cat .hmac_secret) xcodebuild -scheme $(SCHEME) -configuration $(CONFIGURATION) -archivePath $(ARCHIVE_PATH) archive HMAC_SECRET="$$(cat .hmac_secret)"; \
	else \
		echo "⚠️  .hmac_secret file not found - using development secret"; \
		echo "   Run: ./scripts/setup-production-secret.sh to create it"; \
		xcodebuild -scheme $(SCHEME) -configuration $(CONFIGURATION) -archivePath $(ARCHIVE_PATH) archive; \
	fi

# Code signing verification
codesign-check:
	@echo "Checking code signature..."
	@if [ -d "$(APP_PATH)" ]; then \
		codesign -dv --verbose=4 $(APP_PATH); \
	else \
		echo "App not found at $(APP_PATH). Run 'make build' first."; \
		exit 1; \
	fi

codesign-verify:
	@echo "Verifying code signature..."
	@if [ -d "$(APP_PATH)" ]; then \
		codesign --verify --verbose $(APP_PATH); \
		spctl --assess --verbose $(APP_PATH); \
	else \
		echo "App not found at $(APP_PATH). Run 'make build' first."; \
		exit 1; \
	fi

# Notarization (requires Apple ID credentials)
notarize:
	@echo "Submitting for notarization..."
	@if [ -d "$(APP_PATH)" ]; then \
		xcrun notarytool submit $(APP_PATH) --keychain-profile "Developer" --wait; \
	else \
		echo "App not found at $(APP_PATH). Run 'make archive-mac' first."; \
		exit 1; \
	fi

# Development utilities
lint:
	@echo "Running SwiftLint..."
	@if command -v swiftlint >/dev/null 2>&1; then \
		swiftlint; \
	else \
		echo "SwiftLint not installed. Install with: brew install swiftlint"; \
	fi

format:
	@echo "Formatting Swift code..."
	@if command -v swiftformat >/dev/null 2>&1; then \
		swiftformat auto-focus/; \
	else \
		echo "SwiftFormat not installed. Install with: brew install swiftformat"; \
	fi

# AI assistance targets
ai-context:
	@echo "Generating AI context for auto-focus..."
	@mkdir -p Configuration/.claude
	@find auto-focus -name "*.swift" -exec echo "=== {} ===" \; -exec cat {} \; > Configuration/.claude/swift-context.txt
	@tree auto-focus > Configuration/.claude/structure.txt 2>/dev/null || ls -la auto-focus > Configuration/.claude/structure.txt
	@echo "License management features:" > Configuration/.claude/features.txt
	@grep -r "License\|Subscription" auto-focus >> Configuration/.claude/features.txt 2>/dev/null || echo "No license features found" >> Configuration/.claude/features.txt
	@echo "Focus control features:" >> Configuration/.claude/features.txt
	@grep -r "Focus\|Session" auto-focus >> Configuration/.claude/features.txt 2>/dev/null || echo "No focus features found" >> Configuration/.claude/features.txt

ai-swift-refactor:
	@echo "Triggering AI refactor analysis..."
	@echo "Feature analysis complete. Use 'claude \"Review the FocusControl feature and suggest SwiftUI improvements for better performance\"'"

# Browser extension build with semantic versioning
# Usage: make build-extension BUMP=patch|minor|major (defaults to patch)
BUMP ?= patch
build-extension: prepare-downloads
	@echo "🌐 Building browser extension..."
	@CURRENT_VERSION=$$(grep '"version"' auto-focus-browser-extension/chrome/manifest.json | sed 's/.*"version": "\([^"]*\)".*/\1/'); \
	echo "Current version: $$CURRENT_VERSION"; \
	MAJOR=$$(echo $$CURRENT_VERSION | cut -d. -f1); \
	MINOR=$$(echo $$CURRENT_VERSION | cut -d. -f2); \
	PATCH=$$(echo $$CURRENT_VERSION | cut -d. -f3); \
	if [ "$(BUMP)" = "major" ]; then \
		NEW_VERSION="$$((MAJOR + 1)).0.0"; \
	elif [ "$(BUMP)" = "minor" ]; then \
		NEW_VERSION="$$MAJOR.$$((MINOR + 1)).0"; \
	elif [ "$(BUMP)" = "patch" ]; then \
		NEW_VERSION="$$MAJOR.$$MINOR.$$((PATCH + 1))"; \
	else \
		echo "❌ Invalid BUMP value: $(BUMP). Use patch, minor, or major"; \
		exit 1; \
	fi; \
	echo "🔢 Bumping $(BUMP) version: $$CURRENT_VERSION -> $$NEW_VERSION"; \
	sed -i.bak "s/\"version\": \"[^\"]*\"/\"version\": \"$$NEW_VERSION\"/" auto-focus-browser-extension/chrome/manifest.json; \
	rm -f auto-focus-browser-extension/chrome/manifest.json.bak; \
	echo "📦 Creating extension ZIP for version $$NEW_VERSION..."; \
	cd auto-focus-browser-extension && zip -r ../$(EXTENSION_ZIP) chrome/ -x "*.DS_Store*" "*/.git*"; \
	echo "✅ Extension built and packaged at $(EXTENSION_ZIP)"; \
	echo "📋 Extension info:"; \
	echo "   Version: $$NEW_VERSION"; \
	echo "   File: $(EXTENSION_ZIP)"; \
	echo "   Ready for Chrome Web Store submission"

# Distribution targets
prepare-downloads:
	@echo "Creating downloads directory..."
	@mkdir -p $(DOWNLOADS_DIR)

prepare-app-for-notarization: archive-mac
	@echo "Preparing app for notarization..."
	@if [ ! -d "$(ARCHIVE_PATH)" ]; then \
		echo "Archive not found. Run 'make archive-mac' first."; \
		exit 1; \
	fi
	@echo "Extracting app from archive..."
	@rm -rf $(BUILD_DIR)/$(PROJECT_NAME)_temp.app
	@cp -R "$(ARCHIVE_PATH)/Products/Applications/$(PROJECT_NAME).app" "$(BUILD_DIR)/$(PROJECT_NAME)_temp.app"
	@echo "Code signing app for notarization..."
	@codesign --sign "Developer ID Application: Jan Schill (LKQJ2JG34Y)" \
		--timestamp \
		--options runtime \
		--deep \
		--force \
		"$(BUILD_DIR)/$(PROJECT_NAME)_temp.app"
	@echo "Verifying code signature..."
	@codesign --verify --verbose "$(BUILD_DIR)/$(PROJECT_NAME)_temp.app"
	@echo "Creating ZIP for notarization..."
	@cd $(BUILD_DIR) && zip -r $(PROJECT_NAME)_notarization.zip $(PROJECT_NAME)_temp.app
	@echo "✅ App ready for notarization at $(BUILD_DIR)/$(PROJECT_NAME)_notarization.zip"

package-app: prepare-downloads
	@echo "Packaging notarized app for distribution..."
	@if [ ! -d "$(BUILD_DIR)/$(PROJECT_NAME)_temp.app" ]; then \
		echo "Prepared app not found. Run 'make prepare-app-for-notarization' first."; \
		exit 1; \
	fi
	@echo "Verifying notarization..."
	@if ! xcrun stapler validate "$(BUILD_DIR)/$(PROJECT_NAME)_temp.app" 2>/dev/null; then \
		echo "⚠️  WARNING: App may not be properly notarized!"; \
		echo "   Make sure you've run the notarization steps from prepare-app-for-notarization"; \
		echo "   Continuing anyway..."; \
	else \
		echo "✅ App is properly notarized"; \
	fi
	@echo "Renaming app for distribution..."
	@cd $(BUILD_DIR) && cp -R $(PROJECT_NAME)_temp.app $(PROJECT_NAME).app
	@echo "Removing old ZIP file..."
	@rm -f $(APP_ZIP)
	@echo "Creating final distribution ZIP..."
	@cd $(BUILD_DIR) && zip -r ../$(APP_ZIP) $(PROJECT_NAME).app
	@echo "Verifying ZIP contents..."
	@if unzip -l $(APP_ZIP) | grep -q "$(PROJECT_NAME).app/"; then \
		echo "✅ ZIP contains correctly named $(PROJECT_NAME).app"; \
	else \
		echo "❌ ERROR: ZIP does not contain $(PROJECT_NAME).app!"; \
		unzip -l $(APP_ZIP) | head -10; \
		exit 1; \
	fi
	@echo "Cleaning up temporary files..."
	@rm -rf $(BUILD_DIR)/$(PROJECT_NAME).app $(BUILD_DIR)/$(PROJECT_NAME)_temp.app
	@echo "✅ App packaged for distribution at $(APP_ZIP)"

package-extension:
	@echo "⚠️  DEPRECATED: Use 'make build-extension BUMP=patch|minor|major' instead"
	@echo "   This target now calls build-extension with patch bump"
	@$(MAKE) build-extension BUMP=patch

# Release extension to Chrome Web Store
# Usage: make release-extension BUMP=patch|minor|major
release-extension: build-extension
	@echo ""
	@echo "✅ Extension ready for Chrome Web Store submission!"
	@echo ""
	@echo "📦 Package location: $(EXTENSION_ZIP)"
	@echo ""
	@echo "📋 Next steps:"
	@echo "   1. Go to: https://chrome.google.com/webstore/devconsole"
	@echo "   2. Select your extension"
	@echo "   3. Click 'Upload Updated Package'"
	@echo "   4. Upload: $(EXTENSION_ZIP)"
	@echo "   5. Fill in release notes and submit"
	@echo ""
	@echo "📖 See CHROME_STORE_RELEASE.md for detailed instructions"

generate-version: prepare-downloads
	@echo "Generating version information..."
	@VERSION=$$(date +"%Y.%m.%d"); \
	BUILD_DATE=$$(date -u +"%Y-%m-%dT%H:%M:%SZ"); \
	COMMIT_HASH=$$(git rev-parse --short HEAD 2>/dev/null || echo "unknown"); \
	echo "{ \
		\"version\": \"$$VERSION\", \
		\"build_date\": \"$$BUILD_DATE\", \
		\"commit_hash\": \"$$COMMIT_HASH\", \
		\"app_zip\": \"Auto-Focus.zip\", \
		\"extension_zip\": \"auto-focus-extension.zip\", \
		\"download_url\": \"https://auto-focus.app/downloads/Auto-Focus.zip\", \
		\"min_macos\": \"14.0\" \
	}" > $(VERSION_FILE)
	@echo "✅ Version file generated at $(VERSION_FILE)"
	@echo "📋 Release info:"
	@echo "   Version: $$VERSION"
	@echo "   Commit: $$COMMIT_HASH"
	@echo "   Date: $$BUILD_DATE"

# ⚠️  CRITICAL: This target prepares distribution files but does NOT handle notarization
# You MUST notarize the app before running this target - see prepare-app-for-notarization
prepare-distribution: prepare-downloads package-extension generate-version
	@echo "🚨 DISTRIBUTION PREPARATION COMPLETE 🚨"
	@echo ""
	@echo "⚠️  CRITICAL STEP REQUIRED:"
	@echo "   1. Prepare for notarization: make prepare-app-for-notarization"
	@echo "   2. Follow the notarization steps shown by that command"
	@echo "   3. Then run: make package-app"
	@echo ""
	@echo "Files will be ready in $(DOWNLOADS_DIR)/"
	@echo "Update your website to point to these local files instead of GitHub releases."

# Deploy downloads (updates website and manages git)
deploy-downloads: prepare-distribution package-app
	@echo "🚀 Finalizing distribution..."
	@echo "📝 Updating website download links..."
	@sed -i.bak 's|https://github.com/janschill/auto-focus/releases/latest/download/Auto-Focus.zip|downloads/Auto-Focus.zip|g' docs/index.html
	@rm -f docs/index.html.bak
	@echo "✅ Website updated to use local downloads"
	@echo ""
	@echo "📦 Managing git files..."
	@echo "Removing old distribution files from git tracking (keeping files)..."
	@git rm --cached --ignore-unmatch docs/downloads/*.zip 2>/dev/null || true
	@echo "Adding current distribution files to git..."
	@git add docs/downloads/Auto-Focus.zip docs/downloads/auto-focus-extension.zip docs/downloads/version.json docs/index.html
	@echo ""
	@echo "🎉 DISTRIBUTION READY!"
	@echo "   App: $(APP_ZIP) (added to git)"
	@echo "   Extension: $(EXTENSION_ZIP) (added to git)"
	@echo "   Version: $(VERSION_FILE) (added to git)"
	@echo "   Website: Updated to use local downloads"
	@echo ""
	@echo "💡 Next steps:"
	@echo "   1. Commit these changes: git commit -m 'Release: Update distribution files'"
	@echo "   2. Create GitHub release with same files for backup/history"
	@echo "   3. Push to deploy: git push origin main"

# Optional DMG creation (for special releases)
create-dmg: package-app
	@echo "Creating DMG (optional distribution format)..."
	@if ! command -v create-dmg >/dev/null 2>&1; then \
		echo "⚠️  create-dmg not installed. Install with: brew install create-dmg"; \
		echo "   Skipping DMG creation..."; \
		exit 0; \
	fi
	@VERSION=$$(date +"%Y.%m.%d"); \
	DMG_NAME="Auto-Focus-$$VERSION.dmg"; \
	create-dmg --volname "Auto-Focus $$VERSION" \
		--background-color "#f8fafc" \
		--window-size 600 400 \
		--icon-size 80 \
		--icon "auto-focus.app" 150 200 \
		--app-drop-link 450 200 \
		"$(DOWNLOADS_DIR)/$$DMG_NAME" \
		"$(BUILD_DIR)/auto-focus_temp.app" 2>/dev/null || echo "DMG creation failed"
	@if [ -f "$(DOWNLOADS_DIR)/$$DMG_NAME" ]; then \
		echo "✅ DMG created at $(DOWNLOADS_DIR)/$$DMG_NAME"; \
	fi

# Check for version bump
check-version-bump:
	@echo "🔍 Checking for version bump..."
	@if git diff --name-only | grep -q "auto-focus.xcodeproj/project.pbxproj"; then \
		if git diff auto-focus.xcodeproj/project.pbxproj | grep -q "MARKETING_VERSION"; then \
			echo "✅ Version bump detected in project.pbxproj"; \
			CURRENT_VERSION=$$(grep "MARKETING_VERSION" auto-focus.xcodeproj/project.pbxproj | head -1 | sed 's/.*= \(.*\);/\1/' | tr -d ' '); \
			echo "📋 New version: $$CURRENT_VERSION"; \
		else \
			echo "⚠️  WARNING: project.pbxproj changed but no MARKETING_VERSION bump detected"; \
			echo "   Consider bumping version for this release"; \
		fi; \
	else \
		echo "ℹ️  No changes to project.pbxproj - version remains the same"; \
	fi

# Tag release in git
tag-release: check-version-bump
	@VERSION=$$(date +"%Y.%m.%d"); \
	echo "Creating git tag for version $$VERSION..."; \
	git tag -a "v$$VERSION" -m "Release $$VERSION" 2>/dev/null || echo "Tag already exists"; \
	echo "📝 Push tags with: git push origin --tags"

# Create GitHub release using gh CLI
create-github-release: tag-release
	@if ! command -v gh >/dev/null 2>&1; then \
		echo "❌ GitHub CLI (gh) not installed. Install with: brew install gh"; \
		echo "   Then run: gh auth login"; \
		exit 1; \
	fi
	@VERSION=$$(date +"%Y.%m.%d"); \
	echo "Creating GitHub release v$$VERSION..."; \
	git push origin "v$$VERSION" 2>/dev/null || echo "Tag already pushed"; \
	RELEASE_NOTES="## Auto-Focus v$$VERSION\n\n### Features\n- Intelligent focus detection\n- Browser integration with Chrome extension\n- Focus session analytics\n- Configurable thresholds and buffer times\n\n### Installation\n1. Download Auto-Focus.zip\n2. Extract and move Auto-Focus.app to Applications\n3. Install the included Shortcut\n4. Launch and configure focus apps\n\n### System Requirements\n- macOS Sonoma (14.0) or later\n- Chrome browser (for extension)\n\n---\n\n🔗 **Website**: https://auto-focus.app  \n📧 **Support**: auto-focus@janschill.de"; \
	gh release create "v$$VERSION" \
		"docs/downloads/Auto-Focus.zip#Auto-Focus.zip" \
		"docs/downloads/auto-focus-extension.zip#Chrome-Extension.zip" \
		--title "Auto-Focus v$$VERSION" \
		--notes "$$RELEASE_NOTES" \
		--latest || echo "Release may already exist"
	@echo "✅ GitHub release created at: https://github.com/janschill/auto-focus/releases/tag/v$$VERSION"

# Phase 1: Build and prepare for release (includes automated notarization)
prepare-release: deep-clean archive-mac prepare-app-for-notarization
	@echo ""
	@echo "🚀 Starting automated notarization..."
	@echo "   This may take 1-5 minutes..."
	@if xcrun notarytool submit 'build/auto-focus_notarization.zip' --keychain-profile 'Developer' --wait; then \
		echo "✅ Notarization successful!"; \
		echo "📎 Stapling notarization ticket..."; \
		if xcrun stapler staple 'build/auto-focus_temp.app'; then \
			echo "✅ Stapling successful!"; \
			echo ""; \
			echo "🎯 PHASE 1 COMPLETE: Build & Notarization"; \
			echo ""; \
			echo "✅ App built with current version"; \
			echo "✅ App notarized and stapled"; \
			echo ""; \
			echo "🚀 Next: Run 'make complete-release' to deploy"; \
		else \
			echo "❌ Stapling failed!"; \
			echo "   Try manually: xcrun stapler staple 'build/auto-focus_temp.app'"; \
			exit 1; \
		fi; \
	else \
		echo "❌ Notarization failed!"; \
		echo "   Check your keychain profile 'Developer' is configured"; \
		echo "   Run: xcrun notarytool store-credentials 'Developer' --apple-id 'your@email.com' --team-id 'YOUR_TEAM_ID'"; \
		exit 1; \
	fi

# Check that Phase 1 was completed before deploying
check-build-ready:
	@echo "🔍 Checking if build is ready for release..."
	@if [ ! -d "build/auto-focus_temp.app" ]; then \
		echo "❌ No prepared app found. Run 'make prepare-release' first."; \
		exit 1; \
	fi
	@if ! xcrun stapler validate "build/auto-focus_temp.app" 2>/dev/null; then \
		echo "❌ App is not properly notarized. Complete notarization steps first."; \
		echo "   Run: xcrun notarytool submit 'build/auto-focus_notarization.zip' --keychain-profile 'Developer' --wait"; \
		echo "   Then: xcrun stapler staple 'build/auto-focus_temp.app'"; \
		exit 1; \
	fi
	@echo "✅ Build is ready for release"

# Phase 2: Complete the release (package, deploy, create GitHub release)
complete-release: check-build-ready package-app deploy-downloads create-github-release
	@VERSION=$$(date +"%Y.%m.%d"); \
	echo ""; \
	echo "📝 Committing release changes..."; \
	git status --porcelain; \
	git commit -m "Release v$$VERSION: Update distribution files and website - 🤖 Generated with Claude Code"; \
	echo "✅ Changes committed"; \
	echo ""; \
	echo "🎉 RELEASE v$$VERSION COMPLETE!"; \
	echo ""; \
	echo "✅ Distribution files updated and committed"; \
	echo "✅ Website updated to use local downloads"; \
	echo "✅ Git tag v$$VERSION created"; \
	echo "✅ GitHub release created with assets"; \
	echo "✅ All changes committed to git"; \
	echo ""; \
	echo "🌐 Your website is now live with direct downloads!"; \
	echo "📦 GitHub release provides backup distribution"; \
	echo ""; \
	echo "🚀 Final step: Push to deploy"; \
	echo "   git push origin main --tags"

# Legacy target (deprecated - use prepare-release + complete-release)
manual-release:
	@echo "⚠️  DEPRECATED: Use the new streamlined process instead:"
	@echo "   1. make prepare-release    (builds, signs, and notarizes automatically)"
	@echo "   2. make complete-release   (packages and deploys)"
	@echo ""
	@echo "This ensures proper build with current version, automated notarization, and safer release process."

# Complete build pipeline
release: clean build codesign-check
	@echo "Release build complete!"

# Development workflow
dev: build test lint
	@echo "Development workflow complete!"

# Help
help:
	@echo "Available targets:"
	@echo ""
	@echo "📦 Build & Development:"
	@echo "  build             - Build the macOS app"
	@echo "  test              - Run tests"
	@echo "  clean             - Clean build artifacts"
	@echo "  archive-mac       - Create app archive"
	@echo "  release           - Complete release build"
	@echo "  dev               - Development workflow"
	@echo ""
	@echo "🔐 Code Signing & Notarization:"
	@echo "  codesign-check    - Verify code signature"
	@echo "  codesign-verify   - Verify and assess code signature"
	@echo "  notarize          - Submit for Apple notarization"
	@echo ""
	@echo "🚀 Distribution:"
	@echo "  prepare-downloads         - Create downloads directory"
	@echo "  prepare-app-for-notarization - Prepare app ZIP for notarization"
	@echo "  package-app              - Package notarized app (run after notarization)"
	@echo "  package-extension        - Package browser extension"
	@echo "  generate-version         - Create version.json file"
	@echo "  prepare-distribution     - Prepare all distribution files"
	@echo "  deploy-downloads         - Update website to use local downloads"
	@echo ""
	@echo "🛠️  Utilities:"
	@echo "  lint                     - Run SwiftLint"
	@echo "  format                   - Format Swift code"
	@echo "  ai-context               - Generate AI context files"
	@echo "  help                     - Show this help"
	@echo ""
	@echo "💡 New Release Workflow (Fully Automated):"
	@echo "  1. make prepare-release      - Clean, build, sign, and notarize automatically"
	@echo "  2. make complete-release     - Package, verify naming, deploy, create GitHub release"
	@echo ""
	@echo "🔐 Security Features:"
	@echo "  - Uses 'Developer' keychain profile consistently"
	@echo "  - Automatic code signing with Developer ID certificate"
	@echo "  - Verifies app naming in final ZIP (auto-focus.app)"
	@echo ""
	@echo "🎯 Release Management:"
	@echo "  prepare-release          - Phase 1: Build and prepare for notarization"
	@echo "  check-build-ready        - Verify build is ready for release"
	@echo "  complete-release         - Phase 2: Package, deploy, create GitHub release"
	@echo "  tag-release              - Tag current version in git"
	@echo "  create-github-release    - Create GitHub release with assets"
	@echo "  manual-release           - (DEPRECATED) Use prepare-release + complete-release"
	@echo ""
	@echo "🎯 Optional:"
	@echo "  create-dmg               - Create DMG format (requires create-dmg)"

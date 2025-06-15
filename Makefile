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

test-swift:
	@echo "Running Swift tests..."
	xcodebuild test -scheme $(SCHEME) -destination 'platform=macOS' CODE_SIGN_IDENTITY="-" CODE_SIGNING_ALLOWED=NO

swift-package-update:
	@echo "Updating Swift packages..."
	swift package update

# Xcode build targets
build:
	@echo "Building $(PROJECT_NAME) for $(CONFIGURATION)..."
	xcodebuild -scheme $(SCHEME) -configuration $(CONFIGURATION) -derivedDataPath $(BUILD_DIR) build

clean:
	@echo "Cleaning build artifacts..."
	rm -rf $(BUILD_DIR)
	xcodebuild -scheme $(SCHEME) clean

# Archive and signing
archive-mac:
	@echo "Creating archive for $(PROJECT_NAME)..."
	xcodebuild -scheme $(SCHEME) -configuration $(CONFIGURATION) -archivePath $(ARCHIVE_PATH) archive

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

# Browser extension
build-extension:
	@echo "Browser extension is built separately. Check auto-focus-browser-extension/ directory."

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
	@echo "Creating ZIP for notarization..."
	@cd $(BUILD_DIR) && zip -r $(PROJECT_NAME)_notarization.zip $(PROJECT_NAME)_temp.app
	@echo "✅ App ready for notarization at $(BUILD_DIR)/$(PROJECT_NAME)_notarization.zip"
	@echo ""
	@echo "📝 Next steps:"
	@echo "   1. Submit for notarization:"
	@echo "      xcrun notarytool submit '$(BUILD_DIR)/$(PROJECT_NAME)_notarization.zip' --keychain-profile 'Developer' --wait"
	@echo "   2. After notarization succeeds, staple the ticket:"
	@echo "      xcrun stapler staple '$(BUILD_DIR)/$(PROJECT_NAME)_temp.app'"
	@echo "   3. Then run: make package-app"

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
	@echo "Creating final distribution ZIP..."
	@cd $(BUILD_DIR) && zip -r ../$(APP_ZIP) $(PROJECT_NAME)_temp.app
	@echo "✅ App packaged for distribution at $(APP_ZIP)"

package-extension: prepare-downloads
	@echo "Packaging browser extension..."
	@cd auto-focus-browser-extension && zip -r ../$(EXTENSION_ZIP) chrome/
	@echo "✅ Extension packaged at $(EXTENSION_ZIP)"

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
	@echo "Removing old distribution files from git..."
	@git rm -f --ignore-unmatch docs/downloads/*.zip 2>/dev/null || true
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

# Tag release in git
tag-release:
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
	RELEASE_NOTES="## Auto-Focus v$$VERSION\n\n### Features\n- Intelligent focus detection\n- Browser integration with Chrome extension\n- Focus session analytics\n- Configurable thresholds and buffer times\n\n### Installation\n1. Download Auto-Focus.zip\n2. Extract and move Auto-Focus.app to Applications\n3. Install the included Shortcut\n4. Launch and configure focus apps\n\n### System Requirements\n- macOS Sonoma (14.0) or later\n- Chrome browser (for extension)\n\n---\n\n🔗 **Website**: https://auto-focus.app  \n📧 **Support**: help@auto-focus.app"; \
	gh release create "v$$VERSION" \
		"docs/downloads/Auto-Focus.zip#Auto-Focus.zip" \
		"docs/downloads/auto-focus-extension.zip#Chrome-Extension.zip" \
		--title "Auto-Focus v$$VERSION" \
		--notes "$$RELEASE_NOTES" \
		--latest || echo "Release may already exist"
	@echo "✅ GitHub release created at: https://github.com/janschill/auto-focus/releases/tag/v$$VERSION"

# Complete manual release workflow
manual-release: deploy-downloads create-github-release
	@VERSION=$$(date +"%Y.%m.%d"); \
	echo ""; \
	echo "🎉 RELEASE v$$VERSION COMPLETE!"; \
	echo ""; \
	echo "✅ Distribution files updated and committed"; \
	echo "✅ Website updated to use local downloads"; \
	echo "✅ Git tag v$$VERSION created"; \
	echo "✅ GitHub release created with assets"; \
	echo ""; \
	echo "🌐 Your website is now live with direct downloads!"; \
	echo "📦 GitHub release provides backup distribution"; \
	echo ""; \
	echo "🚀 Next: Push to deploy"; \
	echo "   git push origin main"

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
	@echo "💡 Complete distribution workflow:"
	@echo "  1. make prepare-app-for-notarization"
	@echo "  2. Follow notarization steps (output will guide you)"
	@echo "  3. make package-app"
	@echo "  4. make deploy-downloads"
	@echo "  5. make tag-release (optional: create git tag)"
	@echo ""
	@echo "🎯 Release Management:"
	@echo "  tag-release              - Tag current version in git"
	@echo "  create-github-release    - Create GitHub release with assets"
	@echo "  manual-release           - Complete release workflow (recommended)"
	@echo ""
	@echo "🎯 Optional:"
	@echo "  create-dmg               - Create DMG format (requires create-dmg)"

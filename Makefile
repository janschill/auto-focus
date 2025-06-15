.PHONY: build test clean lint format ai-context swift-package-update codesign-check archive-mac notarize prepare-downloads package-app package-extension generate-version prepare-distribution deploy-downloads

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
	swift test --parallel

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

package-app: archive-mac
	@echo "Packaging notarized app for distribution..."
	@if [ ! -d "$(ARCHIVE_PATH)" ]; then \
		echo "Archive not found. Run 'make archive-mac' first."; \
		exit 1; \
	fi
	@echo "Creating app package from archive..."
	@rm -rf $(BUILD_DIR)/$(PROJECT_NAME)_temp.app
	@cp -R "$(ARCHIVE_PATH)/Products/Applications/$(PROJECT_NAME).app" "$(BUILD_DIR)/$(PROJECT_NAME)_temp.app"
	@echo "⚠️  IMPORTANT: Ensure the app is notarized before distribution!"
	@echo "   Run: xcrun notarytool submit '$(BUILD_DIR)/$(PROJECT_NAME)_temp.app' --keychain-profile 'Developer' --wait"
	@echo "   Then run: xcrun stapler staple '$(BUILD_DIR)/$(PROJECT_NAME)_temp.app'"
	@echo "Creating ZIP package..."
	@cd $(BUILD_DIR) && zip -r ../$(APP_ZIP) $(PROJECT_NAME)_temp.app
	@rm -rf $(BUILD_DIR)/$(PROJECT_NAME)_temp.app
	@echo "✅ App packaged at $(APP_ZIP)"

package-extension: prepare-downloads
	@echo "Packaging browser extension..."
	@cd auto-focus-browser-extension && zip -r ../$(EXTENSION_ZIP) chrome/
	@echo "✅ Extension packaged at $(EXTENSION_ZIP)"

generate-version: prepare-downloads
	@echo "Generating version information..."
	@VERSION=$$(date +"%Y.%m.%d"); \
	BUILD_DATE=$$(date -u +"%Y-%m-%dT%H:%M:%SZ"); \
	echo "{ \
		\"version\": \"$$VERSION\", \
		\"build_date\": \"$$BUILD_DATE\", \
		\"app_zip\": \"Auto-Focus.zip\", \
		\"extension_zip\": \"auto-focus-extension.zip\", \
		\"min_macos\": \"14.0\" \
	}" > $(VERSION_FILE)
	@echo "✅ Version file generated at $(VERSION_FILE)"

# ⚠️  CRITICAL: This target prepares distribution files but does NOT handle notarization
# You MUST notarize the app before running this target:
# 1. Run: make archive-mac
# 2. Run: xcrun notarytool submit 'build/auto-focus_temp.app' --keychain-profile 'Developer' --wait
# 3. Run: xcrun stapler staple 'build/auto-focus_temp.app'  
# 4. Then run: make prepare-distribution
prepare-distribution: prepare-downloads package-extension generate-version
	@echo "🚨 DISTRIBUTION PREPARATION COMPLETE 🚨"
	@echo ""
	@echo "⚠️  CRITICAL STEP REQUIRED:"
	@echo "   1. Build and archive: make archive-mac"
	@echo "   2. Notarize the app manually (see above)"
	@echo "   3. Then run: make package-app"
	@echo ""
	@echo "Files will be ready in $(DOWNLOADS_DIR)/"
	@echo "Update your website to point to these local files instead of GitHub releases."

# Deploy downloads (updates website links to local files)
deploy-downloads: prepare-distribution
	@echo "🚀 Updating website download links..."
	@sed -i.bak 's|https://github.com/janschill/auto-focus/releases/latest/download/Auto-Focus.zip|downloads/Auto-Focus.zip|g' docs/index.html
	@rm -f docs/index.html.bak
	@echo "✅ Website updated to use local downloads"
	@echo ""
	@echo "🎉 DISTRIBUTION READY!"
	@echo "   App: $(APP_ZIP)"
	@echo "   Extension: $(EXTENSION_ZIP)"
	@echo "   Version: $(VERSION_FILE)"

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
	@echo "  prepare-downloads - Create downloads directory"
	@echo "  package-app       - Package notarized app (requires manual notarization first)"
	@echo "  package-extension - Package browser extension"
	@echo "  generate-version  - Create version.json file"
	@echo "  prepare-distribution - Prepare all distribution files"
	@echo "  deploy-downloads  - Update website to use local downloads"
	@echo ""
	@echo "🛠️  Utilities:"
	@echo "  lint              - Run SwiftLint"
	@echo "  format            - Format Swift code"
	@echo "  ai-context        - Generate AI context files"
	@echo "  help              - Show this help"
	@echo ""
	@echo "💡 Quick distribution workflow:"
	@echo "  1. make archive-mac"
	@echo "  2. Manually notarize (see package-app target output)"
	@echo "  3. make package-app"
	@echo "  4. make deploy-downloads"

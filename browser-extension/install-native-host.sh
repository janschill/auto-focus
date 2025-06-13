#!/bin/bash

# Install Native Messaging Host for Auto-Focus Browser Extension
# This script installs the native messaging manifest for Chrome

MANIFEST_FILE="native-messaging/com.autofocus.browser.json"
CHROME_NATIVE_DIR="$HOME/Library/Application Support/Google/Chrome/NativeMessagingHosts"

echo "🔧 Installing Auto-Focus Native Messaging Host..."

# Create Chrome native messaging directory if it doesn't exist
mkdir -p "$CHROME_NATIVE_DIR"

# Copy the manifest file
if [ -f "$MANIFEST_FILE" ]; then
    cp "$MANIFEST_FILE" "$CHROME_NATIVE_DIR/"
    echo "✅ Native messaging manifest installed to:"
    echo "   $CHROME_NATIVE_DIR/com.autofocus.browser.json"
else
    echo "❌ Error: Manifest file not found at $MANIFEST_FILE"
    exit 1
fi

# Set proper permissions
chmod 644 "$CHROME_NATIVE_DIR/com.autofocus.browser.json"

echo ""
echo "📋 Next steps:"
echo "1. Update the extension ID in the manifest after Chrome extension installation"
echo "2. Build and install the Auto-Focus app with native messaging support"
echo "3. Load the extension in Chrome"
echo ""
echo "🎯 Installation complete!"
#!/bin/bash

# Auto-Focus Browser Extension Bridge
# This script handles native messaging for the Chrome extension

NATIVE_HOST="/Users/janschill/code/janschill/auto-focus/browser-extension/native-host.swift"

# Run the native messaging host
exec "$NATIVE_HOST"
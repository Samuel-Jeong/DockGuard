#!/usr/bin/env bash
set -euo pipefail

# DockGuard Code Signing and Build Script
# This script demonstrates how to properly sign DockGuard with a Developer ID
# 
# Prerequisites:
# 1. Valid Apple Developer ID certificate installed in Keychain
# 2. Xcode Command Line Tools installed
#
# Usage:
#   ./sign_and_build.sh "Developer ID Application: Your Name (TEAM_ID)"
#
# Or set environment variable:
#   export DEVELOPER_ID="Developer ID Application: Your Name (TEAM_ID)"
#   ./sign_and_build.sh

# Check if Developer ID is provided as argument or environment variable
if [[ $# -gt 0 ]]; then
    DEVELOPER_ID="$1"
elif [[ -z "${DEVELOPER_ID:-}" ]]; then
    echo "Error: Developer ID certificate name required"
    echo ""
    echo "Usage:"
    echo "  $0 \"Developer ID Application: Your Name (TEAM_ID)\""
    echo ""
    echo "Or set environment variable:"
    echo "  export DEVELOPER_ID=\"Developer ID Application: Your Name (TEAM_ID)\""
    echo "  $0"
    echo ""
    echo "To list available certificates:"
    echo "  security find-identity -v -p codesigning"
    exit 1
fi

echo "Building and signing DockGuard with Developer ID..."
echo "Certificate: $DEVELOPER_ID"
echo ""

# Clean previous build and build with signing
CLEAN=1 SIGN=1 DEVELOPER_ID="$DEVELOPER_ID" ./build.sh

echo ""
echo "Verifying code signature..."
codesign -dv --verbose=4 "DockGuard.app"

echo ""
echo "Build and signing complete!"
echo "The app should now have:"
echo "- Proper Info.plist binding"
echo "- Team Identifier set"
echo "- Sealed Resources"
echo "- Internal requirements"
echo ""
echo "For App Store or distribution, you may also want to notarize:"
echo "  xcrun notarytool submit DockGuard.app.zip --keychain-profile \"notarytool-profile\" --wait"
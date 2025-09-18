#!/usr/bin/env bash
set -euo pipefail

# DockGuard build script
# Requirements: Xcode Command Line Tools (xcode-select --install)
# Usage:
#   chmod +x build.sh
#   ./build.sh            # builds DockGuard.app in current directory
#   SIGN=1 ./build.sh     # optionally ad-hoc code sign the app
#   CLEAN=1 ./build.sh    # remove previous build before building
#
# After building, run:
#   open "DockGuard.app"
#
# Notes:
# - The app requests Accessibility permission on first run (System Settings > Privacy & Security > Accessibility).
# - This script compiles all .m files in the directory and links Cocoa and ApplicationServices.

APP_NAME="DockGuard"
BUNDLE="$APP_NAME.app"
CONTENTS="$BUNDLE/Contents"
MACOS="$CONTENTS/MacOS"
RESOURCES="$CONTENTS/Resources"
PLIST_FILE="Info.plist"

if [[ "${CLEAN:-0}" != "0" ]]; then
  rm -rf "$BUNDLE"
fi

mkdir -p "$MACOS" "$RESOURCES"

# Locate tools and SDK
if ! command -v xcrun >/dev/null 2>&1; then
  echo "xcrun not found. Please install Xcode Command Line Tools (xcode-select --install)."
  exit 1
fi
SDK_PATH=$(xcrun --sdk macosx --show-sdk-path)
CC=$(xcrun -find clang)

# Gather sources (compatible with older macOS bash without 'mapfile')
shopt -s nullglob
SOURCES=( *.m )
if [[ ${#SOURCES[@]} -eq 0 ]]; then
  echo "No .m source files found in $(pwd)."
  exit 1
fi

CFLAGS=(
  -fobjc-arc
  -mmacosx-version-min=10.13
  -isysroot "$SDK_PATH"
)
LDFLAGS=(
  -framework Cocoa
  -framework ApplicationServices
  -ObjC
)

# Build binary
"$CC" "${CFLAGS[@]}" "${SOURCES[@]}" -o "$MACOS/$APP_NAME" "${LDFLAGS[@]}"

# Copy Info.plist
if [[ -f "$PLIST_FILE" ]]; then
  cp "$PLIST_FILE" "$CONTENTS/Info.plist"
else
  cat >"$CONTENTS/Info.plist" <<'EOF'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>CFBundleDevelopmentRegion</key>
  <string>en</string>
  <key>CFBundleExecutable</key>
  <string>DockGuard</string>
  <key>CFBundleIdentifier</key>
  <string>com.example.DockGuard</string>
  <key>CFBundleInfoDictionaryVersion</key>
  <string>6.0</string>
  <key>CFBundleName</key>
  <string>DockGuard</string>
  <key>CFBundlePackageType</key>
  <string>APPL</string>
  <key>CFBundleShortVersionString</key>
  <string>1.0</string>
  <key>CFBundleVersion</key>
  <string>1</string>
  <key>LSMinimumSystemVersion</key>
  <string>10.13</string>
  <key>LSUIElement</key>
  <true/>
  <key>NSPrincipalClass</key>
  <string>NSApplication</string>
</dict>
</plist>
EOF
fi

# Optional ad-hoc code signing (helps with some permissions on certain systems)
if [[ "${SIGN:-0}" != "0" ]]; then
  if command -v codesign >/dev/null 2>&1; then
    echo "Ad-hoc signing $BUNDLE ..."
    codesign --force --deep --sign - "$BUNDLE" || true
  fi
fi

echo "Build succeeded: $BUNDLE"
echo "Run: open '$BUNDLE'"
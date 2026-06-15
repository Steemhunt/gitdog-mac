#!/bin/bash
# Assemble GitDog.app from the SwiftPM release build.
# No Xcode required — works with Command Line Tools only.
#
# Usage:
#   ./scripts/make-app.sh [debug|release]    # default: release
#
# Point the build at a non-default server (e.g. a shared test tunnel) by setting
# GITDOG_SERVER — it is baked into the bundle's LSEnvironment so a plain
# `open dist/GitDog.app` picks it up (`open` does not forward your shell env).
# Must be an absolute http(s) URL.
#   GITDOG_SERVER=https://example.trycloudflare.com ./scripts/make-app.sh
set -euo pipefail
cd "$(dirname "$0")/.."

CONF="${1:-release}"
swift build -c "$CONF"

BIN=".build/$CONF/GitDog"
APP="dist/GitDog.app"
# Single source of truth for the bundle version (used in Info.plist below).
VERSION="0.1.0"

rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
cp "$BIN" "$APP/Contents/MacOS/GitDog"

cat > "$APP/Contents/Info.plist" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>CFBundleExecutable</key><string>GitDog</string>
  <key>CFBundleIdentifier</key><string>xyz.gitdog.mac</string>
  <key>CFBundleName</key><string>GitDog</string>
  <key>CFBundleDisplayName</key><string>GitDog</string>
  <key>CFBundlePackageType</key><string>APPL</string>
  <key>CFBundleShortVersionString</key><string>$VERSION</string>
  <key>CFBundleVersion</key><string>1</string>
  <key>LSMinimumSystemVersion</key><string>14.0</string>
  <key>LSUIElement</key><true/>
  <key>CFBundleURLTypes</key>
  <array>
    <dict>
      <key>CFBundleURLName</key><string>GitDog auth callback</string>
      <key>CFBundleURLSchemes</key><array><string>gitdog</string></array>
    </dict>
  </array>
  <key>NSHighResolutionCapable</key><true/>
</dict>
</plist>
PLIST

# Bake the server override into LSEnvironment when provided, so `open` launches
# against it without the caller having to forward env vars by hand.
if [ -n "${GITDOG_SERVER:-}" ]; then
  case "$GITDOG_SERVER" in
    http://*|https://*)
      /usr/libexec/PlistBuddy \
        -c "Add :LSEnvironment dict" \
        -c "Add :LSEnvironment:GITDOG_SERVER string $GITDOG_SERVER" \
        "$APP/Contents/Info.plist" >/dev/null
      echo "Server:  $GITDOG_SERVER (baked into LSEnvironment)"
      ;;
    *)
      echo "WARNING: ignoring GITDOG_SERVER='$GITDOG_SERVER' (need an absolute http(s) URL)" >&2
      ;;
  esac
fi

echo "Built $APP"
echo "Run:  open $APP"

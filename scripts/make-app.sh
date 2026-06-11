#!/bin/bash
# Assemble GitDog.app from the SwiftPM release build.
# No Xcode required — works with Command Line Tools only.
set -euo pipefail
cd "$(dirname "$0")/.."

CONF="${1:-release}"
swift build -c "$CONF"

BIN=".build/$CONF/GitDog"
APP="dist/GitDog.app"
VERSION=$(grep -m1 '"version"' VERSION 2>/dev/null || echo "0.1.0")

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
  <key>CFBundleShortVersionString</key><string>0.1.0</string>
  <key>CFBundleVersion</key><string>1</string>
  <key>LSMinimumSystemVersion</key><string>14.0</string>
  <key>LSUIElement</key><true/>
  <key>NSHighResolutionCapable</key><true/>
</dict>
</plist>
PLIST

echo "Built $APP"
echo "Run:  open $APP"

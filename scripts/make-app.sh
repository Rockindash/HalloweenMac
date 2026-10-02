#!/bin/bash
# Builds "Fall Dock.app" into the build/ folder.
# Usage: ./scripts/make-app.sh
set -euo pipefail
cd "$(dirname "$0")/.."

echo "Building Fall Dock (this takes a minute the first time)..."
swift build -c release

APP="build/Fall Dock.app"
rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
cp "$(swift build -c release --show-bin-path)/FallDock" "$APP/Contents/MacOS/FallDock"
cp Support/Info.plist "$APP/Contents/Info.plist"

# Ad-hoc signature so macOS is happy running it on this Mac.
codesign --force --deep --sign - "$APP"

echo ""
echo "Done! Your app is at: $APP"
echo "Open it with:  open \"$APP\""

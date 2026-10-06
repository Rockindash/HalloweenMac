#!/bin/sh
# Wraps Dockorate.app in a fall-themed drag-to-Applications disk image.
#
#   scripts/make-dmg.sh path/to/Dockorate.app [output.dmg]
#
# The window's background is drawn by scripts/dmg/background.swift. Laying out the window asks
# Finder to arrange it, so the first run may ask to let Terminal control Finder.
set -eu
APP="${1:?Pass the path to Dockorate.app}"
cd "$(dirname "$0")/.."
VERSION=$(/usr/libexec/PlistBuddy -c "Print CFBundleShortVersionString" "$APP/Contents/Info.plist")
DMG="${2:-build/Dockorate-$VERSION.dmg}"
VOLUME="Dockorate $VERSION"
WORK=$(mktemp -d)
trap 'hdiutil detach "/Volumes/$VOLUME" -quiet 2>/dev/null || true; rm -rf "$WORK"' EXIT

echo "Drawing the background…"
mkdir -p "$WORK/stage/.background"
swift scripts/dmg/background.swift "$WORK"
tiffutil -cathidpicheck "$WORK/background.png" "$WORK/background@2x.png" -out "$WORK/stage/.background/background.tiff" 2>/dev/null

ditto "$APP" "$WORK/stage/Dockorate.app"
ln -s /Applications "$WORK/stage/Applications"

echo "Laying out the window…"
hdiutil detach "/Volumes/$VOLUME" -quiet 2>/dev/null || true
hdiutil create -volname "$VOLUME" -srcfolder "$WORK/stage" -fs HFS+ -format UDRW -ov "$WORK/rw.dmg" -quiet
hdiutil attach "$WORK/rw.dmg" -readwrite -noverify -noautoopen -quiet
osascript <<APPLESCRIPT
tell application "Finder"
    tell disk "$VOLUME"
        open
        set current view of container window to icon view
        set toolbar visible of container window to false
        set statusbar visible of container window to false
        set the bounds of container window to {200, 120, 860, 568}
        set viewOptions to the icon view options of container window
        set arrangement of viewOptions to not arranged
        set icon size of viewOptions to 128
        set text size of viewOptions to 13
        set background picture of viewOptions to file ".background:background.tiff"
        set position of item "Dockorate.app" of container window to {170, 215}
        set position of item "Applications" of container window to {490, 215}
        update without registering applications
        delay 1
        close
    end tell
end tell
APPLESCRIPT
# Hide the background folder and keep Finder's layout file.
SetFile -a V "/Volumes/$VOLUME/.background" 2>/dev/null || true
sync
hdiutil detach "/Volumes/$VOLUME" -quiet

echo "Compressing…"
mkdir -p "$(dirname "$DMG")"
hdiutil convert "$WORK/rw.dmg" -format UDZO -imagekey zlib-level=9 -ov -o "$DMG" -quiet
echo "Ready: $DMG"

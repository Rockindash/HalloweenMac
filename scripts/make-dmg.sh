#!/bin/sh
# Wraps Dockorate.app in a fall-themed "drag to Applications" disk image.
#
#   scripts/make-dmg.sh path/to/Dockorate.app [output.dmg]
#
# The window background is scripts/dmg/background.png (+ @2x), drawn with the app's own art
# (generator: page.html in the project's FallDock/version-1/installer folder). Finder lays the window out, so run this on a Mac that's
# logged in (the first run asks to let Terminal control Finder).
set -eu
APP="${1:?Pass the path to Dockorate.app}"
cd "$(dirname "$0")/.."
VERSION=$(/usr/libexec/PlistBuddy -c "Print CFBundleShortVersionString" "$APP/Contents/Info.plist")
BUILD=$(/usr/libexec/PlistBuddy -c "Print CFBundleVersion" "$APP/Contents/Info.plist")
OUT="${2:-build/Dockorate-$VERSION-build$BUILD.dmg}"
VOLUME="Dockorate"
WORK=$(mktemp -d)
trap 'hdiutil detach "/Volumes/$VOLUME" -quiet 2>/dev/null || true; rm -rf "$WORK"' EXIT

mkdir -p "$WORK/stage/.background"
ditto "$APP" "$WORK/stage/Dockorate.app"
ln -s /Applications "$WORK/stage/Applications"
# One file holding both resolutions, so the background is sharp on Retina screens.
tiffutil -cathidpicheck scripts/dmg/background.png scripts/dmg/background@2x.png -out "$WORK/stage/.background/background.tiff" >/dev/null

hdiutil detach "/Volumes/$VOLUME" -quiet 2>/dev/null || true
hdiutil create -volname "$VOLUME" -srcfolder "$WORK/stage" -fs HFS+ -format UDRW -ov "$WORK/rw.dmg" -quiet
hdiutil attach "$WORK/rw.dmg" -mountpoint "/Volumes/$VOLUME" -nobrowse -noautoopen -quiet

osascript <<OSA
tell application "Finder"
  tell disk "$VOLUME"
    open
    set current view of container window to icon view
    set toolbar visible of container window to false
    set statusbar visible of container window to false
    set the bounds of container window to {200, 120, 860, 548}
    set viewOptions to the icon view options of container window
    set arrangement of viewOptions to not arranged
    set icon size of viewOptions to 128
    set text size of viewOptions to 13
    set background picture of viewOptions to file ".background:background.tiff"
    set position of item "Dockorate.app" of container window to {170, 205}
    set position of item "Applications" of container window to {490, 205}
    update without registering applications
    delay 1
    close
  end tell
end tell
OSA

chmod -Rf go-w "/Volumes/$VOLUME" 2>/dev/null || true
sync
hdiutil detach "/Volumes/$VOLUME" -quiet
mkdir -p "$(dirname "$OUT")"
hdiutil convert "$WORK/rw.dmg" -format UDZO -imagekey zlib-level=9 -ov -o "$OUT" -quiet
echo "Made $OUT"

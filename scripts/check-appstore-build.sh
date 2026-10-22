#!/bin/bash
# Builds the Mac App Store version (unsigned) and checks it's fit for the App Store: sandboxed, no
# Sparkle or update feed, the privacy manifest included, no license screen, and that it starts and
# keeps running inside the sandbox. Runs on GitHub with the tests, and before every App Store upload.
#
#   scripts/check-appstore-build.sh
#
set -euo pipefail
cd "$(dirname "$0")/.."
DERIVED=build/appstore-check
rm -rf "$DERIVED"

xcodebuild build -project FallDock.xcodeproj -scheme DockorateAppStore -configuration Release \
    -destination 'platform=macOS' -derivedDataPath "$DERIVED" -quiet \
    CODE_SIGN_IDENTITY=- CODE_SIGN_STYLE=Manual DEVELOPMENT_TEAM=
APP="$DERIVED/Build/Products/Release/Dockorate.app"
PLIST="$APP/Contents/Info.plist"
failures=0
check() {
    local what="$1"; shift
    if "$@" >/dev/null 2>&1; then echo "✓ $what"; else echo "✗ $what"; failures=$((failures + 1)); fi
}
plist_value() { /usr/libexec/PlistBuddy -c "Print $1" "$2"; }

ENTITLEMENTS=$(codesign -d --entitlements :- "$APP" 2>/dev/null || true)
check "runs in the App Sandbox" grep -q "com.apple.security.app-sandbox" <<<"$ENTITLEMENTS"
check "can read the Dock's settings" grep -q "com.apple.dock" <<<"$ENTITLEMENTS"
check "doesn't ask for the network" bash -c '! grep -q "network.client" <<<"$1"' _ "$ENTITLEMENTS"
check "has no Sparkle" test ! -e "$APP/Contents/Frameworks/Sparkle.framework"
check "has no update feed" bash -c '! /usr/libexec/PlistBuddy -c "Print SUFeedURL" "$1"' _ "$PLIST"
check "says it uses no non-exempt encryption" bash -c '[ "$(/usr/libexec/PlistBuddy -c "Print ITSAppUsesNonExemptEncryption" "$1")" = false ]' _ "$PLIST"
check "has the privacy manifest" test -f "$APP/Contents/Resources/PrivacyInfo.xcprivacy"
check "has an app category" plist_value LSApplicationCategoryType "$PLIST"
check "has the app icon" test -f "$APP/Contents/Resources/Assets.car"
check "doesn't mention Gumroad" bash -c '! grep -rqi gumroad "$1/Contents/MacOS"' _ "$APP"

# Starts it (with fresh test settings, and without touching the desktop) and checks it's still
# running a few seconds later, inside its sandbox container.
"$APP/Contents/MacOS/Dockorate" -UITesting -UITestingSkipWelcome >"$DERIVED/launch.log" 2>&1 &
PID=$!
sleep 8
check "starts and keeps running in the sandbox" kill -0 "$PID"
check "has its sandbox container" test -d "$HOME/Library/Containers/com.amol.dockorate"
kill "$PID" 2>/dev/null || true
wait "$PID" 2>/dev/null || true

if [ "$failures" -gt 0 ]; then
    echo "$failures App Store check(s) failed."
    sed -n '1,40p' "$DERIVED/launch.log" || true
    exit 1
fi
echo "The App Store build is good."

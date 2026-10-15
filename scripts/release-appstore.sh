#!/bin/sh
# Builds the Mac App Store version of Dockorate and uploads it to App Store Connect, ready to submit
# for review. See docs/AppStore.md for the one-time setup and what to fill in on App Store Connect.
#
#   TEAM_ID=ABCDE12345 scripts/release-appstore.sh
#
# Xcode signs it with your Apple Distribution certificate and the App Store profile, making them if
# needed (sign in to your Apple account in Xcode → Settings → Accounts first). Each upload needs a new
# build number (target → General → Build), even when the version stays the same.
set -eu
: "${TEAM_ID:?Set TEAM_ID to your Apple Developer Team ID (developer.apple.com → Account → Membership)}"
cd "$(dirname "$0")/.."
OUT=build/appstore
rm -rf "$OUT"
mkdir -p "$OUT"

echo "Checking the App Store build…"
scripts/check-appstore-build.sh

echo "Building and signing for the App Store…"
xcodebuild -project FallDock.xcodeproj -scheme DockorateAppStore -configuration Release \
    -archivePath "$OUT/Dockorate.xcarchive" archive \
    DEVELOPMENT_TEAM="$TEAM_ID" CODE_SIGN_STYLE=Automatic CODE_SIGN_IDENTITY="Apple Development" \
    -allowProvisioningUpdates -quiet
sed "s/TEAM_ID/$TEAM_ID/" scripts/ExportOptions-AppStore.plist > "$OUT/ExportOptions.plist"

echo "Uploading to App Store Connect…"
xcodebuild -exportArchive -archivePath "$OUT/Dockorate.xcarchive" \
    -exportOptionsPlist "$OUT/ExportOptions.plist" -exportPath "$OUT" -allowProvisioningUpdates -quiet
echo "Uploaded. In a few minutes the build shows up in App Store Connect → Dockorate → TestFlight; pick it for the new version and submit for review."

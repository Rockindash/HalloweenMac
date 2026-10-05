#!/bin/sh
# Builds Dockorate for people to download: signed with your Developer ID, notarized by Apple
# and stapled, then zipped for your website. See README → "Releasing" for the one-time setup.
#
#   TEAM_ID=ABCDE12345 scripts/release.sh
#
set -eu
: "${TEAM_ID:?Set TEAM_ID to your Apple Developer Team ID (developer.apple.com → Account → Membership)}"
PROFILE="${NOTARY_PROFILE:-Dockorate}"
cd "$(dirname "$0")/.."
OUT=build/release
rm -rf "$OUT"
mkdir -p "$OUT"

echo "Building and signing…"
xcodebuild -project FallDock.xcodeproj -scheme FallDock -configuration Release \
    -archivePath "$OUT/FallDock.xcarchive" archive \
    DEVELOPMENT_TEAM="$TEAM_ID" CODE_SIGN_STYLE=Manual CODE_SIGN_IDENTITY="Developer ID Application" \
    OTHER_CODE_SIGN_FLAGS="--timestamp" -quiet
sed "s/TEAM_ID/$TEAM_ID/" scripts/ExportOptions.plist > "$OUT/ExportOptions.plist"
xcodebuild -exportArchive -archivePath "$OUT/FallDock.xcarchive" \
    -exportOptionsPlist "$OUT/ExportOptions.plist" -exportPath "$OUT" -quiet
APP="$OUT/Dockorate.app"

echo "Sending to Apple for notarization (this usually takes a few minutes)…"
ditto -c -k --keepParent "$APP" "$OUT/notarize.zip"
xcrun notarytool submit "$OUT/notarize.zip" --keychain-profile "$PROFILE" --wait
xcrun stapler staple "$APP"
rm "$OUT/notarize.zip"

VERSION=$(/usr/libexec/PlistBuddy -c "Print CFBundleShortVersionString" "$APP/Contents/Info.plist")
ditto -c -k --keepParent "$APP" "$OUT/Dockorate-$VERSION.zip"
spctl --assess --type execute --verbose "$APP"
echo "Ready to upload: $OUT/Dockorate-$VERSION.zip"

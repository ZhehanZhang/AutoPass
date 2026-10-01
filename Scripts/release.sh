#!/bin/bash
# Builds a universal AutoPass, signs it with your Developer ID (hardened runtime, secure timestamp), has Apple notarize it,
# staples the ticket and writes dist/AutoPass-<version>.zip.
#
#   AUTOPASS_NOTARY_PROFILE=<profile> Scripts/release.sh
#
# One-time setup, with an app-specific password from appleid.apple.com:
#   xcrun notarytool store-credentials <profile> --apple-id <you@example.com> --team-id <TEAMID>
set -euo pipefail
cd "$(dirname "$0")/.."

PROFILE="${AUTOPASS_NOTARY_PROFILE:-AutoPass}"
APP=build/AutoPass.app
VERSION="$(/usr/libexec/PlistBuddy -c 'Print CFBundleShortVersionString' Resources/Info.plist)"
ZIP="dist/AutoPass-$VERSION.zip"

IDENTITY="${AUTOPASS_SIGN_IDENTITY:-$(security find-identity -v -p codesigning | sed -n 's/.*"\(Developer ID Application:[^"]*\)".*/\1/p' | head -1)}"
if [ -z "$IDENTITY" ] || [ "$IDENTITY" = "-" ]; then
    echo "A Developer ID Application certificate is needed to notarize." >&2
    exit 1
fi

AUTOPASS_SIGN_IDENTITY="$IDENTITY" AUTOPASS_UNIVERSAL=1 AUTOPASS_TIMESTAMP=1 Scripts/build-app.sh

echo "--- signature"
codesign -dvv "$APP" 2>&1 | grep -E 'Authority=Developer ID Application|Timestamp=|flags=' || true
lipo -archs "$APP/Contents/MacOS/AutoPass"

mkdir -p dist
SUBMIT="$(mktemp -d)/AutoPass-submit.zip"
ditto -c -k --keepParent "$APP" "$SUBMIT"

echo "--- notarizing (this usually takes a few minutes)"
RESULT="$(xcrun notarytool submit "$SUBMIT" --keychain-profile "$PROFILE" --wait 2>&1 | tee /dev/stderr)"
ID="$(printf '%s\n' "$RESULT" | sed -n 's/^ *id: *//p' | head -1)"
if ! printf '%s\n' "$RESULT" | grep -q 'status: Accepted'; then
    echo "Notarization did not succeed. Apple's log:" >&2
    [ -n "$ID" ] && xcrun notarytool log "$ID" --keychain-profile "$PROFILE" >&2
    exit 1
fi

echo "--- stapling"
xcrun stapler staple "$APP"
xcrun stapler validate "$APP"
spctl --assess --type execute -vv "$APP"

rm -f "$ZIP"
ditto -c -k --keepParent "$APP" "$ZIP"
shasum -a 256 "$ZIP"
echo "Release ready: $ZIP"

#!/bin/bash
# Builds build/AutoPass.app (hardened runtime, no entitlements) and signs it.
#
#   Scripts/build-app.sh                          # signs with your Developer ID, else Apple Development, else ad hoc
#   AUTOPASS_SIGN_IDENTITY="-" Scripts/build-app.sh   # force ad hoc (Accessibility permission won't survive rebuilds)
#   AUTOPASS_UNIVERSAL=1 Scripts/build-app.sh         # arm64 + x86_64 (Scripts/release.sh does this)
#   AUTOPASS_TIMESTAMP=1 Scripts/build-app.sh         # secure timestamp, which notarization needs
#
# Accessibility permission is tied to the code signature. Sign every build with the same certificate and
# the permission you grant once keeps working across rebuilds.
set -euo pipefail
cd "$(dirname "$0")/.."

CONFIG=release
APP=build/AutoPass.app

ARCH_FLAGS=()
[ -n "${AUTOPASS_UNIVERSAL:-}" ] && ARCH_FLAGS=(--arch arm64 --arch x86_64)
swift build -c "$CONFIG" ${ARCH_FLAGS[@]+"${ARCH_FLAGS[@]}"}
BIN="$(swift build -c "$CONFIG" ${ARCH_FLAGS[@]+"${ARCH_FLAGS[@]}"} --show-bin-path)/AutoPass"

rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
# SwiftPM without Xcode stamps the deployment target (14.0) as the SDK version. macOS decides whether an app gets
# the current design (Liquid Glass switches, glass buttons, ...) from the SDK it was linked against, so stamp the
# real SDK version, as Xcode would. The minimum OS stays 14.0.
SDK_VERSION="$(xcrun --show-sdk-version)"
vtool -set-build-version macos 14.0 "$SDK_VERSION" -replace -output "$APP/Contents/MacOS/AutoPass" "$BIN"
cp Resources/Info.plist "$APP/Contents/Info.plist"
cp Resources/AppIcon.icns "$APP/Contents/Resources/AppIcon.icns"
printf 'APPL????' > "$APP/Contents/PkgInfo"

identity="${AUTOPASS_SIGN_IDENTITY:-}"
if [ -z "$identity" ]; then
    identity=$(security find-identity -v -p codesigning | sed -n 's/.*"\(Developer ID Application:[^"]*\)".*/\1/p' | head -1)
fi
if [ -z "$identity" ]; then
    identity=$(security find-identity -v -p codesigning | sed -n 's/.*"\(Apple Development:[^"]*\)".*/\1/p' | head -1)
fi
if [ -z "$identity" ]; then
    identity="-"
fi
echo "Signing with: $identity"

timestamp="--timestamp=none"
[ -n "${AUTOPASS_TIMESTAMP:-}" ] && timestamp="--timestamp"

# Hardened runtime, and deliberately no entitlements: no debugger attach, no DYLD injection,
# no unsigned-library loading.
codesign --force --options runtime $timestamp --sign "$identity" "$APP"

codesign --verify --strict --verbose=2 "$APP"
echo "--- flags / entitlements"
codesign -dv "$APP" 2>&1 | grep -E 'Identifier|flags|TeamIdentifier|Authority' || true
if codesign -d --entitlements - "$APP" 2>&1 | grep -q '<key>'; then
    echo "ERROR: unexpected entitlements present" >&2; exit 1
fi
echo "No entitlements (expected)."
vtool -show-build "$APP/Contents/MacOS/AutoPass" | grep -E 'minos|sdk' | tr -s ' ' | tr '\n' ' '; echo
echo "Built $APP"

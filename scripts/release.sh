#!/bin/sh
# Builds a release zip of the app in ./build, ready to attach to a GitHub release.
#
# Unsigned by default (ad-hoc signature): users open it once with right-click › Open.
# To sign and notarize, set:
#   DEVELOPER_ID="Developer ID Application: Your Name (TEAMID)"
#   NOTARY_PROFILE=<keychain profile from `xcrun notarytool store-credentials`>
set -e
cd "$(dirname "$0")/.."
scripts/build-app.sh
APP=build/KiyoControl.app
VERSION=$(/usr/libexec/PlistBuddy -c "Print CFBundleShortVersionString" "$APP/Contents/Info.plist")
ZIP=build/KiyoControl-$VERSION.zip

if [ -n "$DEVELOPER_ID" ]; then
    codesign --force --options runtime --timestamp --sign "$DEVELOPER_ID" "$APP"
fi
rm -f "$ZIP"
ditto -c -k --keepParent "$APP" "$ZIP"
if [ -n "$DEVELOPER_ID" ] && [ -n "$NOTARY_PROFILE" ]; then
    xcrun notarytool submit "$ZIP" --keychain-profile "$NOTARY_PROFILE" --wait
    xcrun stapler staple "$APP"
    rm -f "$ZIP"
    ditto -c -k --keepParent "$APP" "$ZIP"
fi
echo "Release: $ZIP"
echo "sha256:  $(shasum -a 256 "$ZIP" | cut -d' ' -f1)"

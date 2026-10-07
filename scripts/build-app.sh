#!/bin/sh
# Builds KiyoControl.app (release) into ./build. The bundle is needed for the camera permission prompt.
set -e
# The Command Line Tools SDK lags behind macOS; prefer Xcode when present.
[ -d /Applications/Xcode.app ] && export DEVELOPER_DIR="${DEVELOPER_DIR:-/Applications/Xcode.app/Contents/Developer}"
cd "$(dirname "$0")/.."


swift build -c release --product KiyoControl
APP=build/KiyoControl.app
rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
cp .build/release/KiyoControl "$APP/Contents/MacOS/"
cp Resources/AppIcon.icns "$APP/Contents/Resources/"
cat > "$APP/Contents/Info.plist" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleExecutable</key><string>KiyoControl</string>
    <key>CFBundleIdentifier</key><string>io.github.kiyocontrol</string>
    <key>CFBundleName</key><string>Kiyo Control</string>
    <key>CFBundleIconFile</key><string>AppIcon</string>
    <key>CFBundlePackageType</key><string>APPL</string>
    <key>CFBundleShortVersionString</key><string>0.2.0</string>
    <key>CFBundleVersion</key><string>2</string>
    <key>LSMinimumSystemVersion</key><string>15.0</string>
    <key>NSHighResolutionCapable</key><true/>
    <key>NSCameraUsageDescription</key><string>Shows a live preview so you can judge settings before saving them.</string>
</dict>
</plist>
PLIST
codesign --force --sign - "$APP"
echo "Built $APP"

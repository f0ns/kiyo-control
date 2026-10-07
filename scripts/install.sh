#!/bin/sh
# Installs (or updates) Kiyo Control into /Applications from the latest GitHub release.
# usage: curl -fsSL https://raw.githubusercontent.com/REPO_SLUG/main/scripts/install.sh | sh
set -e
REPO="${KIYO_REPO:-REPO_SLUG}"
DEST="${KIYO_INSTALL_DIR:-/Applications}"
TMP=$(mktemp -d)
trap 'rm -rf "$TMP"' EXIT

if [ -n "$KIYO_ZIP_URL" ]; then
    URL="$KIYO_ZIP_URL"
else
    echo "Looking up the latest release…"
    URL=$(curl -fsSL "https://api.github.com/repos/$REPO/releases/latest" \
        | grep -o '"browser_download_url": *"[^"]*\.zip"' | head -1 | sed 's/.*"\(http[^"]*\)"/\1/')
    [ -n "$URL" ] || { echo "Could not find a release download."; exit 1; }
fi

echo "Downloading Kiyo Control…"
curl -fsSL "$URL" -o "$TMP/KiyoControl.zip"
ditto -x -k "$TMP/KiyoControl.zip" "$TMP"

# Quit a running copy before replacing it.
osascript -e 'tell application id "io.github.kiyocontrol" to quit' >/dev/null 2>&1 || true
rm -rf "$DEST/KiyoControl.app"
mv "$TMP/KiyoControl.app" "$DEST/"
xattr -dr com.apple.quarantine "$DEST/KiyoControl.app" 2>/dev/null || true

echo "Installed in $DEST. Opening Kiyo Control…"
open "$DEST/KiyoControl.app"

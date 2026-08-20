#!/bin/zsh
set -euo pipefail

PROJECT_DIR="${0:A:h:h}"
VERSION="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' "$PROJECT_DIR/Support/Info.plist")"
ARCH="$(uname -m)"
RELEASE_DIR="$PROJECT_DIR/release"
DMG_NAME="Herdr-for-Mac-$VERSION-$ARCH.dmg"
DMG_PATH="$RELEASE_DIR/$DMG_NAME"
STAGING_DIR="$(mktemp -d "${TMPDIR:-/tmp}/herdr-dmg.XXXXXX")"

cleanup() {
    rm -rf "$STAGING_DIR"
}
trap cleanup EXIT

"$PROJECT_DIR/scripts/build-app.sh"

mkdir -p "$RELEASE_DIR"
ditto "$PROJECT_DIR/dist/Herdr.app" "$STAGING_DIR/Herdr.app"
ln -s /Applications "$STAGING_DIR/Applications"

rm -f "$DMG_PATH" "$DMG_PATH.sha256"
hdiutil create \
    -volname "Herdr" \
    -srcfolder "$STAGING_DIR" \
    -format UDZO \
    -imagekey zlib-level=9 \
    "$DMG_PATH"
codesign --force --sign - "$DMG_PATH"

(
    cd "$RELEASE_DIR"
    shasum -a 256 "$DMG_NAME" > "$DMG_NAME.sha256"
)

echo "$DMG_PATH"
echo "$DMG_PATH.sha256"

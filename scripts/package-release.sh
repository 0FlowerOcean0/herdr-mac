#!/bin/zsh
set -euo pipefail

PROJECT_DIR="${0:A:h:h}"
VERSION="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' "$PROJECT_DIR/Support/Info.plist")"
ARCH="$(uname -m)"
RELEASE_DIR="$PROJECT_DIR/release"
ARCHIVE="$RELEASE_DIR/Herdr-for-Mac-$VERSION-$ARCH.zip"

"$PROJECT_DIR/scripts/build-app.sh"

mkdir -p "$RELEASE_DIR"
rm -f "$ARCHIVE" "$ARCHIVE.sha256"
ditto -c -k --sequesterRsrc --keepParent "$PROJECT_DIR/dist/Herdr.app" "$ARCHIVE"
(
    cd "$RELEASE_DIR"
    shasum -a 256 "${ARCHIVE:t}" > "${ARCHIVE:t}.sha256"
)

echo "$ARCHIVE"
echo "$ARCHIVE.sha256"

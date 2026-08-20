#!/bin/zsh
set -euo pipefail

PROJECT_DIR="${0:A:h:h}"
cd "$PROJECT_DIR"

swift test
swift build -c release

BIN_DIR="$(swift build -c release --show-bin-path)"
APP_DIR="$PROJECT_DIR/dist/Herdr.app"
CONTENTS_DIR="$APP_DIR/Contents"

rm -rf "$APP_DIR"
mkdir -p "$CONTENTS_DIR/MacOS" "$CONTENTS_DIR/Resources"
cp "$BIN_DIR/HerdrMac" "$CONTENTS_DIR/MacOS/HerdrMac"
cp "$PROJECT_DIR/Support/Info.plist" "$CONTENTS_DIR/Info.plist"
if [[ -d "$BIN_DIR/SwiftTerm_SwiftTerm.bundle" ]]; then
  cp -R "$BIN_DIR/SwiftTerm_SwiftTerm.bundle" "$CONTENTS_DIR/Resources/SwiftTerm_SwiftTerm.bundle"
fi
if [[ -f "$PROJECT_DIR/Resources/AppIcon.icns" ]]; then
  cp "$PROJECT_DIR/Resources/AppIcon.icns" "$CONTENTS_DIR/Resources/AppIcon.icns"
fi
if [[ -f "$PROJECT_DIR/Sources/HerdrMac/Resources/HerdrLogoMark.svg" ]]; then
  cp "$PROJECT_DIR/Sources/HerdrMac/Resources/HerdrLogoMark.svg" "$CONTENTS_DIR/Resources/HerdrLogoMark.svg"
fi

codesign --force --deep --sign - "$APP_DIR"
echo "$APP_DIR"

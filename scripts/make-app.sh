#!/bin/bash
# Assembles dist/HeatPeek.app from a release build and ad-hoc signs it.
set -euo pipefail

cd "$(dirname "$0")/.."

BIN=$(swift build -c release --show-bin-path)
SRC="$BIN/heatpeek"
APP=dist/HeatPeek.app

if [ ! -x "$SRC" ]; then
  echo "heatpeek: release binary not found at $SRC — run 'swift build -c release' first" >&2
  exit 1
fi

rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
cp Support/Info.plist "$APP/Contents/Info.plist"
cp "$SRC" "$APP/Contents/MacOS/heatpeek"
printf 'APPL????' > "$APP/Contents/PkgInfo"

# Ad-hoc signature: a free Apple ID cannot issue Developer ID, so there is nothing to notarize.
codesign --force --sign - "$APP" 2> /dev/null
codesign --verify --verbose=2 "$APP"

echo "built $APP"
echo "ad-hoc signed; first launch may need: xattr -dr com.apple.quarantine $APP"

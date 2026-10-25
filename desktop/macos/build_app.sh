#!/bin/bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "$SCRIPT_DIR/../.." && pwd)"
PACKAGE_DIR="$SCRIPT_DIR/ScrcpyStudio"
SCRCPY_DIST="$ROOT_DIR/release/work/build-macos-aarch64/dist"
OUTPUT_DIR="$ROOT_DIR/release/output"
APP_PATH="$OUTPUT_DIR/Scrcpy Studio.app"

if [[ ! -x "$SCRCPY_DIST/scrcpy" || ! -f "$SCRCPY_DIST/scrcpy-server" ]]; then
    echo "Build the macOS scrcpy client and Android server first." >&2
    exit 1
fi

/usr/bin/swift build --package-path "$PACKAGE_DIR" -c release --arch arm64
BIN_DIR="$(/usr/bin/swift build --package-path "$PACKAGE_DIR" -c release --arch arm64 --show-bin-path)"

rm -rf "$APP_PATH"
mkdir -p "$APP_PATH/Contents/MacOS" "$APP_PATH/Contents/Resources/scrcpy"
cp "$BIN_DIR/ScrcpyStudio" "$APP_PATH/Contents/MacOS/"
cp "$PACKAGE_DIR/Info.plist" "$APP_PATH/Contents/"
cp -R "$SCRCPY_DIST/". "$APP_PATH/Contents/Resources/scrcpy/"
printf 'APPL????' > "$APP_PATH/Contents/PkgInfo"
codesign --force --deep --sign - "$APP_PATH"

echo "$APP_PATH"

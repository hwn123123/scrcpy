#!/bin/bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "$SCRIPT_DIR/../.." && pwd)"
PACKAGE_DIR="$SCRIPT_DIR/ScrcpyStudio"
SCRCPY_DIST="$ROOT_DIR/release/work/build-macos-aarch64/dist"
OUTPUT_DIR="$ROOT_DIR/release/output"
APP_PATH="$OUTPUT_DIR/Scrcpy Studio.app"
ICON_MASTER="$PACKAGE_DIR/Assets/AppIcon-master.png"
ICONSET_DIR="$PACKAGE_DIR/.build/AppIcon.iconset"

if [[ ! -x "$SCRCPY_DIST/scrcpy" || ! -f "$SCRCPY_DIST/scrcpy-server" ]]; then
    echo "Build the macOS scrcpy client and Android server first." >&2
    exit 1
fi

/usr/bin/swift build --package-path "$PACKAGE_DIR" -c release --arch arm64
BIN_DIR="$(/usr/bin/swift build --package-path "$PACKAGE_DIR" -c release --arch arm64 --show-bin-path)"

if [[ ! -f "$ICON_MASTER" ]]; then
    echo "Missing app icon master: $ICON_MASTER" >&2
    exit 1
fi

rm -rf "$ICONSET_DIR"
mkdir -p "$ICONSET_DIR"
sips -z 16 16 "$ICON_MASTER" --out "$ICONSET_DIR/icon_16x16.png" >/dev/null
sips -z 32 32 "$ICON_MASTER" --out "$ICONSET_DIR/icon_16x16@2x.png" >/dev/null
sips -z 32 32 "$ICON_MASTER" --out "$ICONSET_DIR/icon_32x32.png" >/dev/null
sips -z 64 64 "$ICON_MASTER" --out "$ICONSET_DIR/icon_32x32@2x.png" >/dev/null
sips -z 128 128 "$ICON_MASTER" --out "$ICONSET_DIR/icon_128x128.png" >/dev/null
sips -z 256 256 "$ICON_MASTER" --out "$ICONSET_DIR/icon_128x128@2x.png" >/dev/null
sips -z 256 256 "$ICON_MASTER" --out "$ICONSET_DIR/icon_256x256.png" >/dev/null
sips -z 512 512 "$ICON_MASTER" --out "$ICONSET_DIR/icon_256x256@2x.png" >/dev/null
sips -z 512 512 "$ICON_MASTER" --out "$ICONSET_DIR/icon_512x512.png" >/dev/null
cp "$ICON_MASTER" "$ICONSET_DIR/icon_512x512@2x.png"
iconutil -c icns "$ICONSET_DIR" -o "$PACKAGE_DIR/.build/AppIcon.icns"

rm -rf "$APP_PATH"
mkdir -p "$APP_PATH/Contents/MacOS" "$APP_PATH/Contents/Resources/scrcpy"
cp "$BIN_DIR/ScrcpyStudio" "$APP_PATH/Contents/MacOS/"
cp "$PACKAGE_DIR/Info.plist" "$APP_PATH/Contents/"
cp "$PACKAGE_DIR/.build/AppIcon.icns" "$APP_PATH/Contents/Resources/"
cp -R "$SCRCPY_DIST/". "$APP_PATH/Contents/Resources/scrcpy/"
printf 'APPL????' > "$APP_PATH/Contents/PkgInfo"
codesign --force --deep --sign - "$APP_PATH"

echo "$APP_PATH"

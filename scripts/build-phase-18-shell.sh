#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
PACKAGE_DIR="$ROOT_DIR/macos/BlendZigShell"
APP_PATH="${1:-$ROOT_DIR/zig-out/BlendZigShell.app}"
APP_NAME="BlendZigShell"
HELPER_BIN="${BLENDER_ZIG_BIN:-$ROOT_DIR/zig-out/bin/blender-zig-direct}"

cd "$ROOT_DIR"

if [[ ! -x "$HELPER_BIN" ]]; then
  bash scripts/verify-local.sh "$HELPER_BIN"
fi

swift build --package-path "$PACKAGE_DIR" -c release --product "$APP_NAME" >/dev/null
APP_BIN_DIR="$(swift build --package-path "$PACKAGE_DIR" -c release --show-bin-path)"
APP_EXECUTABLE="$APP_BIN_DIR/$APP_NAME"

rm -rf "$APP_PATH"
mkdir -p "$APP_PATH/Contents/MacOS" "$APP_PATH/Contents/Resources"

cp "$PACKAGE_DIR/Info.plist" "$APP_PATH/Contents/Info.plist"
cp "$APP_EXECUTABLE" "$APP_PATH/Contents/MacOS/$APP_NAME"
cp "$HELPER_BIN" "$APP_PATH/Contents/MacOS/blender-zig-direct"
chmod +x "$APP_PATH/Contents/MacOS/$APP_NAME" "$APP_PATH/Contents/MacOS/blender-zig-direct"

printf 'app_bundle=%s\n' "$APP_PATH"

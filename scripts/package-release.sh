#!/usr/bin/env bash
set -euo pipefail

ROOT="$(git rev-parse --show-toplevel 2>/dev/null || pwd)"
VERSION="${1:-$(git -C "$ROOT" rev-parse --short HEAD 2>/dev/null || printf 'dev')}"
VERIFY_BEFORE_DIST="${VERIFY_BEFORE_DIST:-1}"
CODESIGN_IDENTITY="${CODESIGN_IDENTITY:-${APPLE_DEVELOPER_IDENTITY:-}}"
APPLE_NOTARY_PROFILE="${APPLE_NOTARY_PROFILE:-}"

normalize_os() {
  case "$(uname -s)" in
    Darwin) printf 'macos' ;;
    Linux) printf 'linux' ;;
    *) printf 'unknown' ;;
  esac
}

normalize_arch() {
  case "$(uname -m)" in
    arm64|aarch64) printf 'arm64' ;;
    x86_64|amd64) printf 'x86_64' ;;
    *) printf 'unknown' ;;
  esac
}

OS_NAME="$(normalize_os)"
ARCH_NAME="$(normalize_arch)"
ARTIFACT_NAME="blender-zig-${VERSION}-${OS_NAME}-${ARCH_NAME}"
ARTIFACT_DIR="$ROOT/dist/$ARTIFACT_NAME"
ARCHIVE_PATH="$ROOT/dist/${ARTIFACT_NAME}.tar.gz"

cd "$ROOT"
if [[ "$VERIFY_BEFORE_DIST" -eq 1 ]]; then
  zig build test
fi
zig build -Doptimize=ReleaseFast

rm -rf "$ARTIFACT_DIR"
mkdir -p "$ARTIFACT_DIR"

cp "$ROOT/zig-out/bin/blender-zig" "$ARTIFACT_DIR/"
cp "$ROOT/README.md" "$ARTIFACT_DIR/"
cp "$ROOT/NOTICE.md" "$ARTIFACT_DIR/"

if [[ "$OS_NAME" == "macos" && -n "$CODESIGN_IDENTITY" ]]; then
  # Signing stays opt-in so local packaging still works on machines without Apple credentials.
  codesign --force --sign "$CODESIGN_IDENTITY" --options runtime --timestamp "$ARTIFACT_DIR/blender-zig"
fi

if [[ "$OS_NAME" == "macos" ]]; then
  ARCHIVE_PATH="$ROOT/dist/${ARTIFACT_NAME}.zip"
  ditto -c -k --keepParent "$ARTIFACT_DIR" "$ARCHIVE_PATH"
else
  tar -czf "$ARCHIVE_PATH" -C "$ROOT/dist" "$ARTIFACT_NAME"
fi

if [[ "$OS_NAME" == "macos" && -n "$APPLE_NOTARY_PROFILE" ]]; then
  if ! command -v xcrun >/dev/null 2>&1; then
    printf 'xcrun is required for notarization submission.\n' >&2
    exit 1
  fi
  xcrun notarytool submit "$ARCHIVE_PATH" --keychain-profile "$APPLE_NOTARY_PROFILE" --wait
fi

if command -v shasum >/dev/null 2>&1; then
  shasum -a 256 "$ARCHIVE_PATH" >"${ARCHIVE_PATH}.sha256"
elif command -v sha256sum >/dev/null 2>&1; then
  sha256sum "$ARCHIVE_PATH" >"${ARCHIVE_PATH}.sha256"
fi

printf 'artifact=%s\n' "$ARCHIVE_PATH"

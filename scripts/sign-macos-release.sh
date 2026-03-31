#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat <<'EOF'
Usage: bash scripts/sign-macos-release.sh <path> [identity]

Environment fallback:
  APPLE_DEVELOPER_IDENTITY
EOF
}

if [[ $# -lt 1 ]]; then
  usage >&2
  exit 1
fi

if [[ "$(uname -s)" != "Darwin" ]]; then
  printf 'macOS signing is only available on Darwin hosts.\n' >&2
  exit 1
fi

TARGET_PATH="$1"
IDENTITY="${2:-${APPLE_DEVELOPER_IDENTITY:-}}"

if [[ -z "$IDENTITY" ]]; then
  printf 'Missing signing identity. Pass one explicitly or set APPLE_DEVELOPER_IDENTITY.\n' >&2
  exit 1
fi

codesign --force --timestamp --options runtime --sign "$IDENTITY" "$TARGET_PATH"
codesign --verify --deep --strict --verbose=2 "$TARGET_PATH"

if command -v spctl >/dev/null 2>&1; then
  spctl -a -t exec -vv "$TARGET_PATH" || true
fi

printf 'signed=%s\nidentity=%s\n' "$TARGET_PATH" "$IDENTITY"

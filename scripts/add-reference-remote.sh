#!/usr/bin/env bash
set -euo pipefail

ROOT="$(git rev-parse --show-toplevel 2>/dev/null || pwd)"
REMOTE_NAME="${1:-blender-reference}"
REMOTE_URL="${2:-https://github.com/stussysenik/blender.git}"
REMOTE_BRANCH="${3:-main}"

if git -C "$ROOT" remote get-url "$REMOTE_NAME" >/dev/null 2>&1; then
  git -C "$ROOT" remote set-url "$REMOTE_NAME" "$REMOTE_URL"
else
  git -C "$ROOT" remote add "$REMOTE_NAME" "$REMOTE_URL"
fi

git -C "$ROOT" fetch --depth=1 "$REMOTE_NAME" "$REMOTE_BRANCH"

printf 'remote=%s\nurl=%s\nbranch=%s\n' "$REMOTE_NAME" "$REMOTE_URL" "$REMOTE_BRANCH"

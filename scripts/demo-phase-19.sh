#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
APP_PATH="${BLENDER_ZIG_SHELL_APP:-$ROOT_DIR/zig-out/BlendZigShell.app}"
DEMO_FILE="${1:-$ROOT_DIR/recipes/phase-19/viewport-gallery.bzscene}"

cd "$ROOT_DIR"

bash scripts/build-phase-18-shell.sh "$APP_PATH" >/dev/null

cat <<EOF
Launching the phase-19 viewport demo on macOS.

Demo file:
  $DEMO_FILE

Manual viewport checklist:
  - create: choose "New Primitive" and save a starter `.bzrecipe`
  - focus: select one object or scene part in the "Object Focus" panel
  - orbit: click-drag in the viewport
  - pan: secondary-drag or two-finger drag
  - zoom: scroll or pinch
  - reset: click "Reset Camera" in the shell
EOF

open -a "$APP_PATH" "$DEMO_FILE"

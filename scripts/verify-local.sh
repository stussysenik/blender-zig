#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
BIN_PATH="${1:-$ROOT_DIR/zig-out/bin/blender-zig-direct}"

pick_target() {
  if [[ -n "${BLENDER_ZIG_TARGET:-}" ]]; then
    printf '%s\n' "$BLENDER_ZIG_TARGET"
    return
  fi

  # Homebrew Zig 0.15.2 currently mislinks its native build runner against the
  # macOS 26 host target on this machine. Pin a lower deployment target for the
  # direct compile path so local verification stays usable.
  if [[ "$(uname -s)" == "Darwin" && "$(uname -m)" == "arm64" ]]; then
    printf 'aarch64-macos.15.0\n'
    return
  fi

  printf '\n'
}

TARGET="$(pick_target)"

cd "$ROOT_DIR"
mkdir -p "$(dirname "$BIN_PATH")"

if [[ -n "$TARGET" ]]; then
  zig test -target "$TARGET" src/lib.zig
  zig test -target "$TARGET" --dep blendzig -Mroot=src/main.zig -Mblendzig=src/lib.zig
  zig build-exe -target "$TARGET" --dep blendzig -Mroot=src/main.zig -Mblendzig=src/lib.zig -femit-bin="$BIN_PATH"
else
  zig test src/lib.zig
  zig test --dep blendzig -Mroot=src/main.zig -Mblendzig=src/lib.zig
  zig build-exe --dep blendzig -Mroot=src/main.zig -Mblendzig=src/lib.zig -femit-bin="$BIN_PATH"
fi

printf 'verified_local_bin=%s\n' "$BIN_PATH"

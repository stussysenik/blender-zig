#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
BIN_PATH="${BLENDER_ZIG_BIN:-$ROOT_DIR/zig-out/bin/blender-zig-direct}"

cd "$ROOT_DIR"

bash scripts/verify-local.sh "$BIN_PATH"
"$BIN_PATH" mesh-delete-edge zig-out/mesh-delete-edge.obj
"$BIN_PATH" mesh-pipeline --recipe recipes/phase-16/wire-cleanup.bzrecipe
"$BIN_PATH" mesh-pipeline --recipe recipes/phase-16/wire-rebuild.bzrecipe
"$BIN_PATH" mesh-pipeline --recipe recipes/phase-16/panel-lift.bzrecipe
"$BIN_PATH" mesh-pipeline --recipe recipes/phase-16/chamfer-recovery.bzrecipe
"$BIN_PATH" mesh-scene --recipe recipes/phase-16/modeling-bench.bzscene
npm run status:update
npm run status:check
npm run status:live
bash scripts/ralph-loop.sh --task-file tasks/phase-16.md --role architect --dry-run --once
bash scripts/team-loop.sh --task-file tasks/phase-16.md --dry-run

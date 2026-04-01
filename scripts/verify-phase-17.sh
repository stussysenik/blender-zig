#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
BIN_PATH="${BLENDER_ZIG_BIN:-$ROOT_DIR/zig-out/bin/blender-zig-direct}"

cd "$ROOT_DIR"

bash scripts/verify-local.sh "$BIN_PATH"
"$BIN_PATH" mesh-pipeline --recipe recipes/phase-16/wire-rebuild.bzrecipe --write zig-out/phase-17-wire-rebuild.obj
"$BIN_PATH" mesh-scene --recipe recipes/phase-16/modeling-bench.bzscene --write zig-out/phase-17-modeling-bench.obj
"$BIN_PATH" mesh-import zig-out/phase-17-modeling-bench.obj zig-out/phase-17-modeling-bench-roundtrip.obj
"$BIN_PATH" mesh-pipeline --recipe recipes/phase-17/pocket-platform-study.bzrecipe
"$BIN_PATH" mesh-pipeline --recipe recipes/phase-17/rail-bevel-study.bzrecipe
"$BIN_PATH" mesh-scene --recipe recipes/phase-17/persistence-workbench.bzscene --write zig-out/phase-17-persistence-workbench.obj
"$BIN_PATH" mesh-import zig-out/phase-17-persistence-workbench.obj zig-out/phase-17-persistence-workbench-roundtrip.obj
"$BIN_PATH" sphere zig-out/phase-17-bundle-mesh.obj
"$BIN_PATH" mesh-roundtrip zig-out/phase-17-bundle-curves.obj
"$BIN_PATH" mesh-edges zig-out/phase-17-bundle-mixed.obj
"$BIN_PATH" geometry-bundle-pack zig-out/phase-17-bundle-mesh.obj zig-out/phase-17-bundle-mesh.bzbundle
"$BIN_PATH" geometry-bundle-pack zig-out/phase-17-bundle-curves.obj zig-out/phase-17-bundle-curves.bzbundle
"$BIN_PATH" geometry-bundle-pack zig-out/phase-17-bundle-mixed.obj zig-out/phase-17-bundle-mixed.bzbundle
"$BIN_PATH" geometry-bundle-open zig-out/phase-17-bundle-mesh.bzbundle zig-out/phase-17-bundle-mesh-roundtrip.obj
"$BIN_PATH" geometry-bundle-open zig-out/phase-17-bundle-curves.bzbundle zig-out/phase-17-bundle-curves-roundtrip.obj
"$BIN_PATH" geometry-bundle-open zig-out/phase-17-bundle-mixed.bzbundle zig-out/phase-17-bundle-mixed-roundtrip.obj
"$BIN_PATH" geometry-bundle-pack zig-out/phase-17-persistence-workbench.obj zig-out/phase-17-persistence-workbench.bzbundle
"$BIN_PATH" geometry-bundle-open zig-out/phase-17-persistence-workbench.bzbundle zig-out/phase-17-persistence-workbench-bundle-roundtrip.obj
"$BIN_PATH" mesh-import zig-out/phase-17-bundle-mesh-roundtrip.obj zig-out/phase-17-bundle-mesh-reimport.obj
"$BIN_PATH" geometry-import zig-out/phase-17-bundle-curves-roundtrip.obj zig-out/phase-17-bundle-curves-reimport.obj
"$BIN_PATH" geometry-import zig-out/phase-17-bundle-mixed-roundtrip.obj zig-out/phase-17-bundle-mixed-reimport.obj
"$BIN_PATH" mesh-import zig-out/phase-17-persistence-workbench-bundle-roundtrip.obj zig-out/phase-17-persistence-workbench-bundle-reimport.obj

mkdir -p zig-out
missing_scene_path="zig-out/phase-17-missing-part.bzscene"
missing_scene_stderr="zig-out/phase-17-missing-part.stderr"
printf 'part=missing.obj\n' > "$missing_scene_path"
if "$BIN_PATH" mesh-scene --recipe "$missing_scene_path" >/dev/null 2>"$missing_scene_stderr"; then
  printf 'expected mesh-scene to fail when a scene part is missing\n' >&2
  exit 1
fi
grep -q "scene part file is missing" "$missing_scene_stderr"
rm -f "$missing_scene_path" "$missing_scene_stderr"

npm run status:update
npm run status:check
npm run status:live
bash scripts/ralph-loop.sh --task-file tasks/phase-17.md --role architect --dry-run --once
bash scripts/team-loop.sh --task-file tasks/phase-17.md --dry-run

if [[ "${BLENDER_ZIG_SKIP_CLEAN_ROOM:-0}" != "1" ]]; then
  bash scripts/verify-clean-room.sh
fi

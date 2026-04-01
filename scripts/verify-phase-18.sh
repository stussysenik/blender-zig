#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
APP_PATH="${BLENDER_ZIG_SHELL_APP:-$ROOT_DIR/zig-out/BlendZigShell.app}"
APP_BIN="$APP_PATH/Contents/MacOS/BlendZigShell"
HELPER_BIN="${BLENDER_ZIG_BIN:-$ROOT_DIR/zig-out/bin/blender-zig-direct}"
SMOKE_DIR="$ROOT_DIR/zig-out/phase-18-shell-smoke"

cd "$ROOT_DIR"

bash scripts/verify-local.sh "$HELPER_BIN"
swift test --package-path macos/BlendZigShell
bash scripts/build-phase-18-shell.sh "$APP_PATH"

rm -rf "$SMOKE_DIR"
mkdir -p "$SMOKE_DIR"
cp recipes/phase-17/pocket-platform-study.bzrecipe "$SMOKE_DIR/pocket-platform-study.bzrecipe"
cp recipes/phase-17/pocket-platform-study.bzrecipe "$SMOKE_DIR/pocket-platform-conflict.bzrecipe"
cp recipes/phase-17/persistence-workbench.bzscene "$SMOKE_DIR/persistence-workbench.bzscene"
cp recipes/phase-17/reference-plate.obj "$SMOKE_DIR/reference-plate.obj"
cp recipes/phase-17/pocket-platform-study.bzrecipe "$SMOKE_DIR/pocket-platform-study.scene-copy.bzrecipe"
cp recipes/phase-17/rail-bevel-study.bzrecipe "$SMOKE_DIR/rail-bevel-study.bzrecipe"
perl -0pi -e 's/part=pocket-platform-study\.bzrecipe/part=pocket-platform-study.scene-copy.bzrecipe/' "$SMOKE_DIR/persistence-workbench.bzscene"

recipe_inspect="$("$APP_BIN" --smoke-inspect "$SMOKE_DIR/pocket-platform-study.bzrecipe")"
printf '%s\n' "$recipe_inspect"
grep -q "inspect kind=recipe" <<<"$recipe_inspect"
grep -q "summary=seed=grid:verts-x=4,verts-y=3,size-x=4.5,size-y=2.8,uvs=true steps=4" <<<"$recipe_inspect"

recipe_save_output="$("$APP_BIN" --smoke-save-title "$SMOKE_DIR/pocket-platform-study.bzrecipe" "Phase 18 Saved Pocket Platform")"
printf '%s\n' "$recipe_save_output"
grep -q "title=Phase 18 Saved Pocket Platform" <<<"$recipe_save_output"
grep -q "replay kind=recipe format-version=1 id=phase-17/pocket-platform title=Phase 18 Saved Pocket Platform" <<<"$recipe_save_output"

if "$APP_BIN" --smoke-save-title-conflict "$SMOKE_DIR/pocket-platform-conflict.bzrecipe" "Phase 18 External Pocket Platform" "Phase 18 Lost Update" >/tmp/blender-zig-phase18-conflict-save.out 2>&1; then
  printf 'expected conflicting title save to fail in the current slice\n' >&2
  exit 1
fi
grep -q "changed on disk since it was opened" /tmp/blender-zig-phase18-conflict-save.out
rm -f /tmp/blender-zig-phase18-conflict-save.out

recipe_output="$("$APP_BIN" --smoke-open "$ROOT_DIR/recipes/phase-17/pocket-platform-study.bzrecipe")"
printf '%s\n' "$recipe_output"
grep -q "replay kind=recipe" <<<"$recipe_output"

scene_save_output="$("$APP_BIN" --smoke-save-title "$SMOKE_DIR/persistence-workbench.bzscene" "Phase 18 Saved Persistence Workbench")"
printf '%s\n' "$scene_save_output"
grep -q "title=Phase 18 Saved Persistence Workbench" <<<"$scene_save_output"
grep -q "replay kind=scene format-version=1 id=phase-17/persistence-workbench title=Phase 18 Saved Persistence Workbench" <<<"$scene_save_output"

scene_output="$("$APP_BIN" --smoke-open "$ROOT_DIR/recipes/phase-17/persistence-workbench.bzscene")"
printf '%s\n' "$scene_output"
grep -q "replay kind=scene" <<<"$scene_output"

"$HELPER_BIN" mesh-scene --recipe recipes/phase-17/persistence-workbench.bzscene --write zig-out/phase-18-persistence-workbench.obj
"$HELPER_BIN" geometry-bundle-pack zig-out/phase-18-persistence-workbench.obj zig-out/phase-18-persistence-workbench.bzbundle

bundle_inspect="$("$APP_BIN" --smoke-inspect "$ROOT_DIR/zig-out/phase-18-persistence-workbench.bzbundle")"
printf '%s\n' "$bundle_inspect"
grep -q "inspect kind=bundle" <<<"$bundle_inspect"
grep -q "editable=false" <<<"$bundle_inspect"

if "$APP_BIN" --smoke-save-title "$ROOT_DIR/zig-out/phase-18-persistence-workbench.bzbundle" "Nope" >/tmp/blender-zig-phase18-bundle-save.out 2>&1; then
  printf 'expected bundle title save to fail in the current slice\n' >&2
  exit 1
fi
grep -q "inspect-only" /tmp/blender-zig-phase18-bundle-save.out
rm -f /tmp/blender-zig-phase18-bundle-save.out

bundle_output="$("$APP_BIN" --smoke-open "$ROOT_DIR/zig-out/phase-18-persistence-workbench.bzbundle")"
printf '%s\n' "$bundle_output"
grep -q "replay kind=bundle" <<<"$bundle_output"

npm run status:update
npm run status:check
npm run status:live
bash scripts/ralph-loop.sh --task-file tasks/phase-18.md --role architect --dry-run --once
bash scripts/team-loop.sh --task-file tasks/phase-18.md --dry-run

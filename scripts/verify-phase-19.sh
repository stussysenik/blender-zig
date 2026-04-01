#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
APP_PATH="${BLENDER_ZIG_SHELL_APP:-$ROOT_DIR/zig-out/BlendZigShell.app}"
APP_BIN="$APP_PATH/Contents/MacOS/BlendZigShell"
DEMO_FILE="$ROOT_DIR/recipes/phase-19/viewport-gallery.bzscene"
RECIPE_FILE="$ROOT_DIR/recipes/phase-17/pocket-platform-study.bzrecipe"
SCENE_FILE="$ROOT_DIR/recipes/phase-17/persistence-workbench.bzscene"
CREATED_STUDY="$ROOT_DIR/zig-out/phase-19-starter-sphere.bzrecipe"
CREATED_OBJ="$ROOT_DIR/zig-out/phase-19-starter-sphere.obj"

cd "$ROOT_DIR"

bash scripts/verify-phase-18.sh

preview_output="$("$APP_BIN" --smoke-preview "$DEMO_FILE")"
printf '%s\n' "$preview_output"
grep -q "preview kind=scene" <<<"$preview_output"
grep -q "geometry=.*phase-19-viewport-gallery.obj" <<<"$preview_output"
grep -q "camera-position=" <<<"$preview_output"
grep -q "camera-target=" <<<"$preview_output"

recipe_inspect_output="$("$APP_BIN" --smoke-inspect "$RECIPE_FILE")"
printf '%s\n' "$recipe_inspect_output"
grep -q "inspect kind=recipe" <<<"$recipe_inspect_output"
grep -q "focus-targets=1" <<<"$recipe_inspect_output"
grep -q "focus-kind=grid" <<<"$recipe_inspect_output"

scene_inspect_output="$("$APP_BIN" --smoke-inspect "$SCENE_FILE")"
printf '%s\n' "$scene_inspect_output"
grep -q "inspect kind=scene" <<<"$scene_inspect_output"
grep -q "focus-targets=3" <<<"$scene_inspect_output"
grep -q "focus-kind=obj" <<<"$scene_inspect_output"

rm -f "$CREATED_STUDY" "$CREATED_OBJ"
create_output="$("$APP_BIN" --smoke-create-primitive sphere "$CREATED_STUDY")"
printf '%s\n' "$create_output"
grep -q "inspect kind=recipe" <<<"$create_output"
grep -q "focus-targets=1" <<<"$create_output"
grep -q "focus-kind=sphere" <<<"$create_output"
grep -q "wrote .*phase-19-starter-sphere.obj" <<<"$create_output"
test -f "$CREATED_STUDY"
test -f "$CREATED_OBJ"

transform_output="$("$APP_BIN" --smoke-save-recipe-transform "$CREATED_STUDY" 1.2 1.1 0.9 22 2.5 -1.0 0.75)"
printf '%s\n' "$transform_output"
grep -q "inspect kind=recipe" <<<"$transform_output"
grep -q "transform-editable=true" <<<"$transform_output"
grep -q "transform-scale=(1.2,1.1,0.9)" <<<"$transform_output"
grep -q "transform-rotate-z=22.0" <<<"$transform_output"
grep -q "transform-translate=(2.5,-1.0,0.75)" <<<"$transform_output"
grep -q "wrote .*phase-19-starter-sphere.obj" <<<"$transform_output"
grep -q '^step=scale:x=1.2,y=1.1,z=0.9$' "$CREATED_STUDY"
grep -q '^step=rotate-z:degrees=22.0$' "$CREATED_STUDY"
grep -q '^step=translate:x=2.5,y=-1.0,z=0.75$' "$CREATED_STUDY"

npm run status:update
npm run status:check
npm run status:live
bash scripts/ralph-loop.sh --task-file tasks/phase-19.md --dry-run --once
bash scripts/team-loop.sh --task-file tasks/phase-19.md --dry-run

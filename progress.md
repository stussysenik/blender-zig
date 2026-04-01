# Progress

> Generated from `status/hyperdata.json`. Refresh with `npm run status:update`.

## Hypertime Snapshot

- source: `status/hyperdata.json`

Artifacts:
- `progress.md`
- `docs/screenshots/current-state.svg`
- `docs/assets/phase-map.svg`

## Current State

`blender-zig` is a runnable Zig CLI on macOS and a staged rewrite workspace for Blender-inspired geometry systems.

Completed phases:
- Phase 0: Repo bootstrap
- Phase 1: Mesh and primitive slice
- Phase 2: Verification baseline
- Phase 3: Curves kernel
- Phase 4: Curve interpolation
- Phase 5: Instances and realization
- Phase 6: Nodes and evaluation
- Phase 7: Geometry bridge
- Phase 8: Curves in nodes
- Phase 9: Distribution and references
- Phase 10: Runnable graph demo
- Phase 11: Direct curve modeling
- Phase 14: Composable local authoring
- Phase 16: Directed modeling and phase execution
- Phase 17: Scene persistence and mixed packaging
- Phase 18: App shell foundation

Active phases:
- Phase 12: Release and governance
- Phase 13: Direct mesh ops
- Phase 15: Mesh IO surfaces
- Phase 19: Viewport and interaction MVP

Open phases:
- Phase 20: Daily-driver hardening

## What Runs Today

- `zig test -target aarch64-macos.15.0 src/lib.zig`
- `zig test -target aarch64-macos.15.0 --dep blendzig -Mroot=src/main.zig -Mblendzig=src/lib.zig`
- `zig build-exe -target aarch64-macos.15.0 --dep blendzig -Mroot=src/main.zig -Mblendzig=src/lib.zig -femit-bin=zig-out/bin/blender-zig-direct`
- `./zig-out/bin/blender-zig-direct mesh-delete-edge zig-out/mesh-delete-edge.obj`
- `./zig-out/bin/blender-zig-direct mesh-pipeline --recipe recipes/phase-16/wire-cleanup.bzrecipe`
- `./zig-out/bin/blender-zig-direct mesh-pipeline --recipe recipes/phase-16/wire-rebuild.bzrecipe`
- `./zig-out/bin/blender-zig-direct mesh-pipeline --recipe recipes/phase-16/panel-lift.bzrecipe`
- `./zig-out/bin/blender-zig-direct mesh-pipeline --recipe recipes/phase-16/chamfer-recovery.bzrecipe`
- `./zig-out/bin/blender-zig-direct mesh-scene --recipe recipes/phase-16/modeling-bench.bzscene`
- `./zig-out/bin/blender-zig-direct mesh-pipeline --recipe recipes/phase-16/wire-rebuild.bzrecipe --write zig-out/phase-17-wire-rebuild.obj`
- `./zig-out/bin/blender-zig-direct mesh-scene --recipe recipes/phase-16/modeling-bench.bzscene --write zig-out/phase-17-modeling-bench.obj`
- `./zig-out/bin/blender-zig-direct mesh-import zig-out/phase-17-modeling-bench.obj zig-out/phase-17-modeling-bench-roundtrip.obj`
- `./zig-out/bin/blender-zig-direct mesh-pipeline --recipe recipes/phase-17/pocket-platform-study.bzrecipe`
- `./zig-out/bin/blender-zig-direct mesh-pipeline --recipe recipes/phase-17/rail-bevel-study.bzrecipe`
- `./zig-out/bin/blender-zig-direct mesh-scene --recipe recipes/phase-17/persistence-workbench.bzscene --write zig-out/phase-17-persistence-workbench.obj`
- `./zig-out/bin/blender-zig-direct mesh-import zig-out/phase-17-persistence-workbench.obj zig-out/phase-17-persistence-workbench-roundtrip.obj`
- `swift test --package-path macos/BlendZigShell`
- `bash scripts/build-phase-18-shell.sh`
- `bash scripts/verify-phase-18.sh`
- `bash scripts/verify-phase-19.sh`
- `bash scripts/demo-phase-19.sh`
- `zig-out/BlendZigShell.app/Contents/MacOS/BlendZigShell --smoke-inspect recipes/phase-17/pocket-platform-study.bzrecipe`
- `zig-out/BlendZigShell.app/Contents/MacOS/BlendZigShell --smoke-inspect recipes/phase-17/persistence-workbench.bzscene`
- `zig-out/BlendZigShell.app/Contents/MacOS/BlendZigShell --smoke-create-primitive sphere zig-out/phase-19-starter-sphere.bzrecipe`
- `zig-out/BlendZigShell.app/Contents/MacOS/BlendZigShell --smoke-save-recipe-transform zig-out/phase-19-starter-sphere.bzrecipe 1.2 1.1 0.9 22 2.5 -1.0 0.75`
- `bash scripts/verify-local.sh`
- `bash scripts/verify-phase-16.sh`
- `bash scripts/verify-phase-17.sh`
- `bash scripts/verify-clean-room.sh`
- `npm run reference:setup`
- `npm run dist -- <version>`

## Next Targets

- Verify the viewport MVP through tests and a real local run on `recipes/phase-19/viewport-gallery.bzscene`, using `bash scripts/demo-phase-19.sh` as the concrete demo path.
- Define the first focused-recipe direct modeling slice around one bounded `subdivide` route that preserves the trailing transform block.
- Implement one shell route that inserts or rewrites the bounded `subdivide` step before the current transform block without losing focus.
- Keep the next widened export or handoff path on a universal/open format with explicit semantics instead of inventing opaque app-only files.

## Readout

The repo is past bootstrap and now behaves like a native Zig geometry tool on macOS.
Saved recipe files now sit on top of the same `SeedSpec` and `StepSpec` model as inline pipeline runs, including primitive size and resolution overrides, bounded transforms, and array composition.
Composed scene files can now combine multiple `.bzrecipe` studies or imported `.obj` meshes through `mesh-scene`, with scene-level translate, scale, and rotate-z placement tokens on each part.
Direct cleanup now includes `mesh-delete-loose`, which removes loose edges and isolated points while compacting the surviving face mesh deterministically.
Direct editing now includes `mesh-delete-face`, which removes selected faces while keeping the exposed border as loose wire and preserving unrelated loose edges.
Direct repair now includes `mesh-fill-hole`, which turns one simple planar loose loop back into one face while preserving unrelated faces and loose edges.
Direct topology growth now includes `mesh-bevel-edge`, which bevels one selected manifold shared edge by rewriting the two incident face loops and bridging them with one chamfer quad strip.
Direct constrained editing now includes `mesh-delete-edge`, which removes one loose edge directly or deletes the one-or-two incident faces and preserves the exposed border as loose wire.
The canonical phase-16 constrained-edit contract now lives in `openspec/daily-driver/slices/phase-16-delete-edge.md`, with compatibility pointers left under `docs/` for older links.
Local verification now has a host-safe direct compile path through `scripts/verify-local.sh` and `scripts/verify-phase-16.sh`, which avoids the current Homebrew Zig 0.15.2 native `zig build` runner issue on the macOS 26 host target.
Direct modeling now includes `mesh-extrude-region`, which extrudes the mesh-wide open face region as one shell and bridges only the boundary instead of building per-face internal walls.
Direct modeling now includes `mesh-inset-region`, which offsets one planar open face region inward, preserves the source cap layout, and fills the new border ring with quads.
Phase-scoped operator runs are now supported through `scripts/ralph-loop.sh --phase N` and `scripts/team-loop.sh --phase N --dry-run`, and dedicated task files now exist from `tasks/phase-16.md` through `tasks/phase-20.md` for the daily-driver path.
The OpenSpec bundle under `openspec/daily-driver/` now has a stronger contract stack: product promise, system contracts, phase charters, and slice specs.
Replay-bearing recipe and scene files can now carry explicit `format-version`, `id`, and `title` metadata, with unsupported future versions rejected before replay widens silently.
The repo now has one portable geometry handoff unit in `.bzbundle/`, which keeps a line-oriented manifest beside a bundled `geometry.obj` payload instead of hiding state in shell-only files.
The new phase-17 study pack finally exercises persistence in a more practical loop: replay two authored studies, compose them with one imported OBJ plate, roundtrip the scene result, and then reopen the packed bundle again.
Missing `.bzscene` part files now fail as `ScenePartFileNotFound`, so imported asset references stop with a narrow persistence error instead of widening into silent drift.
Phase-17 verification can now rebuild the current tree inside a temporary git worktree and rerun the full persistence path without manual edits.
The first phase-18 shell bundle is now buildable at `zig-out/BlendZigShell.app`, with a SwiftUI window that opens `.bzrecipe`, `.bzscene`, and `.bzbundle` files through the bundled helper binary.
That shell now inspects replay metadata for recipes, scenes, and bundles, saves `title` in place for recipes and scenes, and rejects bundle mutation narrowly as inspect-only.
That same shell now refuses to overwrite a recipe or scene if the file changed on disk after open, so save conflicts fail with reload guidance instead of silently losing work.
Phase-19 viewport work has started with a native SceneKit preview panel that loads the helper-emitted OBJ output for one recipe or scene, uses deterministic starting camera framing, and exposes Apple camera controls plus a reset path.
The repo now includes `recipes/phase-19/viewport-gallery.bzscene` and `bash scripts/demo-phase-19.sh` as the concrete viewport demo path for Apple Silicon reruns.
The native shell can now create starter cuboid, cylinder, and sphere studies as `.bzrecipe` files, reopen them through the bundled helper, and focus one object or scene part through a bounded object-focus panel.
Mesh commands can now write ASCII PLY when the output path ends in `.ply`.
Mesh commands can now re-import a narrow ASCII OBJ subset through `mesh-import`, and mixed OBJ geometry can roundtrip through `geometry-import`.
The file-format rule is now explicit: `.bz*` stays human-readable authored or packaged state, while external handoff should prefer universal/open formats with declared semantics.
The native shell now persists focused recipe-root `scale`, `rotate-z`, and `translate` edits back into `.bzrecipe` text, reruns the helper-backed preview, and keeps the same focused object selected.
The next meaningful improvement is the first focused recipe direct modeling route: one bounded `subdivide` step exposed through the shell while the manual viewport orbit/pan/zoom proof stays explicitly open.

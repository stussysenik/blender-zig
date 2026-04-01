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

Active phases:
- Phase 12: Release and governance
- Phase 13: Direct mesh ops
- Phase 15: Mesh IO surfaces
- Phase 16: Directed modeling and phase execution

Open phases:
- Phase 17: Scene persistence and mixed packaging
- Phase 18: App shell foundation
- Phase 19: Viewport and interaction MVP
- Phase 20: Daily-driver hardening

## What Runs Today

- `zig test -target aarch64-macos.15.0 src/lib.zig`
- `zig test -target aarch64-macos.15.0 --dep blendzig -Mroot=src/main.zig -Mblendzig=src/lib.zig`
- `zig build-exe -target aarch64-macos.15.0 --dep blendzig -Mroot=src/main.zig -Mblendzig=src/lib.zig -femit-bin=zig-out/bin/blender-zig-direct`
- `./zig-out/bin/blender-zig-direct mesh-delete-edge zig-out/mesh-delete-edge.obj`
- `./zig-out/bin/blender-zig-direct mesh-pipeline --recipe recipes/phase-16/wire-cleanup.bzrecipe`
- `bash scripts/verify-local.sh`
- `bash scripts/verify-phase-16.sh`
- `npm run reference:setup`
- `npm run dist -- <version>`

## Next Targets

- Add edit-heavy saved studies and one composed scene for the phase-16 stack now that `mesh-delete-edge` is landed and verified.
- Start phase 17 by landing replayable study metadata and mixed-scene packaging from `tasks/phase-17.md`.
- Add non-OBJ export handling for mixed mesh-plus-curve geometry where the format semantics stay clear.
- Add notarization only after Apple credentials exist.

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
Mesh commands can now write ASCII PLY when the output path ends in `.ply`.
Mesh commands can now re-import a narrow ASCII OBJ subset through `mesh-import`, and mixed OBJ geometry can roundtrip through `geometry-import`.
The next meaningful improvement is still in `src/`, not in more planning artifacts.

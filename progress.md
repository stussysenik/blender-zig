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

Open phases:
- none

## What Runs Today

- `zig build test`
- `zig build -Doptimize=ReleaseFast`
- `zig build run -- sphere`
- `zig build run -- cylinder zig-out/cylinder.obj`
- `zig build run -- mesh-import zig-out/sphere.obj zig-out/sphere-roundtrip.obj`
- `zig build run -- cylinder zig-out/cylinder.ply`
- `zig build run -- curve-wire zig-out/curve-wire.obj`
- `zig build run -- curve-tube zig-out/curve-tube.obj`
- `zig build run -- mesh-roundtrip zig-out/mesh-roundtrip.obj`
- `zig build run -- mesh-triangulate zig-out/mesh-triangulate.obj`
- `zig build run -- mesh-delete-face zig-out/mesh-delete-face.obj`
- `zig build run -- mesh-delete-loose zig-out/mesh-delete-loose.obj`
- `zig build run -- mesh-merge-by-distance zig-out/mesh-merge-by-distance.obj`
- `zig build run -- mesh-inset zig-out/mesh-inset.obj`
- `zig build run -- mesh-inset-region zig-out/mesh-inset-region.obj`
- `zig build run -- mesh-dissolve zig-out/mesh-dissolve.obj`
- `zig build run -- mesh-extrude zig-out/mesh-extrude.obj`
- `zig build run -- mesh-extrude-region zig-out/mesh-extrude-region.obj`
- `zig build run -- mesh-planar-dissolve zig-out/mesh-planar-dissolve.obj`
- `zig build run -- mesh-subdivide zig-out/mesh-subdivide.obj`
- `zig build run -- mesh-pipeline grid:verts-x=8,verts-y=5,size-x=4.0,size-y=2.0 subdivide:repeat=2 extrude:distance=0.75 inset:factor=0.1 --write zig-out/pipeline.obj`
- `zig build run -- mesh-pipeline --recipe recipes/grid-study.bzrecipe`
- `zig build run -- mesh-pipeline --recipe recipes/courtyard-plaza-study.bzrecipe`
- `zig build run -- mesh-pipeline --recipe recipes/walkway-bays-study.bzrecipe`
- `zig build run -- mesh-pipeline --recipe recipes/tower-stack-study.bzrecipe`
- `zig build run -- mesh-scene --recipe recipes/courtyard-tower-scene.bzscene`
- `zig build run -- mesh-scene --recipe recipes/walkway-plaza-scene.bzscene`
- `zig build run -- mesh-pipeline --recipe recipes/cuboid-facet-study.bzrecipe`
- `zig build run -- mesh-pipeline --recipe recipes/cylinder-panel-study.bzrecipe`
- `zig build run -- mesh-edges zig-out/mesh-edges.obj`
- `zig build run -- graph-demo zig-out/graph-demo.obj`
- `zig build run -- geometry-import zig-out/graph-demo.obj zig-out/graph-demo-roundtrip.obj`
- `npm run reference:setup`
- `npm run dist -- <version>`

## Next Targets

- Port a bevel-like topology-growth mesh op to strengthen direct modeling beyond the current delete/inset/extrude stack.
- Add more reusable saved studies and scene recipes so authoring keeps moving toward a daily-use geometry tool.
- Add non-OBJ export handling for mixed mesh-plus-curve geometry where the format semantics stay clear.
- Widen import beyond the narrow OBJ subset only when a concrete modeling need appears.
- Add notarization only after Apple credentials exist.

## Readout

The repo is past bootstrap and now behaves like a native Zig geometry tool on macOS.
Saved recipe files now sit on top of the same `SeedSpec` and `StepSpec` model as inline pipeline runs, including primitive size and resolution overrides, bounded transforms, and array composition.
Composed scene files can now combine multiple `.bzrecipe` studies or imported `.obj` meshes through `mesh-scene`, with scene-level translate, scale, and rotate-z placement tokens on each part.
Direct cleanup now includes `mesh-delete-loose`, which removes loose edges and isolated points while compacting the surviving face mesh deterministically.
Direct editing now includes `mesh-delete-face`, which removes selected faces while keeping the exposed border as loose wire and preserving unrelated loose edges.
Direct modeling now includes `mesh-extrude-region`, which extrudes the mesh-wide open face region as one shell and bridges only the boundary instead of building per-face internal walls.
Direct modeling now includes `mesh-inset-region`, which offsets one planar open face region inward, preserves the source cap layout, and fills the new border ring with quads.
Mesh commands can now write ASCII PLY when the output path ends in `.ply`.
Mesh commands can now re-import a narrow ASCII OBJ subset through `mesh-import`, and mixed OBJ geometry can roundtrip through `geometry-import`.
The next meaningful improvement is still in `src/`, not in more planning artifacts.

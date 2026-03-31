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

Active phases:
- Phase 12: Release and governance
- Phase 13: Direct mesh ops

Open phases:
- none

## What Runs Today

- `zig build test`
- `zig build -Doptimize=ReleaseFast`
- `zig build run -- sphere`
- `zig build run -- cylinder zig-out/cylinder.obj`
- `zig build run -- curve-wire zig-out/curve-wire.obj`
- `zig build run -- curve-tube zig-out/curve-tube.obj`
- `zig build run -- mesh-roundtrip zig-out/mesh-roundtrip.obj`
- `zig build run -- mesh-triangulate zig-out/mesh-triangulate.obj`
- `zig build run -- mesh-merge-by-distance zig-out/mesh-merge-by-distance.obj`
- `zig build run -- mesh-inset zig-out/mesh-inset.obj`
- `zig build run -- mesh-dissolve zig-out/mesh-dissolve.obj`
- `zig build run -- mesh-extrude zig-out/mesh-extrude.obj`
- `zig build run -- mesh-planar-dissolve zig-out/mesh-planar-dissolve.obj`
- `zig build run -- mesh-subdivide zig-out/mesh-subdivide.obj`
- `zig build run -- mesh-edges zig-out/mesh-edges.obj`
- `zig build run -- graph-demo zig-out/graph-demo.obj`
- `npm run reference:setup`
- `npm run dist -- <version>`

## Next Targets

- Add another export path beyond OBJ once the mesh-plus-curves model stabilizes.
- Port another narrow mesh operation such as a delete/cleanup pass or bevel-like growth.
- Add notarization only after Apple credentials exist.

## Readout

The repo is past bootstrap and now behaves like a native Zig geometry tool on macOS.
The next meaningful improvement is still in `src/`, not in more planning artifacts.

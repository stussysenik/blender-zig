# Progress

> Generated from `status/hyperdata.json` and git state. Refresh with `npm run status:update`.

## Hypertime Snapshot

- branch: `main`
- head: `dd7c539f`
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

Open phases:
- none

## Pushed Commits

- `dd7c539f` feat: automate status docs and roundtrip cli
- `fd883e59` fix: repair direct geometry modeling build
- `13b13a86` feat: add direct curve sweep modeling
- `e455c279` feat: add mesh edges to curves conversion
- `e100adcb` feat: add cylinder and cone primitive mesh
- `e9f4aaec` feat: add curves to mesh conversion
- `b1f931fc` docs: add rewrite progress surfaces
- `20b6d834` feat: add graph demo cli export path

## What Runs Today

- `zig build test`
- `zig build -Doptimize=ReleaseFast`
- `zig build run -- sphere`
- `zig build run -- cylinder zig-out/cylinder.obj`
- `zig build run -- curve-wire zig-out/curve-wire.obj`
- `zig build run -- curve-tube zig-out/curve-tube.obj`
- `zig build run -- mesh-roundtrip zig-out/mesh-roundtrip.obj`
- `zig build run -- mesh-edges zig-out/mesh-edges.obj`
- `zig build run -- graph-demo zig-out/graph-demo.obj`
- `npm run reference:setup`
- `npm run dist -- <version>`

## Next Targets

- Add another export path beyond OBJ once the mesh-plus-curves model stabilizes.
- Port a narrow mesh operation like merge-by-distance or triangulate.
- Add notarization only after Apple credentials exist.

## Readout

The repo is past bootstrap and now behaves like a native Zig geometry tool on macOS.
The next meaningful improvement is still in `src/`, not in more planning artifacts.

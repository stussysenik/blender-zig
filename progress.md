# Progress

## Hypertime Snapshot

Artifacts:
- `progress.md`
- `docs/screenshots/current-state.svg`
- `docs/assets/phase-map.svg`

## Current State

`blender-zig` is a runnable Zig CLI on macOS and a staged rewrite workspace for Blender-inspired geometry systems.

Completed phases:
- Phase 0: repo bootstrap
- Phase 1: mesh and primitive slice
- Phase 2: verification baseline
- Phase 3: curves kernel
- Phase 4: curve interpolation
- Phase 5: instances and realization
- Phase 6: nodes and evaluation
- Phase 7: geometry bridge
- Phase 8: curves in nodes
- Phase 9: distribution and references
- Phase 10: runnable graph demo surface

Open phase:
- Phase 11: release and governance

## Pushed Commits

- `18f16c6d` `ci: add macos artifact workflow`
- `11d3ba30` `build: add distribution and reference tooling`
- `74ca0cae` `feat: add curve realization nodes`
- `4de2b7de` `feat: add node-level realize instances flow`
- `5ab7dfe8` `feat: add curve nodes to geometry evaluation`
- `927027c3` `docs: advance geometry bridge roadmap`

## What Runs Today

- `zig build test`
- `zig build -Doptimize=ReleaseFast`
- `zig build run -- sphere`
- `zig build run -- cuboid zig-out/cuboid.obj`
- `zig build run -- graph-demo zig-out/graph-demo.obj`
- `npm run reference:setup`
- `npm run dist -- <version>`
- `bash scripts/ralph-loop.sh --dry-run --task 'extend GeometrySet beyond the curves-first slice' --role architect`

Observed local outputs:
- `zig-out/bin/blender-zig` is a Mach-O 64-bit arm64 executable on macOS.
- `npm run dist` writes a zip archive under `dist/` and a SHA-256 sidecar.
- `npm run reference:setup` adds and fetches the `blender-reference` remote.
- `graph-demo` builds a real `GeometrySet` from the node graph and can export it as one OBJ.

## Next Targets

- Broaden the graph-demo recipe into a small scene recipe surface instead of one fixed graph.
- Add another export path beyond OBJ once the mesh-plus-curves model stabilizes.
- Add notarization only after Apple credentials exist.
- Keep the Zig runtime slice smaller than the release/tooling surface.

## Readout

The repo is past the bootstrap stage and now has a working native CLI, geometry realization flow, curve-producing nodes, and distribution scaffolding.
The next meaningful improvement is still in `src/`, not in more planning artifacts.

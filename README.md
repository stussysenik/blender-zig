# blender-zig

A companion Zig rewrite that lifts a realistic first slice out of Blender instead of pretending the whole codebase can be transliterated in one shot.

The status sections in this file, [progress.md](/Users/s3nik/Desktop/blender-zig/progress.md), and [ROADMAP.md](/Users/s3nik/Desktop/blender-zig/ROADMAP.md) are generated from `status/hyperdata.json` via `npm run status:update`.

Contributor surfaces:
- [ARCHITECTURE.md](/Users/s3nik/Desktop/blender-zig/ARCHITECTURE.md)
- [CONTRIBUTING.md](/Users/s3nik/Desktop/blender-zig/CONTRIBUTING.md)
- [tasks/zig-rewrite.md](/Users/s3nik/Desktop/blender-zig/tasks/zig-rewrite.md)

Current focus:
<!-- status:auto:focus:start -->
- `blenlib`-style core utilities: disjoint sets and offset indices
- mesh topology and bounds
- geometry primitive generation: line, grid, cuboid, cylinder, cone, UV sphere
- curves-to-mesh wire conversion and swept mesh generation
- bounded direct mesh ops beginning with triangulation
- mesh-edge extraction into curves
- OBJ export so generated geometry can be inspected immediately
- OMX/Ralphy-inspired team and release scaffolding around the rewrite effort
<!-- status:auto:focus:end -->

Current status:
<!-- status:auto:status:start -->
- phase 0 bootstrap through phase 10 runnable graph demo are in
- phase 11 direct curve modeling is in with `curve-wire`, `curve-tube`, `mesh-edges`, and `mesh-roundtrip`
- phase 13 direct mesh ops is started with `mesh-triangulate`, preserving corner UVs and loose edges
- `GeometrySet` OBJ export is in for mixed mesh and curve output
- optimized packaging, reference remote setup, and a macOS CLI artifact workflow are in
- the next recommended slices are tighter mesh ops and broader export paths, not UI or rendering
<!-- status:auto:status:end -->

This repo is intentionally narrow. It is inspired by Blender subsystems like:
- `source/blender/blenlib/BLI_disjoint_set.hh`
- `source/blender/blenlib/BLI_offset_indices.hh`
- `source/blender/geometry/intern/mesh_primitive_line.cc`
- `source/blender/geometry/intern/mesh_primitive_grid.cc`
- `source/blender/geometry/intern/mesh_primitive_cuboid.cc`
- `source/blender/geometry/intern/mesh_primitive_uv_sphere.cc`

For the upstream scan and the next port targets, see `docs/blender-repo-scan.md`.

Progress surfaces:
<!-- status:auto:progress-surfaces:start -->
- [hypertime progress log](/Users/s3nik/Desktop/blender-zig/progress.md)
- [current state snapshot](/Users/s3nik/Desktop/blender-zig/docs/screenshots/current-state.svg)
- [phase map](/Users/s3nik/Desktop/blender-zig/docs/assets/phase-map.svg)
<!-- status:auto:progress-surfaces:end -->

Reference and distribution helpers:
<!-- status:auto:reference-helpers:start -->
- npm run reference:setup
- npm run dist
- npm run sign:macos -- zig-out/bin/blender-zig "Developer ID Application: Your Name"
<!-- status:auto:reference-helpers:end -->
- [reference and distribution notes](/Users/s3nik/Desktop/blender-zig/docs/reference-and-distribution.md)

## Quick Start

<!-- status:auto:quick-start:start -->
```bash
zig build test
zig build run -- sphere
zig build run -- cylinder zig-out/cylinder.obj
zig build run -- curve-wire zig-out/curve-wire.obj
zig build run -- curve-tube zig-out/curve-tube.obj
zig build run -- mesh-roundtrip zig-out/mesh-roundtrip.obj
zig build run -- mesh-triangulate zig-out/mesh-triangulate.obj
zig build run -- mesh-edges zig-out/mesh-edges.obj
zig build run -- graph-demo zig-out/graph-demo.obj
npm run dist
```
<!-- status:auto:quick-start:end -->

CLI usage:

<!-- status:auto:cli-usage:start -->
```text
blender-zig <line|grid|cuboid|cylinder|cone|sphere|curve-wire|curve-tube|mesh-roundtrip|mesh-triangulate|mesh-edges|graph-demo> [output.obj]
```
<!-- status:auto:cli-usage:end -->

Defaults are intentionally opinionated:
- `line`: 8 points
- `grid`: `8 x 5`
- `cuboid`: `4 x 3 x 2`
- `sphere`: `16 segments x 8 rings`

## Contributing

If you want to work in the repo instead of just run it:
- read [ARCHITECTURE.md](/Users/s3nik/Desktop/blender-zig/ARCHITECTURE.md) first
- follow [CONTRIBUTING.md](/Users/s3nik/Desktop/blender-zig/CONTRIBUTING.md) for the dev loop
- treat [status/hyperdata.json](/Users/s3nik/Desktop/blender-zig/status/hyperdata.json) as the source of truth for generated status docs
- keep new work narrow, tested, and wired to a real CLI path when practical

## What This Is Not

- not a renderer
- not a UI rewrite
- not a full Blender file-format or dependency-graph port
- not a claim that this can replace Blender yet

## Operating Model

The repo uses a stripped-down version of the workflow you referenced:
- OMX-style role prompts and planning surfaces
- Ralphy-style task loops and optional worktree isolation
- conventional commits and semantic-release scaffolding

Use the agent contract in [AGENTS.md](/Users/s3nik/Desktop/blender-zig/AGENTS.md) and the role prompts in [`.codex/prompts/`](/Users/s3nik/Desktop/blender-zig/.codex/prompts) when running the local loops.

Cryptographically verified commits are not enabled yet on this machine because no signing key is configured. The repo scaffolding assumes signed commits should be turned on once a signing identity exists.

## License Note

This rewrite is derived from Blender-inspired architecture and algorithmic ports. Before public distribution, keep the repository under GPL-compatible terms and add the final license text explicitly.

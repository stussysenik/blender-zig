# blender-zig

A companion Zig rewrite that lifts a realistic first slice out of Blender instead of pretending the whole codebase can be transliterated in one shot.

Current focus:
- `blenlib`-style core utilities: disjoint sets and offset indices
- mesh topology and bounds
- geometry primitive generation: line, grid, cuboid, UV sphere
- a small executable node-graph kernel for geometry-pipeline planning
- curves-first instances realization and regression coverage
- OBJ export so generated geometry can be inspected immediately
- OMX/Ralphy-inspired team/release scaffolding around the rewrite effort

Current status:
- phase 0 bootstrap is done
- the first mesh/primitive port slice is done
- the curves kernel and merge-curves slice are now in
- the curve interpolation slice is now in
- the curves-first instances and realization slice is now in
- executable node evaluation for primitive meshes is now in
- the shared `GeometrySet` bridge between nodes, meshes, and curves is now in
- curve-producing geometry nodes and curve-first realization nodes are now in
- reference setup, optimized packaging, and a macOS CLI artifact workflow are now in
- the next recommended slice is notarization plus broader distribution hardening once Apple credentials exist
- the OMX-native role prompts live in `.codex/prompts/` and are used by `scripts/ralph-loop.sh`

This repo is intentionally narrow. It is inspired by Blender subsystems like:
- `source/blender/blenlib/BLI_disjoint_set.hh`
- `source/blender/blenlib/BLI_offset_indices.hh`
- `source/blender/geometry/intern/mesh_primitive_line.cc`
- `source/blender/geometry/intern/mesh_primitive_grid.cc`
- `source/blender/geometry/intern/mesh_primitive_cuboid.cc`
- `source/blender/geometry/intern/mesh_primitive_uv_sphere.cc`

For the upstream scan and the next port targets, see `docs/blender-repo-scan.md`.

Reference and distribution helpers:
- `npm run reference:setup`
- `npm run dist`
- `npm run sign:macos -- zig-out/bin/blender-zig "Developer ID Application: Your Name"`
- [reference and distribution notes](/Users/s3nik/Desktop/blender-zig/docs/reference-and-distribution.md)

## Quick Start

```bash
zig build test
zig build run -- sphere
zig build run -- cuboid zig-out/cuboid.obj
zig build run -- grid zig-out/grid.obj
npm run dist
```

CLI usage:

```text
blender-zig <line|grid|cuboid|sphere> [output.obj]
```

Defaults are intentionally opinionated:
- `line`: 8 points
- `grid`: `8 x 5`
- `cuboid`: `4 x 3 x 2`
- `sphere`: `16 segments x 8 rings`

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

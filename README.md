# blender-zig

![Demo](demo.gif)


A companion Zig rewrite that lifts a realistic first slice out of Blender instead of pretending the whole codebase can be transliterated in one shot.

The status sections in this file, [progress.md](/Users/s3nik/Desktop/blender-zig/progress.md), and [ROADMAP.md](/Users/s3nik/Desktop/blender-zig/ROADMAP.md) are generated from versioned `status/hyperdata.json` via `npm run status:update`.
Use `npm run status:live` for the current branch and commit readout.

Contributor surfaces:
- [ARCHITECTURE.md](/Users/s3nik/Desktop/blender-zig/ARCHITECTURE.md)
- [CONTRIBUTING.md](/Users/s3nik/Desktop/blender-zig/CONTRIBUTING.md)
- [DESIGN.md](/Users/s3nik/Desktop/blender-zig/DESIGN.md)
- [TECHSTACK.md](/Users/s3nik/Desktop/blender-zig/TECHSTACK.md)
- [openspec/daily-driver/README.md](/Users/s3nik/Desktop/blender-zig/openspec/daily-driver/README.md)
- [tasks/README.md](/Users/s3nik/Desktop/blender-zig/tasks/README.md)
- [implementation-plan.md](/Users/s3nik/Desktop/blender-zig/docs/implementation-plan.md)
- [tasks/zig-rewrite.md](/Users/s3nik/Desktop/blender-zig/tasks/zig-rewrite.md)

Current focus:
<!-- status:auto:focus:start -->
- `blenlib`-style core utilities: disjoint sets and offset indices
- mesh topology and bounds
- geometry primitive generation: line, grid, cuboid, cylinder, cone, UV sphere
- curves-to-mesh wire conversion and swept mesh generation
- bounded direct mesh ops beginning with triangulation
- bounded face deletion that keeps the deleted region border as loose wire
- bounded hole fill that turns one simple planar loose loop back into one ngon cap
- mesh cleanup ops beginning with merge-by-distance and delete-loose
- individual-face inset modeling on the face-corner mesh
- bounded shared-edge dissolve that merges two faces into one ngon
- bounded individual-face extrusion along the face normal
- bounded open-region extrusion along averaged vertex normals
- bounded planar region inset that offsets one open face region inward and fills the border ring with quads
- bounded single-edge bevel growth that replaces one shared manifold edge with a chamfer strip
- limited planar dissolve for coplanar shared edges
- bounded face subdivision with shared edge midpoints
- parameterized mesh pipeline CLI over existing primitives and ops
- saved mesh-pipeline recipes with seed overrides, transforms, and arrays for repeatable local authoring studies
- version-checked replay metadata for `.bzrecipe` and `.bzscene` so saved studies and scenes can carry stable replay identity
- manifest-based `.bzbundle` packaging for mesh-only, curve-only, and mixed `GeometrySet` handoff on local macOS runs
- phase-17 persistence study coverage with replayable recipes, imported asset references, and one composed scene over the new bundle path
- phase-17 workflow follow-through with clean-room deterministic verification and clear missing-scene-part failures
- a minimal native macOS shell that opens `.bzrecipe`, `.bzscene`, and `.bzbundle` files through the bundled Zig helper
- universal/open interchange policy over OBJ and PLY, with `.bz*` reserved for readable authored state and packaged reopen state
- bounded mesh-space translate, scale, rotate-z, and array composition inside the authoring pipeline
- multi-part mesh scene composition over authored recipes and imported OBJ mesh parts, with part-level placement controls
- ASCII PLY mesh export alongside OBJ
- narrow ASCII OBJ mesh and mixed-geometry import for inspect-edit-export roundtrips
- mesh-edge extraction into curves
- OBJ export so generated geometry can be inspected immediately
- OMX/Ralphy-inspired team and release scaffolding around the rewrite effort
<!-- status:auto:focus:end -->

Current status:
<!-- status:auto:status:start -->
- phase 0 bootstrap through phase 10 runnable graph demo are in
- phase 11 direct curve modeling is in with `curve-wire`, `curve-tube`, `mesh-edges`, and `mesh-roundtrip`
- phase 13 direct mesh ops now includes `mesh-triangulate`, `mesh-bevel-edge`, `mesh-delete-face`, `mesh-fill-hole`, `mesh-delete-loose`, `mesh-merge-by-distance`, `mesh-inset`, `mesh-inset-region`, `mesh-dissolve`, `mesh-extrude`, `mesh-extrude-region`, `mesh-planar-dissolve`, and `mesh-subdivide`
- phase 14 local authoring now includes parameterized `mesh-pipeline` step specs, persisted recipe files, seed-level primitive overrides, bounded transforms, array composition, multi-part scene composition, part-level scene placement, and multiple checked-in studies
- phase 15 mesh IO now includes ASCII PLY export, narrow ASCII OBJ mesh import, and narrow mixed OBJ `GeometrySet` import
- phase 16 is complete: the bounded modeling stack now has repair, topology-growth, constrained edit, authored study-pack, composed scene, and phase-scoped verification coverage
- the constrained-edit slice is now specified in `openspec/daily-driver/slices/phase-16-delete-edge.md` as `mesh-delete-edge`, the edge-domain counterpart to `mesh-delete-face`
- the daily-driver planning surface now has a stronger OpenSpec stack: product contract, system contracts, phase charters, and slice specs under `openspec/daily-driver/`
- phase 17 is complete through `openspec/daily-driver/phases/phase-17-persistence-and-bundles.md`, with replay metadata, bundle format, study coverage, and workflow follow-through all green under `openspec/daily-driver/slices/`
- phase 18 is complete through `openspec/daily-driver/phases/phase-18-app-shell.md`, with shell-open, inspect/save, and workflow follow-through slices all green on the native macOS path
- phase 19 is now active through `openspec/daily-driver/phases/phase-19-viewport-and-tools.md`, and the current slice `openspec/daily-driver/slices/phase-19-workflow-follow-through.md` closes the interaction batch after the focused recipe-root `subdivide` route landed
- the stable-version path is now explicit in `openspec/daily-driver/system/stable-modeling-and-graph-path.md`: close the viewport MVP, then land object focus plus primitive creation, then persisted transforms, then one direct modeling op before widening into a graph-backed saved study
- the interchange contract is now explicit in `openspec/daily-driver/system/interchange-and-file-format-strategy.md`: keep `.bz*` as text-first authored state and prefer universal/open formats for external handoff
- `GeometrySet` OBJ import and export are in for mixed mesh and curve output
- optimized packaging, reference remote setup, and a macOS CLI artifact workflow are in
- current local verification is host-safe through `scripts/verify-local.sh`, `scripts/verify-phase-16.sh`, `scripts/verify-phase-17.sh`, `scripts/verify-phase-18.sh`, `scripts/verify-phase-19.sh`, and `scripts/verify-clean-room.sh`, which pin `aarch64-macos.15.0` on arm64 macOS while the native Homebrew Zig 0.15.2 `zig build` runner mislinks against the macOS 26 host target
- phase 16 now includes an edit-heavy saved study pack under `recipes/phase-16/` plus the composed `recipes/phase-16/modeling-bench.bzscene`, so the modeling stack can be replayed as authored files instead of isolated operator demos
- phase-17 replay now preserves optional `format-version`, `id`, and `title` metadata on recipes and scenes, and the CLI prints that metadata during replay so saved work has visible identity
- bundle open and pack now cover mesh-only, curve-only, and mixed geometry through `geometry-bundle-pack` and `geometry-bundle-open`, giving the repo one portable reopen surface before full project state exists
- phase-17 study coverage now includes `recipes/phase-17/pocket-platform-study.bzrecipe`, `recipes/phase-17/rail-bevel-study.bzrecipe`, and `recipes/phase-17/persistence-workbench.bzscene`, which replay recipe transforms, scene placement, and one imported OBJ reference together
- the phase-17 verification batch now replays the persistence studies, checks that missing scene parts fail clearly, and reruns the same path from a temporary clean-room worktree before phase 18 starts
- the new `zig-out/BlendZigShell.app` bundle opens recipes, scenes, and bundles through one native macOS window while delegating replay back to the bundled `blender-zig-direct` helper
- the native shell now owns one bounded `step=subdivide:repeat=1` route for focused `.bzrecipe` files, preserving the trailing transform block while rerunning the same helper-backed preview path as the CLI
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
bash scripts/verify-local.sh
bash scripts/verify-phase-16.sh
bash scripts/verify-phase-17.sh
bash scripts/build-phase-18-shell.sh
bash scripts/verify-phase-18.sh
bash scripts/verify-phase-19.sh
bash scripts/demo-phase-19.sh
bash scripts/verify-clean-room.sh
zig build run -- sphere
zig build run -- cylinder zig-out/cylinder.obj
zig build run -- mesh-import zig-out/cylinder.obj zig-out/cylinder-roundtrip.obj
zig build run -- graph-demo zig-out/graph-demo.obj
zig build run -- geometry-import zig-out/graph-demo.obj zig-out/graph-demo-roundtrip.obj
zig build run -- cylinder zig-out/cylinder.ply
zig build run -- curve-wire zig-out/curve-wire.obj
zig build run -- curve-tube zig-out/curve-tube.obj
zig build run -- mesh-roundtrip zig-out/mesh-roundtrip.obj
zig build run -- mesh-triangulate zig-out/mesh-triangulate.obj
zig build run -- mesh-bevel-edge zig-out/mesh-bevel-edge.obj
zig build run -- mesh-delete-face zig-out/mesh-delete-face.obj
zig build run -- mesh-fill-hole zig-out/mesh-fill-hole.obj
zig build run -- mesh-delete-loose zig-out/mesh-delete-loose.obj
zig build run -- mesh-merge-by-distance zig-out/mesh-merge-by-distance.obj
zig build run -- mesh-inset zig-out/mesh-inset.obj
zig build run -- mesh-inset-region zig-out/mesh-inset-region.obj
zig build run -- mesh-dissolve zig-out/mesh-dissolve.obj
zig build run -- mesh-extrude zig-out/mesh-extrude.obj
zig build run -- mesh-extrude-region zig-out/mesh-extrude-region.obj
zig build run -- mesh-planar-dissolve zig-out/mesh-planar-dissolve.obj
zig build run -- mesh-subdivide zig-out/mesh-subdivide.obj
zig build run -- mesh-pipeline grid:verts-x=8,verts-y=5,size-x=4.0,size-y=2.0 subdivide:repeat=2 extrude:distance=0.75 inset:factor=0.1 --write zig-out/pipeline.obj
zig build run -- mesh-pipeline --recipe recipes/grid-study.bzrecipe
zig build run -- mesh-pipeline --recipe recipes/courtyard-plaza-study.bzrecipe
zig build run -- mesh-pipeline --recipe recipes/walkway-bays-study.bzrecipe
zig build run -- mesh-pipeline --recipe recipes/tower-stack-study.bzrecipe
zig build run -- mesh-pipeline --recipe recipes/phase-16/wire-cleanup.bzrecipe
zig build run -- mesh-pipeline --recipe recipes/phase-16/wire-rebuild.bzrecipe
zig build run -- mesh-pipeline --recipe recipes/phase-16/panel-lift.bzrecipe
zig build run -- mesh-pipeline --recipe recipes/phase-16/chamfer-recovery.bzrecipe
zig build run -- mesh-scene --recipe recipes/phase-16/modeling-bench.bzscene
zig build run -- mesh-pipeline --recipe recipes/phase-17/pocket-platform-study.bzrecipe
zig build run -- mesh-pipeline --recipe recipes/phase-17/rail-bevel-study.bzrecipe
zig build run -- mesh-scene --recipe recipes/phase-17/persistence-workbench.bzscene
open zig-out/BlendZigShell.app
zig-out/BlendZigShell.app/Contents/MacOS/BlendZigShell --smoke-inspect recipes/phase-17/pocket-platform-study.bzrecipe
zig-out/BlendZigShell.app/Contents/MacOS/BlendZigShell --smoke-inspect recipes/phase-17/persistence-workbench.bzscene
zig-out/BlendZigShell.app/Contents/MacOS/BlendZigShell --smoke-create-primitive sphere zig-out/phase-19-starter-sphere.bzrecipe
zig-out/BlendZigShell.app/Contents/MacOS/BlendZigShell --smoke-save-recipe-transform zig-out/phase-19-starter-sphere.bzrecipe 1.2 1.1 0.9 22 2.5 -1.0 0.75
zig-out/BlendZigShell.app/Contents/MacOS/BlendZigShell --smoke-save-recipe-subdivide zig-out/phase-19-starter-sphere.bzrecipe on
bash scripts/verify-phase-17.sh
bash scripts/verify-phase-18.sh
zig build run -- geometry-bundle-pack zig-out/phase-17-bundle-mixed.obj zig-out/phase-17-bundle-mixed.bzbundle
zig build run -- geometry-bundle-open zig-out/phase-17-bundle-mixed.bzbundle zig-out/phase-17-bundle-mixed-roundtrip.obj
zig build run -- mesh-scene --recipe recipes/courtyard-tower-scene.bzscene
zig build run -- mesh-scene --recipe recipes/walkway-plaza-scene.bzscene
zig build run -- mesh-pipeline --recipe recipes/cuboid-facet-study.bzrecipe
zig build run -- mesh-pipeline --recipe recipes/cylinder-panel-study.bzrecipe
zig build run -- mesh-edges zig-out/mesh-edges.obj
zig build run -- graph-demo zig-out/graph-demo.obj
zig build run -- geometry-import zig-out/graph-demo.obj zig-out/graph-demo-roundtrip.obj
bash scripts/ralph-loop.sh --task-file tasks/phase-19.md --dry-run --once
bash scripts/team-loop.sh --task-file tasks/phase-19.md --dry-run
npm run dist
```
<!-- status:auto:quick-start:end -->

CLI usage:

<!-- status:auto:cli-usage:start -->
```text
blender-zig <line|grid|cuboid|cylinder|cone|sphere|curve-wire|curve-tube|mesh-roundtrip|mesh-triangulate|mesh-bevel-edge|mesh-delete-edge|mesh-delete-face|mesh-fill-hole|mesh-delete-loose|mesh-merge-by-distance|mesh-inset|mesh-inset-region|mesh-dissolve|mesh-extrude|mesh-extrude-region|mesh-planar-dissolve|mesh-subdivide|mesh-pipeline|mesh-scene|mesh-import|geometry-import|geometry-bundle-pack|geometry-bundle-open|mesh-edges|graph-demo> [output-path]
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

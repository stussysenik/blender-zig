# Architecture

This repo is a staged Zig rewrite of a narrow Blender-like geometry stack. It is not trying to mirror Blender's full editor, renderer, or dependency graph yet. The current codebase is centered on a small set of data models and a direct CLI that exercises them.

## Read This First

If you want the fastest path into the code, read files in this order:

1. [src/main.zig](/Users/s3nik/Desktop/blender-zig/src/main.zig)
2. [src/lib.zig](/Users/s3nik/Desktop/blender-zig/src/lib.zig)
3. [src/mesh.zig](/Users/s3nik/Desktop/blender-zig/src/mesh.zig)
4. [src/geometry/curves.zig](/Users/s3nik/Desktop/blender-zig/src/geometry/curves.zig)
5. [src/geometry/realize_instances.zig](/Users/s3nik/Desktop/blender-zig/src/geometry/realize_instances.zig)
6. One concrete op under [src/geometry/](/Users/s3nik/Desktop/blender-zig/src/geometry)
7. [src/io/obj.zig](/Users/s3nik/Desktop/blender-zig/src/io/obj.zig) and [src/io/ply.zig](/Users/s3nik/Desktop/blender-zig/src/io/ply.zig)
8. [src/pipeline.zig](/Users/s3nik/Desktop/blender-zig/src/pipeline.zig)
9. [src/scene.zig](/Users/s3nik/Desktop/blender-zig/src/scene.zig)

That path gives you the executable entrypoint, the public surface, the core mesh model, the curve model, the mixed geometry container, one feature slice, and the export path.

## Core Data Model

### `Mesh`

Defined in [src/mesh.zig](/Users/s3nik/Desktop/blender-zig/src/mesh.zig).

This is the main polygonal data structure:

- `positions`: vertex positions
- `edges`: explicit mesh edges, including loose edges
- `face_offsets`: prefix offsets into the corner arrays
- `corner_verts`: the vertex index for each face corner
- `corner_edges`: the edge index for each face corner after rebuilding topology
- `corner_uvs`: optional UVs stored per corner, aligned with `corner_verts`

The important idea is that faces do not store nested vertex lists directly. Instead, `face_offsets` slices the flat corner arrays. That mirrors Blender's face/corner split closely enough to support ports without pulling in Blender's full type system.

### `CurvesGeometry`

Defined in [src/geometry/curves.zig](/Users/s3nik/Desktop/blender-zig/src/geometry/curves.zig).

This stores:

- flat point positions
- curve offsets
- cyclic flags
- a narrow test attribute used to preserve remapping behavior in ports

The current implementation treats curves as polyline-like. That is deliberate. It keeps the port narrow while still covering merge, interpolation, extraction, and sweep paths.

### `GeometrySet`

Defined in [src/geometry/realize_instances.zig](/Users/s3nik/Desktop/blender-zig/src/geometry/realize_instances.zig).

This is the mixed container used by higher-level evaluation:

- optional `mesh`
- optional `curves`
- optional `instances`

It is intentionally much smaller than Blender's component registry. Right now it exists so mesh and curve features can coexist in one value without dragging in the rest of Blender's architecture.

### `Instances`

Also in [src/geometry/realize_instances.zig](/Users/s3nik/Desktop/blender-zig/src/geometry/realize_instances.zig).

Instances hold:

- referenced `GeometrySet` values
- instance items with transforms
- narrow float attributes for regression coverage

Instances are kept lazy until a realization step asks for real geometry.

## Execution Paths

### Direct CLI path

The default runtime path is:

1. [src/main.zig](/Users/s3nik/Desktop/blender-zig/src/main.zig) parses a command.
2. It builds a mesh or `GeometrySet` using a function in `src/geometry/`.
3. It prints a summary so the CLI is also a smoke test surface.
4. It optionally writes an OBJ or ASCII PLY, `mesh-import` reads a narrow ASCII OBJ mesh subset, `geometry-import` reads mixed face-plus-line OBJ geometry, `mesh-pipeline` covers bounded transform and array composition, and `mesh-scene` composes multiple authored or imported mesh parts with scene-level placement via [src/io/obj.zig](/Users/s3nik/Desktop/blender-zig/src/io/obj.zig), [src/io/ply.zig](/Users/s3nik/Desktop/blender-zig/src/io/ply.zig), [src/geometry/mesh_transform.zig](/Users/s3nik/Desktop/blender-zig/src/geometry/mesh_transform.zig), and [src/scene.zig](/Users/s3nik/Desktop/blender-zig/src/scene.zig).

This is the shortest path for new work. If a feature can be demonstrated directly, prefer adding a CLI route before routing it through the node runtime.

### Optional node path

The lightweight node evaluator lives in [src/nodes/graph.zig](/Users/s3nik/Desktop/blender-zig/src/nodes/graph.zig).

It currently exists for three reasons:

- prove that typed geometry values can flow through a tiny graph
- exercise realization and mixed geometry behavior
- keep the rewrite aligned with Blender-style evaluation without claiming parity

It is not the main contributor entrypoint. Start with direct geometry ops first.

## Directory Map

- [src/math.zig](/Users/s3nik/Desktop/blender-zig/src/math.zig): vector math and bounds
- [src/mesh.zig](/Users/s3nik/Desktop/blender-zig/src/mesh.zig): mesh topology container
- [src/pipeline.zig](/Users/s3nik/Desktop/blender-zig/src/pipeline.zig): bounded composable modeling pipeline, seed/step parser, and recipe loader
- [src/scene.zig](/Users/s3nik/Desktop/blender-zig/src/scene.zig): multi-part scene recipe parser and mesh composition runtime
- [src/geometry/mesh_delete_loose.zig](/Users/s3nik/Desktop/blender-zig/src/geometry/mesh_delete_loose.zig): bounded cleanup that removes loose edges and isolated points
- [src/geometry/mesh_transform.zig](/Users/s3nik/Desktop/blender-zig/src/geometry/mesh_transform.zig): bounded mesh-space translate, scale, rotate-z, and array helpers
- [src/geometry/primitives/](/Users/s3nik/Desktop/blender-zig/src/geometry/primitives): primitive mesh builders
- [src/geometry/curves.zig](/Users/s3nik/Desktop/blender-zig/src/geometry/curves.zig): curve kernel
- [src/geometry/curves_to_mesh.zig](/Users/s3nik/Desktop/blender-zig/src/geometry/curves_to_mesh.zig): wire and sweep conversion
- [src/geometry/mesh_extrude.zig](/Users/s3nik/Desktop/blender-zig/src/geometry/mesh_extrude.zig): bounded individual-face extrusion
- [src/geometry/mesh_subdivide.zig](/Users/s3nik/Desktop/blender-zig/src/geometry/mesh_subdivide.zig): bounded shared-midpoint face subdivision
- [src/geometry/mesh_to_curve.zig](/Users/s3nik/Desktop/blender-zig/src/geometry/mesh_to_curve.zig): edge extraction into curves
- [src/geometry/realize_instances.zig](/Users/s3nik/Desktop/blender-zig/src/geometry/realize_instances.zig): mixed geometry and realization
- [src/io/obj.zig](/Users/s3nik/Desktop/blender-zig/src/io/obj.zig): OBJ export plus narrow mesh and mixed-geometry import
- [src/io/ply.zig](/Users/s3nik/Desktop/blender-zig/src/io/ply.zig): ASCII PLY export for mesh-only output
- [src/nodes/graph.zig](/Users/s3nik/Desktop/blender-zig/src/nodes/graph.zig): optional typed graph evaluator
- [recipes/](/Users/s3nik/Desktop/blender-zig/recipes): saved authoring studies for `mesh-pipeline --recipe` and composed scenes for `mesh-scene --recipe`
- [tasks/zig-rewrite.md](/Users/s3nik/Desktop/blender-zig/tasks/zig-rewrite.md): checked backlog
- [status/hyperdata.json](/Users/s3nik/Desktop/blender-zig/status/hyperdata.json): source of truth for generated status docs
- [scripts/update-status.mjs](/Users/s3nik/Desktop/blender-zig/scripts/update-status.mjs): generator for `README.md`, `progress.md`, and `ROADMAP.md`

## How To Add A Feature

Use this sequence for most contributions:

1. Pick a narrow slice in [tasks/zig-rewrite.md](/Users/s3nik/Desktop/blender-zig/tasks/zig-rewrite.md).
2. Implement it under `src/geometry/` or `src/geometry/primitives/`.
3. Export it from [src/lib.zig](/Users/s3nik/Desktop/blender-zig/src/lib.zig).
4. Add focused tests in the touched module.
5. If the feature is demonstrable, add a CLI surface in [src/main.zig](/Users/s3nik/Desktop/blender-zig/src/main.zig).
6. Update [status/hyperdata.json](/Users/s3nik/Desktop/blender-zig/status/hyperdata.json) and run `npm run status:update` if the project state changed.
7. Run `zig build test` and one real CLI invocation.

## Current Boundaries

These are deliberate limits, not oversights:

- no renderer
- no viewport
- no editor UI
- no Blender file compatibility claim
- no DNA/RNA port
- no full dependency graph

Those would be different projects. The current repo is proving out core geometry and execution slices first.

For the staged path from this geometry kernel toward a usable standalone tool, see [docs/implementation-plan.md](/Users/s3nik/Desktop/blender-zig/docs/implementation-plan.md).

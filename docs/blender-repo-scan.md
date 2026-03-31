# Blender Repo Scan

This note turns the upstream Blender scan into a practical rewrite order for `blender-zig`.

## What Was Scanned

The local upstream mirror was inspected in these roots:
- `source/blender/blenlib`
- `source/blender/blenlib/tests`
- `source/blender/geometry`
- `source/blender/geometry/tests`
- `source/blender/blenkernel`
- `source/blender/nodes`

The current Zig repo already covers a narrow subset inspired by:
- `BLI_disjoint_set.hh`
- `BLI_offset_indices.hh`
- `mesh_primitive_line.cc`
- `mesh_primitive_grid.cc`
- `mesh_primitive_cuboid.cc`
- `mesh_primitive_uv_sphere.cc`

## What The Scan Says

### `blenlib` is broad and reusable

`blenlib/tests` contains a large test surface for containers, math, and utility types. That makes it a good source of small, independent ports, but it is too broad to chase randomly.

Best near-term uses:
- keep expanding vector, bounds, and container parity only when a geometry subsystem needs them
- prefer test-backed ports like `BLI_disjoint_set_test.cc` and `BLI_offset_indices_test.cc`

### `geometry` is the best next step

`geometry/tests` is small and focused:
- `GEO_merge_curves_test.cc`
- `GEO_interpolate_curves_test.cc`
- `GEO_realize_instances_test.cc`

Those files define the cleanest next subsystem because they are:
- geometry-heavy rather than UI-heavy
- bounded enough to port into Zig incrementally
- strongly test-driven

### `blenkernel` is useful for data-model references, not a first port target

`blenkernel` has many tests, but most pull in larger runtime assumptions. It should inform data-model design, especially for curves and attributes, without becoming the next direct port.

### `nodes` should stay minimal for now

The existing Zig graph kernel is enough as scaffolding. A serious nodes port should come only after curves and instances have a stable data model.

## Recommended Port Order

### 1. Curves kernel

Build a narrow `CurvesGeometry` equivalent with:
- point positions
- curve offsets
- cyclic flags
- a tiny point-attribute store

Why first:
- it unlocks both merge and interpolation work
- the test inputs are compact
- it exercises the offset-index infrastructure already ported

### 2. Merge curves

Port behavior from `GEO_merge_curves_test.cc`.

This is the best immediate target because it is mostly:
- topology
- remapping
- cyclic bookkeeping

It does not require a renderer, scene graph, or Blender object model.

### 3. Interpolate curves

Port the sampling behavior from `GEO_interpolate_curves_test.cc`.

This extends the same curves core into:
- index/factor sampling
- reverse handling
- cyclic handling
- resampling semantics

### 4. Minimal instances realization

After curves exist, add just enough `GeometrySet` and `Instances` support to cover the regression in `GEO_realize_instances_test.cc`.

This should stay narrow:
- curves-first
- transform references only
- no broad scene or object ownership model yet

### 5. Nodes follow data, not the reverse

Once primitives, curves, and instances exist, the node graph can grow from a DAG shell into typed geometry operations.

## Explicit Deferrals

Do not target these yet:
- rendering engines
- viewport and editor code
- asset systems
- DNA/RNA reflection
- full dependency graph semantics
- `.blend` compatibility

Those are too coupled to make a credible early Zig rewrite slice.

## Ready-To-Start Tickets

Completed on the first rewrite track:

1. Add `src/geometry/curves.zig` with offsets, cyclic flags, positions, and point attributes.
2. Add tests ported from `GEO_merge_curves_test.cc`.
3. Implement `curves_merge_endpoints`.
4. Add tests ported from `GEO_interpolate_curves_test.cc`.
5. Implement curve sampling and interpolation helpers.
6. Add a minimal `GeometrySet` and `Instances` layer only after curves pass.
7. Extend the node graph into typed, evaluable primitive mesh operations.

Next:

8. Extend `GeometrySet` so node evaluation can move beyond mesh-only values.
9. Add mixed curves and mesh evaluation tests that cross the realization boundary.
10. Keep the node API narrow while admitting shared geometry values.

# Zig Rewrite Backlog

## Discovery
- [x] scan Blender source roots relevant to the first rewrite
- [x] identify the smallest test-driven next slices in `blenlib` and `geometry`
- [x] document the recommended port order in `docs/blender-repo-scan.md`

## Phase 0: Repo bootstrap
- [x] define autonomous team operating model
- [x] add loop scripts and release scaffolding
- [x] create Zig package layout and build entrypoint
- [x] add a tiny `zig test` smoke target

## Phase 1: Mesh and primitive slice
- [x] implement 3D vector and bounds helpers
- [x] implement offset index utilities
- [x] implement disjoint-set union
- [x] port line mesh primitive
- [x] port grid mesh primitive
- [x] port cuboid mesh primitive
- [x] port UV sphere mesh primitive
- [x] add OBJ export and CLI smoke path

## Phase 2: Verification baseline
- [x] add unit tests for math helpers
- [x] add unit tests for primitive builders
- [x] add unit tests for mesh and graph helpers
- [x] verify a real CLI run that emits an OBJ artifact

## Phase 3: Curves kernel
- [x] design a minimal `CurvesGeometry` type with offsets, cyclic flags, and point attributes
- [x] port the scenarios from `source/blender/geometry/tests/GEO_merge_curves_test.cc`
- [x] implement `curves_merge_endpoints`
- [x] preserve point remapping behavior through a `test_index` attribute

## Phase 4: Curve interpolation
- [x] implement sampling helpers inspired by `source/blender/geometry/tests/GEO_interpolate_curves_test.cc`
- [x] port same-length, shorter, longer, cyclic, and reverse sampling cases
- [x] keep interpolation tests data-driven so future curve types can reuse them

## Phase 5: Instances and realization
- [x] add a minimal `GeometrySet` and `Instances` representation
- [x] implement a narrow `realize_instances` path for curves-first geometry
- [x] port the regression from `source/blender/geometry/tests/GEO_realize_instances_test.cc`

## Phase 6: Nodes and evaluation
- [x] extend the current node graph into typed sockets and evaluable operations
- [x] map primitive builders into executable node ops
- [x] add deterministic graph evaluation tests

## Phase 7: Geometry bridge
- [ ] extend `GeometrySet` beyond the curves-first slice without copying Blender's full component registry
- [ ] allow node evaluation to exchange shared geometry values instead of mesh-only outputs
- [ ] add mixed mesh and curves regression tests around realization boundaries

## Phase 8: Release and governance
- [ ] add conventional commit examples
- [x] wire semantic-release in CI
- [x] document signed-commit expectations and limitations

## Explicit deferrals
- [ ] do not touch rendering, viewport, or UI/editor code yet
- [ ] do not port DNA/RNA, asset systems, or the full dependency graph yet
- [ ] do not claim file-format or production compatibility yet

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
- [x] extend `GeometrySet` beyond the curves-first slice without copying Blender's full component registry
- [x] allow node evaluation to exchange shared geometry values instead of mesh-only outputs
- [x] add mixed mesh and curves regression tests around realization boundaries

## Phase 8: Curves In Nodes
- [x] add a minimal curve-producing node that outputs `GeometrySet`
- [x] add a narrow `realize_instances` node op for curve-first geometry
- [x] port node-level mixed mesh and curves realization tests

## Phase 9: Distribution And References
- [x] document and automate the local `blender-reference` remote setup
- [x] add release packaging scripts for optimized native artifacts
- [x] add macOS signing scaffolding without requiring secrets locally
- [x] add a macOS artifact workflow that validates optimized builds in CI
- [ ] add notarization once Apple credentials exist

## Phase 10: Runnable Graph Demo
- [x] export mixed mesh and curves `GeometrySet` values as a single OBJ
- [x] add a fixed `graph-demo` CLI command that exercises the node runtime end to end
- [x] add reader-facing progress artifacts and screenshot-style status surfaces

## Phase 11: Direct Curve Modeling
- [x] extend curves-to-mesh beyond loose wires with a bounded sweep path
- [x] add direct `curve-wire` and `curve-tube` CLI commands that do not depend on the graph demo
- [x] expose mesh-to-curve and curves-to-mesh roundtrips through the CLI

## Phase 12: Release and governance
- [ ] add conventional commit examples
- [x] wire semantic-release in CI
- [x] document signed-commit expectations and limitations

## Phase 13: Direct mesh ops
- [x] add a bounded triangulate op for the current face-corner mesh model
- [x] expose `mesh-triangulate` through the CLI
- [x] port a bounded `merge-by-distance` cleanup pass with face and loose-edge remapping
- [x] port a bounded individual-face inset path with UV-preserving face generation
- [x] port a bounded dissolve-edge pass that merges two manifold faces into one ngon
- [x] port a bounded individual-face extrude along the face normal
- [x] port a bounded open-region extrude that bridges only the outer boundary
- [x] port a bounded planar region inset that offsets one open face region inward
- [x] port a limited planar dissolve pass for coplanar shared edges
- [x] port a bounded face subdivision pass with shared edge midpoints
- [x] port a bounded face delete/edit pass that keeps the deleted region border as loose wire
- [x] port a bounded delete-loose cleanup pass that removes loose edges and isolated points
- [x] port another narrow mesh op such as bevel-like growth or a constrained edge/face selection edit

## Phase 14: Composable local authoring
- [x] add a bounded mesh pipeline CLI that chains existing primitives and ops
- [x] add parameterized pipeline steps instead of fixed defaults
- [x] add a persisted scene or recipe format beyond argv tokens
- [x] add multiple recipe studies that cover different direct-ops authoring patterns
- [x] add recipe-level seed overrides so saved studies can vary primitive resolution and size
- [x] add bounded transform and array composition steps so scene-style studies can assemble repeated forms
- [x] add multi-part scene composition so authoring can combine more than one seed or imported asset in a single saved study
- [x] add part-level scene placement so composed studies can offset or rotate reused parts without mutating their source recipes

## Phase 15: Mesh IO surfaces
- [x] add ASCII PLY mesh export alongside OBJ
- [x] add one lightweight mesh import path to close the inspect-edit-export loop
- [x] add a narrow mixed mesh-plus-curves OBJ import path for `GeometrySet` roundtrips
- [ ] add non-OBJ export handling for mixed mesh-plus-curve geometry where the format semantics stay clear
- [ ] widen import beyond the narrow OBJ subset only when a concrete modeling need appears

## Phase 16: Directed modeling and phase execution

Execution surface: [tasks/phase-16.md](/Users/s3nik/Desktop/blender-zig/tasks/phase-16.md)
Phase charter: [openspec/daily-driver/phases/phase-16-modeling-stack.md](/Users/s3nik/Desktop/blender-zig/openspec/daily-driver/phases/phase-16-modeling-stack.md)
Constrained-edit spec: [openspec/daily-driver/slices/phase-16-delete-edge.md](/Users/s3nik/Desktop/blender-zig/openspec/daily-driver/slices/phase-16-delete-edge.md)

- [x] define the exact `mesh-fill-hole` scope and regression matrix for one simple planar boundary loop
- [x] port `mesh-fill-hole` with direct CLI and pipeline coverage
- [x] define the exact bounded bevel-like growth slice and regression matrix for the current face-corner mesh
- [x] port one bounded bevel-like topology-growth op with direct CLI and pipeline coverage
- [x] define the constrained selection edit contract in `openspec/daily-driver/slices/phase-16-delete-edge.md`
- [x] port one constrained selection edit that pairs with the current delete/inset/extrude stack
- [x] add edit-heavy `.bzrecipe` studies that exercise the new phase-16 stack
- [x] add one `.bzscene` composition that reuses the new edit-heavy studies
- [x] allow the Ralph/operator workflow to target `tasks/phase-16.md` as an intentional phase run surface
- [x] refresh generated status surfaces once the phase-16 slices land

## Phase 17: Scene persistence and mixed packaging

Execution surface: [tasks/phase-17.md](/Users/s3nik/Desktop/blender-zig/tasks/phase-17.md)

- [x] add replay metadata and authored persistence studies so saved recipes and scenes replay from disk with stable identity
- [x] verify the phase through bundle reopen, clear missing-scene-part failure, and clean-room determinism
- [x] add a manifest-based bundle format for mixed mesh-plus-curve scenes with explicit roundtrip semantics
- [x] add roundtrip regression tests for mesh-only, curve-only, and mixed scenes
- [x] keep the phase documented and runnable through the existing CLI/status tooling

## Phase 18: App shell foundation

Execution surface: [tasks/phase-18.md](/Users/s3nik/Desktop/blender-zig/tasks/phase-18.md)

- [x] define the minimum native app shell and read-only shell session floor for launchable local open flows
- [x] add a small app shell that loads a study, scene, or bundle without routing everything through ad hoc CLI flags
- [x] bridge the current geometry kernel into the app shell command path through a bundled helper binary
- [x] add the bounded inspect/save loop before viewport work: inspect recipe, scene, and bundle metadata; save `title` in place for `.bzrecipe` and `.bzscene`; keep `.bzbundle` inspect-only
- [x] close the phase with conflict-safe save rejection, Ralph/team dry-run coverage, and an explicit phase-19 viewport launch slice

## Phase 19: Viewport and interaction MVP

Execution surface: [tasks/phase-19.md](/Users/s3nik/Desktop/blender-zig/tasks/phase-19.md)

- [ ] add a minimal viewport with orbit, pan, and zoom
- [x] add object focus and one primitive-backed create path before widening into element inspection
- [x] add translate, rotate, and scale interaction over the current geometry kernel
- [ ] expose a narrow set of direct modeling ops through the interaction layer

## Phase 20: Daily-driver hardening

Execution surface: [tasks/phase-20.md](/Users/s3nik/Desktop/blender-zig/tasks/phase-20.md)

- [ ] harden project/session reopen flows so real local work can be resumed without reconstruction
- [ ] expand regression coverage around modeling, persistence, and interaction
- [ ] package optimized local macOS builds that are easy to rerun and compare across versions
- [ ] keep the daily-driver spec and the execution backlog aligned as the app shell matures

## Explicit deferrals
- [ ] do not widen beyond the bounded phase-19 viewport MVP into full editor UI, rendering polish, or production rendering features yet
- [ ] do not port DNA/RNA, asset systems, or the full dependency graph yet
- [ ] do not claim file-format or production compatibility yet

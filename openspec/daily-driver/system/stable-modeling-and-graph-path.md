# Stable Modeling And Graph Path

This file answers a narrower question than the daily-driver contract:

- what is the shortest path from the current repo state to a meaningful stable
  version on Apple Silicon
- what is the fastest honest path to "geometry nodes" without widening into a
  full node-editor rewrite

The answer is not "build a Blender-style editor now." The answer is to finish a
small object-centric modeling loop first, then promote the existing graph
runtime into a saved text-backed authoring surface.

## File-Format Rule

The stable-version path should keep two classes of formats distinct:

- `.bzrecipe`, `.bzscene`, future `.bzgraph`, and `.bzbundle/` are internal
  authored or packaged state
- OBJ, PLY, and future widened interchange targets are external handoff formats

That means we should not hide editable work in opaque bundles, but we also
should not confuse universal/export formats with canonical authored state.

## Meaningful Stable-Version Bar

The first meaningful stable version should let a user do all of these on an
M1/M2/M3-class Mac without leaving the documented shell path:

1. launch `zig-out/BlendZigShell.app`
2. create one primitive-backed study from inside the app
3. focus one object and inspect its identity and properties
4. translate, rotate, and scale that object
5. save, reopen, and export the result
6. open one graph-backed saved study and preview its evaluated output
7. tweak a bounded set of graph parameters and rerun the same helper-backed path

Anything smaller than that is still a promising prototype. Anything much larger
than that risks turning phase 19 into editor theater.

## Critical-Path Order

1. close the viewport MVP with one human-confirmed orbit, pan, and zoom pass on
   `recipes/phase-19/viewport-gallery.bzscene`
2. land object focus plus primitive creation so the shell can start work, not
   only replay work
3. land persisted translate, rotate, and scale over the focused object
4. expose one existing direct modeling op through the same interaction model
5. promote the existing node runtime into a saved graph-backed study surface
6. add narrow shell parameter editing for numeric graph fields
7. harden recovery, packaging, and second-machine proof in phase 20

## Why This Order Wins

- primitive creation is the first step that makes the native shell feel like a
  tool instead of a replay viewer
- transforms are only meaningful after the shell can focus one bounded target
- direct modeling exposure should ride on the same selection and persistence
  path instead of inventing a parallel interaction layer
- the node runtime already exists, so the shortest geometry-node bridge is a
  saved graph study, not a visual node canvas
- packaging and handoff matter, but they should harden a working modeling loop
  instead of masking missing authoring semantics

## Fastest Geometry-Node Bridge

The repo already has real graph execution in `src/nodes/graph.zig`. The missing
piece is not evaluation. The missing piece is a persisted, replayable work unit.

The intended bridge is:

- add one saved graph file surface, likely `.bzgraph`
- keep it text-first with `format-version`, `id`, `title`, nodes, typed edges,
  and output metadata
- add one helper replay command that evaluates the graph and writes deterministic
  geometry output
- let the shell open and inspect graph studies through the same helper-backed
  path already used for recipes and scenes
- start with parameter editing for numeric node fields before any node-canvas UI

This turns "graph-demo" into a reusable authoring surface while preserving the
current design rule that saved work stays understandable and replayable from the
CLI.

## Design Constraint

Graph-backed studies should enter the system as a study subtype, not as a fourth
opaque project model. They must reuse the same replay metadata, shell-open
bridge, viewport preview path, and save/reopen expectations that already exist
for `.bzrecipe` and `.bzscene`.

## Explicit Deferrals

Do not widen into any of these until the stable-version bar above is real:

- full node-canvas editing
- Blender-style modifier stack parity
- element-level edit modes beyond the bounded object-focused loop
- asset browser or dependency-graph rewrites
- rendering or viewport polish work that does not strengthen modeling flow

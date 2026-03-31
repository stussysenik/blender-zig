# Implementation Plan

This repo is not trying to outrun Blender by rewriting everything at once. The long-term plan is to grow a usable native Zig geometry application in layers, keeping each layer runnable before moving wider.

## Stage 1: Core geometry kernel

Status: largely in place.

This stage establishes the minimal data model and the first executable ports:

- vector math and bounds
- mesh topology with face-corner storage
- curves, instances, and a narrow `GeometrySet`
- primitive generators
- OBJ export
- test-backed direct mesh and curve ops

The current repo is solidly inside this stage and already spills into stage 2.

## Stage 2: Modeling operations

Status: active.

This is where `blender-zig` starts to feel like a modeling tool instead of a geometry sandbox. The target is a small but coherent set of direct operations that can be chained from the CLI and later from a scene layer.

Current ops in tree:

- triangulate
- merge by distance
- inset
- shared-edge dissolve
- individual-face extrude
- limited planar dissolve
- face subdivision with shared edge midpoints
- mesh-to-curve and curve-to-mesh conversions

Next high-value ports:

- delete/cleanup passes
- bevel-like topology growth
- region-style operations that go beyond individual-face processing

## Stage 3: Scene and evaluation layer

Status: partially in place.

The lightweight node graph and `GeometrySet` work are here to make sure geometry can flow through a higher-level evaluation model without pulling in Blender's full dependency graph yet.

The practical goal is:

- multiple runnable scene recipes instead of one fixed demo
- reusable graph ops around the direct geometry kernels
- realization and mixed mesh/curve behavior that stays deterministic

## Stage 4: Native application shell

Status: early.

Today `blender-zig` is a native macOS CLI. The next step toward an application is not a renderer first; it is a stronger authoring/runtime shell:

- scene recipe loading
- richer export paths beyond OBJ
- repeatable packaging and release artifacts
- code signing and notarization for distribution

This is the point where the project becomes easy to run and inspect outside the development loop.

## Stage 5: Much later work

These are intentionally deferred:

- viewport and editor UI
- rendering
- Blender file compatibility claims
- DNA/RNA and the full dependency graph

Those are major projects on top of the geometry kernel, not prerequisites for proving that Zig is a good fit.

## Distance From A Usable `blender-zig`

There are two honest answers:

- Usable as a native Zig geometry tool: yes, now.
- Usable as a real Blender replacement: not close yet.

What exists today is enough to build, test, export, and inspect geometry features natively on macOS. What does not exist yet is the broader modeling stack, scene authoring layer, file compatibility story, and application shell needed for a day-to-day Blender-class workflow.

The nearest credible milestone is not "replace Blender." It is:

1. a coherent direct-ops modeling CLI
2. a small scene/evaluation layer that can compose those ops
3. one additional export path and repeatable packaged artifacts

Once those are in place, `blender-zig` becomes a serious standalone geometry application rather than only a rewrite experiment.

The new short-term bridge between 1 and 2 is a composable mesh pipeline CLI: one seed mesh plus a bounded, parameterized stack of existing ops, still without pretending we already have Blender's full scene model.

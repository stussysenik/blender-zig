# Vision

## Goal

Move `blender-zig` from a runnable geometry CLI into a realistic daily-driver modeling workspace that can replace a meaningful subset of Blender work on macOS.

## Problem

`blender-zig` is already beyond the bootstrap stage, but it is still primarily a well-tested geometry kernel and authoring CLI. The missing pieces are not just more operators. The missing pieces are persisted authoring semantics, interaction, recovery, and product hardening.

## What Daily-Driver Means

A daily-driver `blender-zig` must satisfy all of these:

- launch from a fresh clone and documented build path on macOS without local source edits
- create, import, edit, save, and export mesh and curve data
- keep authored state readable and keep external handoff on documented universal/open formats
- support repeatable studies or scenes instead of one-off demos
- run the core modeling loop deterministically from the CLI or a small native shell
- provide a minimal viewport and interaction path for inspection and transforms
- produce optimized release builds and packaged artifacts
- remain understandable enough that a new contributor can follow the active slice from docs to tests to implementation

## What It Is Not

- not a full Blender UI clone
- not a renderer-first project
- not a claim of file-format parity with Blender
- not a broad asset-system or dependency-graph rewrite before the modeling core is complete
- not a plugin ecosystem project

## Non-Goals For This Bundle

- do not expand scope into viewport polish before the core modeling path is stable
- do not promise every Blender operator
- do not widen import/export beyond what supports a concrete modeling use case
- do not treat documentation as a substitute for runnable slices

## Current Anchor

The current repo already has:

- primitive mesh generation
- curves and curve-to-mesh work
- direct mesh ops
- recipe and scene surfaces
- macOS packaging scaffolding

The remaining work is to make those pieces into a stable, repeatable modeling tool with a small app shell instead of a collection of isolated commands.

## Constraints

- keep the work executable in bounded slices
- keep the geometry kernel test-backed
- map planning surfaces back to runnable task files and loop commands
- prefer honest scope over rewrite theater

## Risks

- scope risk: “rewrite Blender” language can erase the actual critical path
- architecture risk: adding a viewport before persistence and undo are stable will cause churn
- workflow risk: if the spec, status surfaces, and task files diverge, the loop becomes noise instead of execution

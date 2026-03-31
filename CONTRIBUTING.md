# Contributing

This repo moves best when changes are narrow, test-backed, and visible through a real runtime path.

## Toolchain

- Zig `0.15.2` or newer
- Node.js `20` or newer for status and release tooling
- macOS is the currently verified host, though the core Zig code is kept portable where practical

## First 20 Minutes

If you are new here:

1. Read [ARCHITECTURE.md](/Users/s3nik/Desktop/blender-zig/ARCHITECTURE.md).
2. Read [tasks/zig-rewrite.md](/Users/s3nik/Desktop/blender-zig/tasks/zig-rewrite.md).
3. Run `zig build test`.
4. Run one CLI command such as `zig build run -- curve-tube zig-out/curve-tube.obj`.
5. Run `zig build run -- mesh-pipeline --recipe recipes/grid-study.bzrecipe`.
6. Run one inline override example such as `zig build run -- mesh-pipeline grid:verts-x=8,verts-y=5,size-x=4.0,size-y=2.0 subdivide:repeat=2 extrude:distance=0.75`.
7. Run one scene-style recipe such as `zig build run -- mesh-pipeline --recipe recipes/courtyard-plaza-study.bzrecipe`.
8. Open [src/main.zig](/Users/s3nik/Desktop/blender-zig/src/main.zig), [src/pipeline.zig](/Users/s3nik/Desktop/blender-zig/src/pipeline.zig), and the module behind the step you want to study.

That gets you from zero to a concrete, debuggable feature slice quickly.

## Working Style

- prefer one meaningful subsystem slice per commit
- add tests in the same module you touch
- keep comments reader-facing and only around non-obvious ownership, topology, or data-alignment behavior
- prefer direct geometry ops over adding more workflow machinery
- do not widen scope into UI, rendering, or file-compatibility claims

## Local Loop

The standard local loop is:

```bash
zig build test
zig build run -- <command> [output.obj]
zig build run -- mesh-pipeline grid:verts-x=8,verts-y=5,size-x=4.0,size-y=2.0 subdivide:repeat=2 extrude:distance=0.75
zig build run -- mesh-pipeline --recipe recipes/grid-study.bzrecipe
zig build run -- mesh-pipeline --recipe recipes/courtyard-plaza-study.bzrecipe
zig build run -- mesh-pipeline --recipe recipes/tower-stack-study.bzrecipe
zig build run -- mesh-pipeline --recipe recipes/cuboid-facet-study.bzrecipe
zig build run -- mesh-import zig-out/sphere.obj zig-out/sphere-roundtrip.obj
zig build run -- graph-demo zig-out/graph-demo.obj
zig build run -- geometry-import zig-out/graph-demo.obj zig-out/graph-demo-roundtrip.obj
npm run status:update
npm run status:check
npm run status:live
```

Use `npm run status:update` only when the repo's reported state actually changed. It regenerates:

- [README.md](/Users/s3nik/Desktop/blender-zig/README.md)
- [progress.md](/Users/s3nik/Desktop/blender-zig/progress.md)
- [ROADMAP.md](/Users/s3nik/Desktop/blender-zig/ROADMAP.md)

The source of truth for those generated sections is [status/hyperdata.json](/Users/s3nik/Desktop/blender-zig/status/hyperdata.json).
Use `npm run status:live` when you want the current git branch and commit instead of the committed status surfaces.

## Where To Put Code

- new primitive generators: `src/geometry/primitives/`
- mesh or curve ops: `src/geometry/`
- mixed geometry behavior: `src/geometry/realize_instances.zig`
- mesh-space transforms and array composition: `src/geometry/mesh_transform.zig`
- export paths: `src/io/`
- runnable demos or CLI surfaces: `src/main.zig`
- public exports: `src/lib.zig`

If you add a new public feature and forget to export it from [src/lib.zig](/Users/s3nik/Desktop/blender-zig/src/lib.zig), the repo becomes harder to read and use. Treat that export step as part of the feature.

## Verification Standard

Before pushing:

1. Run `zig build test`.
2. Run at least one real CLI command that touches your new code.
3. If status changed, run `npm run status:update` and `npm run status:check`.
4. Read the command output instead of assuming success.

## Branches And Commits

- keep `main` green
- use short-lived feature branches or worktrees for larger slices
- use Conventional Commit prefixes when possible
- signed commits are preferred when signing is configured, but not required for local development

## Reference Repo

The Blender fork is a local reference, not a second active workspace for this rewrite.

Set it up with:

```bash
npm run reference:setup
```

That adds the local `blender-reference` remote on this machine so upstream ports can be traced back to their source.

## Good First Contributions

- tighten a geometry op already in `src/geometry/`
- add a missing regression test from the Blender-inspired slice we already started
- add a new CLI-visible mesh or curve operation
- improve contributor docs when a runtime path is hard to understand

## Things To Avoid

- large speculative refactors without tests
- new dependencies
- abstract frameworks around tiny code paths
- silent changes to generated status docs without updating `status/hyperdata.json`

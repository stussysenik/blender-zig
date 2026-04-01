# Tech Stack

This file records the actual stack in use for `blender-zig` today and the
deliberate boundaries for the next daily-driver phases. It is not a wishlist.

## Product Layer

- target product: local-first 3D authoring tool on macOS
- current shipped surface: native CLI executable, saved study files, saved scene files
- planned next surfaces:
  - phase 17: persisted replay metadata and mixed-scene bundles
  - phase 18: minimal native shell
  - phase 19: minimal viewport and narrow interaction tools

## Core Language And Runtime

- language: Zig
- minimum Zig version: `0.15.2`
- Zig dependency policy today: standard library only, no external Zig packages in `build.zig.zon`
- build entrypoints:
  - [build.zig](/Users/s3nik/Desktop/blender-zig/build.zig)
  - [build.zig.zon](/Users/s3nik/Desktop/blender-zig/build.zig.zon)

## Geometry And Authoring Stack

- core geometry kernel: Zig modules under [src/](/Users/s3nik/Desktop/blender-zig/src)
- data domains:
  - mesh
  - curves
  - geometry sets
  - scene composition
- current authoring surfaces:
  - direct CLI commands in [src/main.zig](/Users/s3nik/Desktop/blender-zig/src/main.zig)
  - saved `.bzrecipe` studies parsed by [src/pipeline.zig](/Users/s3nik/Desktop/blender-zig/src/pipeline.zig)
  - saved `.bzscene` compositions parsed by [src/scene.zig](/Users/s3nik/Desktop/blender-zig/src/scene.zig)
- current import and export formats:
  - ASCII OBJ
  - ASCII PLY for mesh-only output
- interchange policy:
  - `.bz*` stays internal authored state
  - external handoff prefers universal/open formats with explicit semantics
  - the next widened external target should be chosen after the object-create and transform loop is stable

## Local Tooling

- shell tooling: Bash scripts under [scripts/](/Users/s3nik/Desktop/blender-zig/scripts)
- package metadata and repo automation: Node.js `>=20` via [package.json](/Users/s3nik/Desktop/blender-zig/package.json)
- release helpers:
  - semantic-release
  - commitlint
  - macOS packaging and signing scripts
- planning and execution surfaces:
  - markdown task files under [tasks/](/Users/s3nik/Desktop/blender-zig/tasks)
  - OpenSpec docs under [openspec/daily-driver/](/Users/s3nik/Desktop/blender-zig/openspec/daily-driver)
  - Ralph/team loop scripts for sequential and tmux-backed execution

## Verification Stack

- library verification: `zig test src/lib.zig`
- CLI verification: `zig test --dep blendzig -Mroot=src/main.zig -Mblendzig=src/lib.zig`
- local end-to-end entrypoint: [scripts/verify-local.sh](/Users/s3nik/Desktop/blender-zig/scripts/verify-local.sh)
- phase-16 entrypoint: [scripts/verify-phase-16.sh](/Users/s3nik/Desktop/blender-zig/scripts/verify-phase-16.sh)
- macOS arm64 note:
  - local verification currently pins `aarch64-macos.15.0` when needed because the native Homebrew Zig `0.15.2` runner mislinks on the macOS 26 host target in this environment

## File And Workflow Formats

- study format: line-oriented `.bzrecipe`
- scene format: line-oriented `.bzscene`
- portable bundle format: `.bzbundle/` directory with `manifest.bzmanifest` and `geometry.obj`
- interchange formats:
  - ASCII OBJ for current mixed geometry handoff
  - ASCII PLY for current mesh-only handoff
  - broader scene interchange is intentionally deferred until object creation, transforms, and graph-backed studies are stable
- backlog format: markdown checklist task files
- status source of truth: [status/hyperdata.json](/Users/s3nik/Desktop/blender-zig/status/hyperdata.json)
- generated status surfaces:
  - [README.md](/Users/s3nik/Desktop/blender-zig/README.md)
  - [progress.md](/Users/s3nik/Desktop/blender-zig/progress.md)
  - [ROADMAP.md](/Users/s3nik/Desktop/blender-zig/ROADMAP.md)

## Daily-Driver Boundaries

- persistence format for phase 17: replay metadata is in, and the first portable bundle unit is `.bzbundle/`; full project/session state is still not defined
- universal-format rule: authored state remains `.bz*`, but anything handed outside the app should prefer documented open formats over opaque app-only files
- native shell toolkit for phase 18: not chosen in-repo yet
- viewport implementation for phase 19: not chosen in-repo yet

Those undecided pieces are intentional. The current contract is to keep the
stack narrow until persisted project state is real.

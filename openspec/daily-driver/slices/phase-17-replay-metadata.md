# Phase 17 Slice: Replay Metadata

## Goal

Define the smallest durable metadata layer for `.bzrecipe` and `.bzscene` so
saved studies and scenes have explicit replay identity before the repo widens
into bundle manifests or shell state.

## Scope

In scope:

- optional replay metadata lines for recipes and scenes
- version-checked parsing for the metadata layer
- direct CLI replay of metadata-bearing recipe and scene files
- one runtime roundtrip smoke path through exported OBJ plus `mesh-import`

Out of scope:

- bundle manifests
- autosave or session state
- project containers
- new selection semantics beyond the current recipe and scene grammars

## Metadata Contract

Supported optional keys:

- `format-version=1`
- `id=<stable replay id>`
- `title=<human-readable title>`

Rules:

- `format-version` currently accepts only `1`
- `id` must be stable and machine-friendly
- `title` is for human readout and may contain spaces
- duplicate metadata keys fail narrowly
- missing metadata keeps the old replay path valid

## Acceptance Criteria

This slice is complete only when all of these are true:

- `.bzrecipe` and `.bzscene` accept the replay metadata keys above
- unsupported metadata versions fail with a clear parse error
- `mesh-pipeline --recipe ...` and `mesh-scene --recipe ...` still replay from disk
- metadata-bearing replay files produce visible runtime output
- one scene replay can roundtrip through OBJ export and `mesh-import`

## Verification

```bash
bash scripts/verify-phase-17.sh
./zig-out/bin/blender-zig-direct mesh-pipeline --recipe recipes/phase-16/wire-rebuild.bzrecipe --write zig-out/phase-17-wire-rebuild.obj
./zig-out/bin/blender-zig-direct mesh-scene --recipe recipes/phase-16/modeling-bench.bzscene --write zig-out/phase-17-modeling-bench.obj
./zig-out/bin/blender-zig-direct mesh-import zig-out/phase-17-modeling-bench.obj zig-out/phase-17-modeling-bench-roundtrip.obj
```

## Follow-On Slice

The next phase-17 slice after this one is the manifest-based mixed-geometry
bundle format. Do not widen into shell or viewport work before that format is
explicit.

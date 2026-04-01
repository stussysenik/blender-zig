# Phase 17 Slice: Bundle Format

## Goal

Add the smallest portable bundle unit that can reopen mesh-only, curve-only, and
mixed geometry on an M-series Mac without depending on ad hoc shell state.

## Scope

In scope:

- one directory-backed `.bzbundle` format
- one line-oriented manifest
- one bundled `geometry.obj` payload using the existing `GeometrySet` OBJ path
- CLI pack and open commands
- mesh-only, curve-only, and mixed bundle roundtrips

Out of scope:

- project containers
- autosave
- undo history
- asset-reference rebasing
- shell or viewport work

## Bundle Contract

Bundle shape:

- `<name>.bzbundle/`
- `manifest.bzmanifest`
- `geometry.obj`

Manifest keys:

- `format-version=1`
- optional `id`
- optional `title`
- `kind=geometry-bundle`
- `geometry-format=obj`
- `geometry-path=geometry.obj`
- `components=mesh`, `components=curves`, or `components=mesh,curves`

Rules:

- the bundle is portable because the manifest points at a relative payload path
- the payload is deliberately OBJ because mixed `GeometrySet` OBJ roundtrips already exist
- manifest component claims must match the reopened payload
- unsupported future manifest versions fail narrowly

## Acceptance Criteria

This slice is complete only when all of these are true:

- the repo can pack an imported OBJ geometry file into a `.bzbundle`
- the repo can reopen that bundle and export the contained geometry again
- mesh-only, curve-only, and mixed geometry all roundtrip through the bundle path
- the bundle path is covered by tests and by one phase-level verification script

## Verification

```bash
bash scripts/verify-phase-17.sh
./zig-out/bin/blender-zig-direct geometry-bundle-pack zig-out/phase-17-bundle-mixed.obj zig-out/phase-17-bundle-mixed.bzbundle
./zig-out/bin/blender-zig-direct geometry-bundle-open zig-out/phase-17-bundle-mixed.bzbundle zig-out/phase-17-bundle-mixed-roundtrip.obj
./zig-out/bin/blender-zig-direct geometry-import zig-out/phase-17-bundle-mixed-roundtrip.obj zig-out/phase-17-bundle-mixed-reimport.obj
```

## Follow-On Slice

The next phase-17 work after this is study coverage over the new persistence
path, then workflow follow-through. Do not jump to shell work before those are
green.

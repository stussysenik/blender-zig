# Phase 19 Slice: Viewport MVP Launch

## Goal

Add the smallest visual surface so a user can open one saved work unit in the
native shell and inspect it with orbit, pan, and zoom on a Mac without
reconstructing geometry outside the current helper-backed path.

## Scope

In scope:

- one viewport panel embedded in the existing macOS shell
- one mesh-backed saved `.bzrecipe` or `.bzscene` rendered in-app after replay
- deterministic orbit, pan, zoom, and one camera reset path
- one concrete saved work unit used for local reruns and smoke verification:
  `recipes/phase-19/viewport-gallery.bzscene`

Out of scope:

- bundle or curve-first viewport support
- selection, transforms, or direct modeling interaction
- save operations from the viewport
- renderer abstraction or performance tuning beyond the MVP floor

## Acceptance Criteria

This slice is complete only when all of these are true:

- the built app can open one saved recipe or scene and show its geometry in a
  viewport without leaving the shell
- orbit, pan, and zoom work over that geometry with a deterministic starting
  camera
- the viewport still depends on the existing helper-backed geometry path rather
  than forking scene or mesh construction into UI code
- phase-19 tasks and generated docs point at one concrete viewport MVP instead
  of wider editor or rendering ambitions

## Planned Verification

```bash
bash scripts/verify-phase-19.sh
bash scripts/demo-phase-19.sh
open zig-out/BlendZigShell.app
```

## Follow-On Slice

Once the viewport launch floor is stable, the next honest work is
[openspec/daily-driver/slices/phase-19-object-focus-and-primitive-creation.md](/Users/s3nik/Desktop/blender-zig/openspec/daily-driver/slices/phase-19-object-focus-and-primitive-creation.md),
which keeps phase 19 object-focused before widening into element editing.

# Phase 19 Slice: Object Focus And Primitive Creation

## Goal

Add the smallest shell path that can start a modeling session instead of only
opening existing files: create one primitive-backed study, focus one object, and
inspect its current properties without widening into element editing.

## Scope

In scope:

- one object-focused interaction model in the native shell
- one bounded primitive creation path for starter geometry such as cuboid,
  cylinder, or sphere
- one saved study emitted from that creation path and reopened immediately
- one inspection surface that reports the focused object's identity and current
  high-level properties

Out of scope:

- element-level mesh selection
- full scene hierarchy editing
- graph-backed studies
- transform gizmos or modal editing beyond focus and inspection

## Acceptance Criteria

This slice is complete only when all of these are true:

- the shell can create one new primitive-backed study without manual file
  authoring outside the app
- the new study reuses the existing helper-backed replay path instead of
  bypassing it with UI-only geometry state
- the shell can focus exactly one bounded object and show its current
  inspectable properties
- the created study can be saved, reopened, and previewed through the same
  document path used for existing studies

## Planned Verification

```bash
swift test --package-path macos/BlendZigShell
bash scripts/build-phase-18-shell.sh
zig-out/BlendZigShell.app/Contents/MacOS/BlendZigShell --smoke-inspect recipes/phase-17/pocket-platform-study.bzrecipe
zig-out/BlendZigShell.app/Contents/MacOS/BlendZigShell --smoke-inspect recipes/phase-17/persistence-workbench.bzscene
zig-out/BlendZigShell.app/Contents/MacOS/BlendZigShell --smoke-create-primitive sphere zig-out/phase-19-starter-sphere.bzrecipe
bash scripts/verify-phase-19.sh
open zig-out/BlendZigShell.app
```

## Follow-On Slice

Once object focus and primitive creation are stable, the next honest work is
persisted translate, rotate, and scale over the same focused object model.

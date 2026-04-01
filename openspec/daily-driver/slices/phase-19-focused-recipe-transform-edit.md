# Phase 19 Slice: Focused Recipe Transform Edit

## Goal

Add the smallest persisted transform-edit path over the object-focused shell
model: edit `scale`, `rotate-z`, and `translate` for the focused root object of
one `.bzrecipe`, save those values back into the recipe text, and replay the
same helper-backed preview without losing focus.

## Scope

In scope:

- recipe-root transform editing only
- persisted `scale`, `rotate-z`, and `translate` values using the existing
  `.bzrecipe` `step=` grammar
- one shell editor surface with explicit save/reload behavior
- one helper-backed smoke path that proves the recipe is rewritten and replayed

Out of scope:

- scene-part placement editing
- viewport gizmos or drag handles
- element-level transforms
- non-transform step editing
- graph-backed transform editing

## Persistence Rule

The shell owns only a trailing transform block on `.bzrecipe` studies:

- zero or one trailing `step=scale:...`
- zero or one trailing `step=rotate-z:degrees=...`
- zero or one trailing `step=translate:...`

If a recipe has no trailing transform block, the shell may append one.

If a recipe interleaves transform steps with non-transform modeling steps, or
uses repeated transform steps in a way that the shell cannot rewrite without
changing semantics, transform editing must fail narrowly instead of guessing.

## Acceptance Criteria

This slice is complete only when all of these are true:

- the shell can inspect the current transform state for a focused recipe root
- the shell can save bounded transform values back into the same `.bzrecipe`
- saving replays through the existing helper path and keeps the same focused
  object selected
- the shell fails narrowly when the recipe transform history is outside this
  bounded rewrite contract

## Planned Verification

```bash
swift test --package-path macos/BlendZigShell
bash scripts/build-phase-18-shell.sh
zig-out/BlendZigShell.app/Contents/MacOS/BlendZigShell --smoke-create-primitive sphere zig-out/phase-19-starter-sphere.bzrecipe
zig-out/BlendZigShell.app/Contents/MacOS/BlendZigShell --smoke-save-recipe-transform zig-out/phase-19-starter-sphere.bzrecipe 1.2 1.1 0.9 22 2.5 -1.0 0.75
bash scripts/verify-phase-19.sh
open zig-out/BlendZigShell.app
```

## Follow-On Slice

Once focused recipe transform editing is stable, the next honest work is one
shell-exposed direct modeling op over the same focused object model.

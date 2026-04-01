# Phase 19 Slice: Focused Recipe Subdivide

## Goal

Expose the first direct modeling op through the native shell over the same
focused recipe-root model used by primitive creation and transform editing:
apply one bounded `subdivide` step to the focused `.bzrecipe` root without
breaking the trailing transform block.

## Scope

In scope:

- recipe-root modeling only
- one shell-exposed `subdivide` route over the focused object
- persistence through the existing `.bzrecipe` `step=` grammar
- replay through the bundled helper after the save path runs
- preservation of the current focus target and trailing transform editability

Out of scope:

- scene-part modeling
- element selection or edit mode
- arbitrary step reordering
- multiple modeling ops in one slice
- viewport gizmos or drag-based editing

## Persistence Rule

The shell may own one bounded trailing modeling step immediately before the
trailing transform block:

- zero or one `step=subdivide:repeat=1`
- followed by the existing trailing transform block contract:
  `scale`, `rotate-z`, and `translate`

If the recipe already has transform steps, the shell must keep them trailing.
If the recipe history around `subdivide` cannot be rewritten without guessing,
the shell must fail narrowly instead of mutating the file.

## Acceptance Criteria

This slice is complete only when all of these are true:

- the shell can detect whether the focused recipe already carries the bounded
  `subdivide` step it owns
- the shell can apply or rewrite that bounded step before the trailing transform
  block without losing transform editability
- the helper-backed preview reruns after the change and keeps the same focused
  object selected
- the shell fails narrowly when recipe history is outside the bounded rewrite
  contract

## Planned Verification

```bash
swift test --package-path macos/BlendZigShell
bash scripts/build-phase-18-shell.sh
zig-out/BlendZigShell.app/Contents/MacOS/BlendZigShell --smoke-create-primitive sphere zig-out/phase-19-starter-sphere.bzrecipe
zig-out/BlendZigShell.app/Contents/MacOS/BlendZigShell --smoke-save-recipe-transform zig-out/phase-19-starter-sphere.bzrecipe 1.2 1.1 0.9 22 2.5 -1.0 0.75
zig-out/BlendZigShell.app/Contents/MacOS/BlendZigShell --smoke-save-recipe-subdivide zig-out/phase-19-starter-sphere.bzrecipe on
zig-out/BlendZigShell.app/Contents/MacOS/BlendZigShell --smoke-save-recipe-subdivide zig-out/phase-19-starter-sphere.bzrecipe off
bash scripts/verify-phase-19.sh
open zig-out/BlendZigShell.app
```

## Follow-On Slice

Once one shell-exposed direct modeling op is stable, the next honest work is
`openspec/daily-driver/slices/phase-19-workflow-follow-through.md`.

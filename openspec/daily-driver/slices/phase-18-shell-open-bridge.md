# Phase 18 Slice: Shell Open Bridge

## Goal

Land the smallest launchable macOS shell that can open the current persistence
surfaces without inventing a second geometry runtime.

## Scope

In scope:

- one native macOS app bundle under `zig-out/`
- read-only open flows for `.bzrecipe`, `.bzscene`, and `.bzbundle`
- one bundled helper bridge back to `blender-zig-direct`
- one explicit shell session floor for the first launchable app slice
- package tests for shell request parsing and command mapping
- one smoke-run verifier for the built app bundle on arm64 macOS

Out of scope:

- save or export from the shell
- viewport rendering
- in-shell transforms or editing tools
- project containers beyond the current recipe, scene, and bundle surfaces

## Shell Session Floor

The first shell session is intentionally narrow:

- active document path
- active document kind
- last helper command that ran
- last helper stdout or stderr result
- last open failure, if any

No undo stack, autosave pointer, or viewport state exists in this slice.

## Bridge Rule

The shell must not replay geometry itself. It opens supported documents by
spawning the bundled `blender-zig-direct` helper with one of these stable paths:

- `.bzrecipe` -> `mesh-pipeline --recipe <path>`
- `.bzscene` -> `mesh-scene --recipe <path>`
- `.bzbundle` -> `geometry-bundle-open <path>`

## Acceptance Criteria

This slice is complete only when all of these are true:

- `bash scripts/build-phase-18-shell.sh` produces
  `zig-out/BlendZigShell.app`
- the shell can open supported documents through a native window on arm64 macOS
- the bundled helper path is explicit and test-backed instead of inferred from
  ad hoc shell state
- `bash scripts/verify-phase-18.sh` runs package tests, builds the app bundle,
  and smoke-opens one recipe, one scene, and one bundle through the shell
- phase-18 docs and task files point at the same launchable shell slice

## Verification

```bash
bash scripts/build-phase-18-shell.sh
bash scripts/verify-phase-18.sh
open zig-out/BlendZigShell.app
```

## Follow-On Slice

Once the shell can open current durable work, the next honest phase-18 slice is
the minimal inspect and save loop over the same persistence surfaces.

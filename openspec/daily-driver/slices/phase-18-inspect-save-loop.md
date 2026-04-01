# Phase 18 Slice: Inspect And Save Loop

## Goal

Add the smallest honest inspect/save loop to the native macOS shell so a
user can open authored work, inspect its durable metadata, edit one bounded
field, save it, and reopen it through the same helper-backed path.

## Scope

In scope:

- metadata inspection for `.bzrecipe`, `.bzscene`, and `.bzbundle`
- one structure summary per file kind
- one editable metadata field: `title`
- in-place `title` save for text-backed `.bzrecipe` and `.bzscene`
- `.bzbundle` manifest inspection remains read-only in this slice
- shell smoke commands and package tests for inspect, save, reopen, and
  bundle-save rejection

Out of scope:

- geometry edits from the shell
- bundle mutation
- viewport rendering
- project/session containers beyond current recipe, scene, and bundle files

## Inspect Floor

The shell inspect path must surface at least:

- document path
- document kind
- `format-version`
- `id`
- `title`
- one structure summary:
  - recipe: seed and step count
  - scene: part count
  - bundle: component set and payload path

## Save Floor

The shell save path is intentionally narrow:

- only `title` is editable
- saves happen in place on `.bzrecipe` and `.bzscene`
- if `title` is missing, the shell inserts it into the metadata block without
  disturbing the rest of the file order
- `.bzbundle` stays inspect-only because it is currently packaged state, not the
  primary authored work surface

## Acceptance Criteria

This slice is complete only when all of these are true:

- the shell can inspect recipe, scene, and bundle metadata through the
  documented file contracts
- the shell can edit and save `title` on a recipe or scene in place
- a saved recipe or scene can reopen through the same helper path and show the
  updated title
- a bundle save attempt fails narrowly as inspect-only instead of widening into
  mutation support
- `bash scripts/verify-phase-18.sh` proves inspect, save, reopen, and
  bundle-save rejection from the built app bundle on arm64 macOS

## Verification

```bash
bash scripts/verify-phase-18.sh
open zig-out/BlendZigShell.app
```

## Follow-On Slice

Once inspect and save are stable, the remaining honest phase-18 work is the
workflow follow-through batch before phase 19 viewport work starts.

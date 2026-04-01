# Phase 18 Slice: Workflow Follow-Through

## Goal

Close phase 18 with one executable proof that the launchable macOS shell stays
bounded, fails narrowly on external-save conflicts, and hands off to a concrete
phase-19 viewport gap instead of widening into editor work.

## Scope

In scope:

- one narrow save-conflict rejection when a `.bzrecipe` or `.bzscene` changes on
  disk after the shell opens it
- one phase-18 verification path that proves inspect, save, reopen, bundle-save
  rejection, save-conflict rejection, status regeneration, and Ralph/team
  dry-runs from the current tree
- phase-18 task and status updates that mark the shell batch complete and point
  to the first phase-19 viewport slice

Out of scope:

- viewport or rendering implementation
- selection, transforms, or direct modeling from the shell
- wider project, undo, or autosave state

## Acceptance Criteria

This slice is complete only when all of these are true:

- `bash scripts/verify-phase-18.sh` proves recipe and scene inspect-save-reopen,
  bundle inspect-only rejection, save-conflict rejection, status regeneration,
  and the phase-18 Ralph/team dry-run surfaces from the current tree
- the shell save path fails narrowly with reload guidance instead of overwriting
  a recipe or scene that changed on disk after open
- `tasks/phase-18.md` is fully checked, and the next interaction gap is
  captured as one explicit phase-19 viewport slice rather than a vague editor
  wishlist

## Verification

```bash
bash scripts/verify-phase-18.sh
```

## Follow-On Slice

Once this closure batch is green, the next honest work is
`openspec/daily-driver/slices/phase-19-viewport-mvp-launch.md`.

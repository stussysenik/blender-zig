# Phase 19 Slice: Workflow Follow-Through

## Goal

Close the phase-19 interaction batch with one executable proof that the native
shell can preview saved work, create a primitive-backed study, persist focused
transforms, and apply or remove one bounded direct-modeling step without
widening into a larger editor scope.

## Scope

In scope:

- one phase-19 verification path that proves viewport preview, object focus,
  primitive creation, focused transform save, focused `subdivide` apply/remove,
  status regeneration, and the Ralph/team dry-run surfaces from the current
  tree
- phase-19 task and status updates that reflect the completed direct-modeling
  round and keep the remaining manual viewport proof explicit
- one bounded follow-through pointer for the next phase instead of a vague
  post-phase backlog

Out of scope:

- new modeling ops beyond the shell-owned `subdivide` route
- graph-backed study work
- phase-20 reopen, autosave, or packaging implementation

## Acceptance Criteria

This slice is complete only when all of these are true:

- `bash scripts/verify-phase-19.sh` proves viewport preview, object focus,
  primitive creation, focused transform save, focused `subdivide` apply/remove,
  status regeneration, and the phase-19 Ralph/team dry-run surfaces from the
  current tree
- `tasks/phase-19.md` reflects the direct-modeling round as landed, while the
  remaining open interaction gap stays the manual orbit/pan/zoom proof on
  `recipes/phase-19/viewport-gallery.bzscene`
- the daily-driver OpenSpec surfaces point at this workflow slice instead of
  leaving the completed direct-modeling slice as the active planning target

## Verification

```bash
bash scripts/verify-phase-19.sh
```

## Follow-On Slice

Once this closure batch is green, the next honest work is the first phase-20
reopen hardening slice over the current durable recipe and scene surfaces.

# Phase 17 Slice: Workflow Follow-Through

## Goal

Close phase 17 with one executable proof that the persistence path survives a
clean-room run, fails clearly on missing scene parts, and still lines up with
the Ralph/team execution surfaces.

## Scope

In scope:

- one clean-room verification script built from a temporary git worktree of the
  current tree
- one explicit missing-scene-part failure path for `mesh-scene`
- phase-17 task and status updates that reflect the completed persistence batch

Out of scope:

- new project or session file formats
- native shell or viewport work
- new geometry operators

## Acceptance Criteria

This slice is complete only when all of these are true:

- `bash scripts/verify-phase-17.sh` proves replay, bundle reopen, missing scene
  part failure, status regeneration, and the phase task surfaces from the
  current tree
- `bash scripts/verify-clean-room.sh` rebuilds the current tree in a temporary
  worktree and reruns the phase-17 verification with no manual edits
- missing `.bzscene` part files fail as `ScenePartFileNotFound` instead of
  widening into silent drift
- phase-17 docs, tasks, and generated status surfaces agree that the remaining
  product gap is phase 18 shell scope rather than more persistence mechanics

## Verification

```bash
bash scripts/verify-phase-17.sh
bash scripts/verify-clean-room.sh
```

## Follow-On Slice

Once this closure batch is green, the next honest work is the first phase-18
shell-scope slice for a launchable native macOS entrypoint.

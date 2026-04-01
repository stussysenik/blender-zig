# Phase 17: Persistence And Bundles

## Intent

Move from replayable studies to durable local work units that can be reopened,
replayed, and verified cleanly across machines without rebuilding state by hand.

## Workflows Unlocked

- save authored work as something stronger than ad hoc recipes
- reopen mixed geometry work after closing the tool
- roundtrip scenes, imports, and replay or bundle metadata through one
  documented path

## In Scope

- canonical project or bundle format
- save and reopen semantics
- mixed mesh-plus-curve persistence
- compatibility and migration rules for early versions

## Exit Criteria

- one documented durable project or bundle unit exists
- mesh-only, curve-only, and mixed scenes can roundtrip
- imported asset references survive replay or fail clearly
- the current tree can rerun the persistence path from a clean-room checkout
- persistence semantics align with the project-state contract

## Execution Surface

- [tasks/phase-17.md](/Users/s3nik/Desktop/blender-zig/tasks/phase-17.md)
- [openspec/daily-driver/system/project-state-and-recovery.md](/Users/s3nik/Desktop/blender-zig/openspec/daily-driver/system/project-state-and-recovery.md)

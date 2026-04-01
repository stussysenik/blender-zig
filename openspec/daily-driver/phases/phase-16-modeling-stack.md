# Phase 16: Modeling Stack

## Intent

Turn the current direct-op baseline into a coherent local modeling stack that can
support authored studies, constrained edits, and repeatable verification.

## Workflows Unlocked

- repair a local modeling mistake without rebuilding from scratch
- grow topology with bounded edit operators
- replay a saved edit-heavy recipe instead of a one-off demo command
- drive the phase through Ralph/team loops without guessing what the next slice means

## System Boundary

In scope:

- bounded mesh edit and topology-growth operators
- direct CLI commands
- `mesh-pipeline` composition
- edit-heavy recipes and scene studies
- phase-scoped verification scripts

Out of scope:

- viewport
- app shell
- rendering
- Blender compatibility claims

## Active Slice Stack

Current landed or landing slices:

- `mesh-fill-hole`
- `mesh-bevel-edge`
- `mesh-delete-edge`

Linked slice specs:

- [openspec/daily-driver/slices/phase-16-delete-edge.md](/Users/s3nik/Desktop/blender-zig/openspec/daily-driver/slices/phase-16-delete-edge.md)

## Execution Surface

- [tasks/phase-16.md](/Users/s3nik/Desktop/blender-zig/tasks/phase-16.md)
- `bash scripts/verify-phase-16.sh`

## Exit Criteria

Phase 16 is complete when all of these are true:

- constrained edit stack includes at least one edge-domain counterpart to `mesh-delete-face`
- new edit/growth operators compose through `mesh-pipeline`
- at least two edit-heavy authored studies exist
- at least one `.bzscene` composes those studies
- phase-specific verification is runnable without hidden host knowledge

## Next Slice After Delete-Edge

The next highest-value slice is the authoring-study set:

- define the edit-heavy recipe pack
- add at least one composed scene
- verify the study pack through the phase script and real runtime output

# Phase 16 Task File

Use this task file when the goal is to push the next modeling/application phase intentionally instead of pulling the next unchecked item from the global backlog.

The first four unchecked items are intentionally ordered for `scripts/team-loop.sh` with the default role set:
- `architect`
- `executor`
- `verifier`
- `release-manager`

## Round 1: Fill-Hole Launch
- [x] define the exact `mesh-fill-hole` scope and regression matrix for one simple planar boundary loop
- [x] implement `mesh-fill-hole` with direct CLI and pipeline coverage
- [x] verify `mesh-fill-hole` through `zig build test`, direct CLI, and pipeline runtime output
- [x] update generated status surfaces and phase notes after `mesh-fill-hole` lands

## Round 2: Topology Growth
- [ ] define the exact bounded bevel-like growth slice and regression matrix for the current face-corner mesh
- [ ] implement the first bounded bevel-like topology-growth op with direct CLI and pipeline coverage
- [ ] verify the first bounded bevel-like topology-growth op through tests and real CLI runs
- [ ] refresh generated docs after the first topology-growth op lands

## Round 3: Constrained Edit Stack
- [ ] define one constrained selection edit that pairs with delete-face, inset-region, and extrude-region
- [ ] implement one constrained selection edit that pairs with the current delete/inset/extrude stack
- [ ] verify the constrained selection edit through tests and real CLI runs
- [ ] update phase notes after the constrained selection edit lands

## Round 4: Authoring Studies
- [ ] define the edit-heavy recipe and scene study set for the phase-16 stack
- [ ] add edit-heavy `.bzrecipe` studies that exercise the new phase-16 stack
- [ ] verify the new recipe studies and one `.bzscene` composition through real runtime output
- [ ] refresh generated status surfaces once the new studies land

## Round 5: Workflow Follow-Through
- [ ] verify the Ralph/operator flow against `tasks/phase-16.md` and the global phase-16 backlog

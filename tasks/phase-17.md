# Phase 17 Task File

Use this task file when the goal is to make saved studies and mixed-geometry packaging executable instead of just documented.

The first four unchecked items are intentionally ordered for `scripts/team-loop.sh` with the default role set:
- `architect`
- `executor`
- `verifier`
- `release-manager`

## Round 1: Replay Scope
- [ ] define the exact saved-recipe and scene replay scope for repeatable daily-driver studies
- [ ] implement the smallest replayable metadata layer for `.bzrecipe` and `.bzscene`
- [ ] verify replay from disk through direct CLI runs and one roundtrip smoke test
- [ ] refresh generated status surfaces after the replay scope lands

## Round 2: Mixed Packaging
- [ ] define the exact manifest-based bundle format for mixed mesh-plus-curve scenes
- [ ] implement bundle read/write for one narrow mixed scene shape
- [ ] verify mesh-only, curve-only, and mixed bundle roundtrips through tests and CLI output
- [ ] update phase notes and docs after the bundle format lands

## Round 3: Study Coverage
- [ ] define the edit-heavy study set that exercises scene persistence in a practical workflow
- [ ] add at least two replayable `.bzrecipe` studies that vary seed, selection, and placement
- [ ] verify the new studies through `mesh-pipeline` and `mesh-scene`
- [ ] refresh generated docs once the studies land

## Round 4: Workflow Follow-Through
- [ ] verify the Ralph/operator flow against `tasks/phase-17.md`
- [ ] confirm the new tasks remain narrow enough for parallel roles
- [ ] capture any acceptance gaps that need to roll into phase 18
- [ ] update generated status surfaces after the phase-17 batch lands

## Exit Condition

Phase 17 ends when the repo can:

- replay a saved study from disk
- bundle and reopen a mixed mesh-plus-curve scene
- roundtrip the resulting geometry through the documented CLI path
- do the above deterministically from a fresh clone with no manual edits

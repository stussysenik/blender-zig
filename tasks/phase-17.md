# Phase 17 Task File

Use this task file when the goal is to make saved studies and mixed-geometry packaging executable instead of just documented.

The first four unchecked items are intentionally ordered for `scripts/team-loop.sh` with the default role set:
- `architect`
- `executor`
- `verifier`
- `release-manager`

## Round 1: Replay Scope
- [x] define the exact saved-recipe and scene replay scope for repeatable daily-driver studies
- [x] implement the smallest replayable metadata layer for `.bzrecipe` and `.bzscene`
- [x] verify replay from disk through direct CLI runs and one roundtrip smoke test
- [x] refresh generated status surfaces after the replay scope lands

## Round 2: Mixed Packaging
- [x] define the exact manifest-based bundle format for mixed mesh-plus-curve scenes
- [x] implement bundle read/write for one narrow mixed scene shape
- [x] verify mesh-only, curve-only, and mixed bundle roundtrips through tests and CLI output
- [x] update phase notes and docs after the bundle format lands

## Round 3: Study Coverage
- [x] define the edit-heavy study set that exercises scene persistence in a practical workflow
- [x] add at least two replayable `.bzrecipe` studies that vary seed, selection, and placement
- [x] verify the new studies through `mesh-pipeline` and `mesh-scene`
- [x] refresh generated docs once the studies land

## Round 4: Workflow Follow-Through
- [x] verify the Ralph/operator flow against `tasks/phase-17.md`
- [x] confirm the new tasks remain narrow enough for parallel roles
- [x] capture any acceptance gaps that need to roll into phase 18
- [x] update generated status surfaces after the phase-17 batch lands

## Exit Condition

Phase 17 ends when the repo can:

- replay a saved study from disk
- bundle and reopen a mixed mesh-plus-curve scene
- roundtrip the resulting geometry through the documented CLI path
- do the above deterministically from a fresh clone with no manual edits

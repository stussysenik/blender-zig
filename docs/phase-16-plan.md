# Phase 16 Plan

Phase 16 is the next deliberate push after the current direct-op baseline. The goal is not "rewrite Blender tonight." The goal is to turn the current Zig geometry tool into a much stronger local modeling/runtime surface with a backlog that parallel agents can actually execute safely.

## Outcome

By the end of Phase 16, `blender-zig` should be stronger in three ways:

1. direct editing and topology growth feel more like a modeling tool than a demo suite
2. saved recipes and scenes exercise those edits in repeatable studies
3. the OMX/Ralph workflow can target the whole phase intentionally instead of drifting task by task

## Acceptance Criteria

Phase 16 is complete when all of these are true:

- at least two new bounded mesh-edit or topology-growth ops land beyond the current delete/inset/extrude stack
- those ops are available through both direct CLI commands and `mesh-pipeline`
- at least two new saved studies or scenes demonstrate the new edit stack in practical compositions
- the Ralph/operator workflow can target this phase explicitly through a dedicated task source or phase selector
- generated status surfaces reflect the new phase state
- every landed slice remains test-backed with a real CLI verification path

## Non-Goals

Phase 16 does not include:

- viewport work
- editor UI
- rendering
- Blender file compatibility claims
- broad import format expansion without a concrete modeling need
- pretending the whole rewrite is parallelizable without bounded ownership

## Workstreams

### Workstream A: Mesh Editing And Topology Growth

Target outcome:
- move from isolated primitive transforms into a coherent edit stack

Planned slices:

1. bounded fill/repair op
   - first target: `mesh-fill-hole`
   - scope: fill one simple planar boundary loop back into one ngon cap
   - reason: make `mesh-delete-face` reversible enough to support a real edit loop
2. bounded bevel-like growth op
   - likely a narrow chamfer or edge-bevel slice, not full Blender bevel
   - must preserve the current face-corner model and keep UV behavior deterministic
3. constrained selection edit
   - examples: delete-edge with wire preservation, dissolve-wire, or another bounded selection-based edit
4. compose edit-stack coverage
   - ensure the new ops chain cleanly with `mesh-delete-face`, `mesh-inset-region`, `mesh-extrude-region`, and subdivision

Verification standard:
- unit tests in the touched geometry module
- one direct CLI command per new op
- one `mesh-pipeline` run that proves the op composes with the existing stack

### Workstream B: Authoring Studies And Scene Recipes

Target outcome:
- shift new ops from "they compile" to "they build something worth inspecting"

Planned slices:

1. add new `.bzrecipe` studies that exercise edit-heavy workflows
2. add at least one `.bzscene` composition that reuses those studies
3. keep outputs inspectable through OBJ or PLY without inventing a UI layer

Verification standard:
- each new study runs through `zig build run -- mesh-pipeline --recipe ...`
- each new scene runs through `zig build run -- mesh-scene --recipe ...`

### Workstream C: Workflow And Phase Control

Target outcome:
- make the OMX/Ralph loop usable against the whole phase instead of only the global backlog

Planned slices:

1. add a dedicated phase task file
2. allow `ralph-loop` and `team-loop` to target that phase more explicitly
3. document the operator path for running architect, executor, and verifier lanes against the same phase

Verification standard:
- shell syntax checks for loop scripts
- one dry-run invocation that shows the phase-targeting surface clearly

## Parallelization Model

This phase is intentionally split into bounded lanes:

- `architect` lane:
  - define the next narrow op and its regression matrix
  - keep the phase task file and acceptance criteria coherent
- `executor` lane:
  - implement one op at a time in `src/geometry/`
  - wire CLI and pipeline surfaces
- `verifier` lane:
  - run the minimal useful test and runtime matrix
  - confirm command outputs and status surfaces
- `release-manager` lane:
  - keep generated status docs and release metadata aligned

## Recommended Execution Order

1. lock the phase task file and workflow targeting
2. land `mesh-fill-hole` as the first repair/edit recovery op
3. land the first topology-growth op
4. land the first constrained selection edit
5. add recipe and scene studies that use the new stack
6. refresh status surfaces and phase docs

## Suggested Operator Commands

These are the intended entry points once the workflow surface is aligned:

```bash
bash scripts/ralph-loop.sh --task-file tasks/phase-16.md --once
bash scripts/ralph-loop.sh --task-file tasks/phase-16.md --role architect --once
bash scripts/ralph-loop.sh --task-file tasks/phase-16.md --role verifier --once
bash scripts/team-loop.sh --task-file tasks/phase-16.md
```

## Exit Condition

Phase 16 ends when the repo can demonstrate a clearly stronger local modeling loop:

- create or import a mesh
- apply bounded edit and growth ops
- save the result as a study or scene
- export the output
- rerun the exact same study deterministically from the CLI

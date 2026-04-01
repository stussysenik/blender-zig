# Phase 19 Task File

Use this task file when the daily-driver OpenSpec bundle is the active spec surface and the goal is to land the first usable viewport and interaction layer intentionally instead of pulling the next unchecked item from the global backlog.

The first four unchecked items are intentionally ordered for `scripts/team-loop.sh` with the default role set:
- `architect`
- `executor`
- `verifier`
- `release-manager`

## Round 1: Viewport MVP Launch
- [ ] define the minimum viewport slice for the daily-driver shell, including orbit, pan, zoom, and one inspectable scene or project, with a clear acceptance matrix for local reruns
- [ ] implement the viewport MVP with a direct shell entry, deterministic camera controls, and one test-backed render path over the current geometry kernel
- [ ] verify the viewport MVP through tests and a real local run that demonstrates orbit, pan, and zoom on a concrete study or project file
- [ ] refresh the generated docs, phase notes, and daily-driver spec pointer after the viewport MVP lands

## Round 2: Selection And Inspection
- [ ] define the smallest selection and inspection path for objects or geometry elements that keeps the app shell bounded to a single focused workflow
- [ ] implement the inspection path so the shell can select or focus one object or element and read back its current properties
- [ ] verify selection and inspection through tests and a real local run on at least one mesh study and one mixed mesh-plus-curve study
- [ ] update the daily-driver spec bundle and generated status surfaces after selection and inspection land

## Round 3: Transform Interaction
- [ ] define bounded translate, rotate, and scale interaction over the current geometry kernel and app shell state, with explicit persistence expectations
- [ ] implement one interaction path that applies transform edits without rebuilding the whole scene or losing the current selection
- [ ] verify transforms through tests and a real local run that shows edits persist in the active project or study after reload
- [ ] refresh phase notes and execution docs after the transform path lands

## Round 4: Direct Modeling Exposure
- [ ] define the narrow set of direct modeling ops exposed through the interaction layer, keeping the surface aligned to the existing CLI ops
- [ ] wire one interaction route to invoke a bounded modeling op from the shell or viewport surface
- [ ] verify the exposed op through tests and a real run that uses the same underlying geometry kernel as the CLI
- [ ] update the OpenSpec daily-driver bundle and generated docs after the interaction route lands

## Round 5: Workflow Follow-Through
- [ ] verify the Ralph/operator flow against `tasks/phase-19.md` and the daily-driver OpenSpec bundle
- [ ] confirm the phase remains bounded, testable, and not dependent on rendering beyond the viewport MVP
- [ ] keep the next slice ready for Phase 20 without widening scope

## Exit Condition

Phase 19 ends when the repo can:

- open a saved study or project in the app shell
- inspect the geometry in a viewport with orbit, pan, and zoom
- select a bounded target and apply at least one persisted transform
- invoke one direct modeling op through the same geometry kernel used by the CLI

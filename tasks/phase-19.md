# Phase 19 Task File

Use this task file when the daily-driver OpenSpec bundle is the active spec surface and the goal is to land the first usable viewport and interaction layer intentionally instead of pulling the next unchecked item from the global backlog.

The first four unchecked items are intentionally ordered for `scripts/team-loop.sh` with the default role set:
- `architect`
- `executor`
- `verifier`
- `release-manager`

## Round 1: Viewport MVP Launch
- [x] define the minimum viewport slice for the daily-driver shell: orbit, pan, zoom, and one inspectable mesh-backed saved recipe or scene, with a clear acceptance matrix for local reruns
- [x] implement the viewport MVP with a direct shell entry, deterministic camera controls, and one test-backed preview path over the current geometry kernel output
- [ ] verify the viewport MVP through tests and a real local run that demonstrates orbit, pan, and zoom on `recipes/phase-19/viewport-gallery.bzscene`
- [ ] refresh the generated docs, phase notes, and daily-driver spec pointer after the viewport MVP lands

## Round 2: Object Focus, Primitive Creation, And Inspection
- [x] define the smallest object-focus and primitive-creation path that keeps the app shell bounded to a single focused workflow
- [x] implement the inspection path so the shell can create one primitive-backed study, focus one object, and read back its current properties
- [x] verify object focus and inspection through tests and a real local run on at least one mesh study, one mixed mesh-plus-curve study, and one newly created primitive study
- [x] update the daily-driver spec bundle and generated status surfaces after object focus and inspection land

## Round 3: Transform Interaction
- [x] define bounded translate, rotate, and scale interaction over the current geometry kernel and app shell state, with explicit persistence expectations
- [x] implement one interaction path that applies transform edits without rebuilding the whole scene or losing the current selection
- [x] verify transforms through tests and a real local run that shows edits persist in the active project or study after reload
- [x] refresh phase notes and execution docs after the transform path lands

## Round 4: Direct Modeling Exposure
- [ ] define the first focused-recipe direct modeling slice around one bounded `subdivide` route that preserves the trailing transform block
- [ ] wire one shell interaction route to invoke the bounded `subdivide` op before the current transform block
- [ ] verify the exposed `subdivide` route through tests and a real run that uses the same underlying geometry kernel as the CLI
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

## Geometry-Node Shortcut

Once the object-focused shell loop is stable, the fastest path to usable
geometry nodes is a graph-backed saved study over the existing node runtime, not
a visual node-editor rewrite.

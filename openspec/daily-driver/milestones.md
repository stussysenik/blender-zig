# Milestones

## Planning Horizon

These are best-case planning ranges for the current narrow scope, not promises:

- M0: immediate
- M1-M2: early to mid April 2026
- M3: mid to late April 2026
- M4: late April to mid May 2026
- M5: mid May to early June 2026
- M6: June 2026 and after

If the scope expands beyond the current geometry, persistence, and shell path, these ranges stop being meaningful.

## M0. Spec Sync And Backlog Hygiene

Exit conditions:

- `openspec/daily-driver/` exists and is the active planning bundle
- `tasks/zig-rewrite.md` has unique phase numbering and no duplicate phase headers
- root planning docs point to this bundle instead of copying the same slice in multiple places
- status docs stay generated from versioned status data, with live git state read separately

Acceptance criteria:

- the README, implementation plan, and operating model all point at the same active spec
- no numbering collision remains between the global backlog and phase-specific task files

## M1. Modeling Core Completeness

Exit conditions:

- the direct modeling stack supports the current mesh edit loop without hand-holding
- bounded slices exist for triangulate, merge-by-distance, delete-face, delete-loose, fill-hole, inset, extrude, dissolve, subdivide, and at least one bevel-like growth op
- every op has a direct CLI and a test
- at least one pipeline study composes several of the ops together

Acceptance criteria:

- the same modeling command can be run twice and produce the same shape and counts
- the touched slices have both unit coverage and at least one runtime verification path

## M2. Mixed Geometry And Repeatable Studies

Exit conditions:

- curve and mesh workflows can roundtrip through the same geometry model
- scene and recipe files can replay repeatable authoring studies
- import and export support the concrete formats needed by those studies
- the CLI surface can exercise mixed mesh-plus-curve cases without graph-demo scaffolding

Acceptance criteria:

- a saved study can be replayed from disk with no manual edits
- a mixed-geometry result can be exported and re-imported through a documented path

## M3. Reliability And Undo Floor

Exit conditions:

- mesh invariant validation exists around the active edit stack
- undo and redo exist through snapshots or operation history
- local recovery or autosave exists for the narrow project/session path
- medium-sized repeatable studies stay stable through longer edit runs

Acceptance criteria:

- a 20-30 step local modeling session can be completed without corruption or unrecoverable state loss
- reopening saved work after a failed or interrupted session does not require reconstructing the study by hand

## M4. App Shell Foundation

Exit conditions:

- a small native shell can open, inspect, and save local work
- the shell can invoke the current geometry kernel without ad hoc glue
- project or session state is simple enough to keep testable
- the shell remains narrow enough that it does not become a second rewrite

Acceptance criteria:

- the same work can be opened from the shell and from the CLI
- the shell path does not break the existing command-line workflow

## M5. Viewport And Interaction MVP

Exit conditions:

- a minimal viewport can display the current geometry output
- orbit, pan, and zoom exist
- basic selection and transform interaction exist for inspection and simple edits
- the interaction layer can call a narrow set of direct modeling ops

Acceptance criteria:

- a user can inspect and manipulate a model without leaving the app
- the interaction layer still exercises the same tested geometry code paths

Implementation note:

- start M5 with object-focused primitive creation and persisted transforms
- bridge geometry nodes through a text-backed graph study before any visual node canvas

## M6. Releaseable Daily Driver

Exit conditions:

- optimized macOS builds are routine
- the release path is documented and automated enough to hand to another contributor
- signed and notarized distribution can be enabled when credentials exist
- the default user path is stable enough to use repeatedly during real work

Acceptance criteria:

- a fresh clone can reach the full verified loop using only documented commands
- the same workflow works on a second machine with the same toolchain prerequisites

## Daily-Driver Definition

Daily-driver status means all of these are true:

- fresh clone
- `zig build test`
- `zig build -Doptimize=ReleaseFast`
- run the core modeling commands
- open the same work in the app shell
- inspect and transform in the viewport
- replay a saved study or scene
- export a result
- repeat the same workflow on the next machine without special setup beyond the documented toolchain

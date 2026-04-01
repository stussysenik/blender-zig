# Project State And Recovery

This document defines the canonical work units and the recovery floor needed to
turn `blender-zig` from a runnable CLI into a tool that can survive real use.

## Canonical Work Units

### Recipe

`.bzrecipe` is a single modeling study over one seed mesh plus ordered pipeline steps.

Rules:

- deterministic input
- deterministic ordered steps
- optional default output path
- no hidden runtime state

### Scene

`.bzscene` is a composition of recipes or imported assets with part-level placement.

Rules:

- each part must be replayable independently
- scene placement is explicit and ordered
- imported assets must preserve source path and import mode

### Bundle

`.bzbundle` is the current narrow durable packaging unit for reopened geometry.

Rules:

- bundle contents are explicit and portable
- one manifest describes one bundled geometry payload
- the manifest must declare what geometry components are expected
- reopening a bundle must validate the payload instead of trusting silent drift

### Project

Future project state will group recipes, scenes, imports, and local metadata into
one named unit. That project format is not in tree yet, but Phase 17 and Phase 18
must shape toward it deliberately instead of adding ad hoc save files.

### Session

Session state is the reopenable working context around a project:

- active file
- transient viewport state
- undo/redo cursor
- autosave pointer

Session state should never become the only place where essential geometry exists.

The first phase-18 shell session is intentionally smaller than the eventual
session model:

- active document path
- last helper replay summary
- last shell error

That floor is enough for launchable open flows, but not enough for save or
recovery claims yet.

## Persistence Rules

- recipes and scenes are durable authored state
- bundles are durable packaged state for reopen and handoff
- session state is recoverable convenience state
- exports are outputs, not canonical editable state
- exports should prefer documented universal/open interchange formats over app-only packaging
- generated status docs are not project state

## Undo And Redo Model

The minimum intended model is snapshot-backed operation history:

- undo and redo must apply to the same geometry kernel surfaces used by CLI and app shell
- operation history must be serializable or reconstructable from saved state before daily-driver status
- destructive operations must leave enough state to reopen work safely after interruption

## Autosave And Crash Recovery

Daily-driver status requires:

- autosave cadence or explicit checkpointing
- last-known-good reopen path after abnormal termination
- clear rule for recovering unsaved session state vs durable project state

Phase expectations:

- Phase 16: no autosave yet, but authored studies stay deterministic
- Phase 17: durable replay and bundle behavior are explicit, deterministic, and
  fail clearly when scene parts are missing
- Phase 18: shell must open the current durable surfaces directly, then add
  bounded metadata inspection plus recipe/scene `title` save without mutating
  bundles, reject external-save conflicts narrowly, and avoid forking the
  project and session model away from those same files
- Phase 20: recovery flow must be tested and documented

## Failure Handling

Failure modes must be explicit:

- invalid recipe or scene syntax
- incompatible future file versions
- missing imported asset path
- interrupted save
- interrupted export
- failed reopen after a crash

The failure rule is simple: fail narrowly, preserve durable state, and emit a
recoverable message instead of silently widening behavior.

## Migration Rules

Once a project format exists:

- version the format
- keep migration explicit and test-backed
- refuse silent data upgrades that cannot be reversed

## Verification Floor

The project-state and recovery contract is not considered real until the repo can:

- save authored work
- reopen it deterministically
- survive one interrupted session without reconstructing the model by hand

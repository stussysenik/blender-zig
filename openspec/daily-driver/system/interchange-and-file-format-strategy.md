# Interchange And File-Format Strategy

This document defines how `blender-zig` should treat internal authored state
versus external interchange.

The rule is simple:

- internal editable state can use narrow repo-native `.bz*` formats when they
  stay text-first, versioned, and auditable
- external handoff should prefer universal or open interchange formats with
  clear semantics over app-only or opaque packaging

## Format Classes

### Internal Authored State

These formats exist to preserve editable intent inside the repo and app:

- `.bzrecipe` for one bounded modeling study
- `.bzscene` for multi-part composition
- future `.bzgraph` for graph-backed studies
- `.bzbundle/` for explicit packaged reopen state

Rules:

- stay line-oriented or otherwise human-auditable
- carry explicit version metadata when needed
- never become hidden UI-only state
- remain replayable through the same Zig helper path used by the CLI and shell

### External Interchange

These formats exist so work can leave the repo and still be usable elsewhere.

Current floor:

- ASCII OBJ for the broadest mesh-plus-curves inspection and roundtrip path
- ASCII PLY for mesh-only export when topology and vertex data matter more than
  scene composition

Next intended floor:

- one broader universal scene or mesh handoff path after object creation,
  transforms, and graph-backed studies stabilize
- the first candidate should be chosen for clarity and ubiquity, not novelty

Deferred until a concrete need exists:

- USD or USDZ
- broad material interchange
- animation interchange
- importer parity with full DCC scene formats

## Product Rules

- canonical editable work must not exist only as an export
- canonical editable work must not exist only as shell or viewport state
- every new export or import format must declare what geometry semantics are
  preserved and what is intentionally out of scope
- every widened format surface must have one real runtime verification path
- the repo must not invent opaque binary save files when a text-first internal
  format or universal/open interchange format would do the job

## Stable-Version Interpretation

For the first meaningful stable version on Apple Silicon:

- `.bzrecipe`, `.bzscene`, and future `.bzgraph` are the editable authored
  surfaces
- `.bzbundle/` is packaged reopen state
- OBJ and PLY are the current documented interchange surfaces
- the next external-format widening should happen only when the app can already
  create, edit, save, reopen, and export basic objects reliably

## Decision Filter

Before adding a new format, answer all of these:

1. is this format internal authored state or external interchange
2. what exact geometry or scene semantics survive roundtrip
3. why is an existing `.bz*`, OBJ, or PLY path not enough
4. what test and runtime proof will keep the semantics honest

If those answers are weak, the new format should not land yet.

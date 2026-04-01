# Daily-Driver Design

This file is the Stitch-style design surface for the daily-driver path. The
vision says what the product must become. This file fixes the shape of the
system that will get it there.

## Design Goal

Keep `blender-zig` as one understandable modeling stack that can be exercised
from saved studies today and from a native shell later, without forking the
geometry logic or hiding project state in UI-only code.

## Core Design Rules

- one geometry execution path shared by CLI, saved studies, saved scenes, and the future app shell
- text-first project surfaces before opaque binary state
- internal `.bz*` formats for authored intent, universal/open formats for external handoff
- deterministic modeling steps that stay readable enough for contributors to audit
- scene placement stays separate from study modeling history
- verification commands and planning docs must point at the same runnable slices
- phase boundaries are real: persistence before shell polish, shell before viewport polish

## System Shape

The product is intentionally layered:

1. geometry kernel
   - Zig-native mesh, curve, transform, and IO code under `src/`
   - bounded operators that can be tested directly
2. authoring surfaces
   - direct CLI commands for single-slice operator verification
   - `.bzrecipe` studies as deterministic modeling histories over one seed
   - `.bzscene` files as multi-part composition with placement, not duplicated modeling logic
   - future graph-backed studies should enter as the same kind of text-backed,
     replayable work unit instead of a UI-only graph store
3. durable project state
   - the next persistence layer should wrap studies, scenes, metadata, and recovery data
   - the persistence layer should reference the same studies and scenes instead of inventing a second graph
4. native shell
   - open, inspect, save, and export over the same project model used by the CLI
   - shell code owns session flow, not geometry semantics
5. viewport and tools
   - inspect and narrow transforms over persisted project state
   - interaction should call into the same modeling path already proven in the CLI

## Canonical Work Units

The daily-driver path uses three work-unit shapes:

- study: one authored `.bzrecipe` that starts from a seed and replays a bounded edit history
- scene: one `.bzscene` that composes studies or imported mesh parts with explicit placement
- project: a future persisted container that records which study or scene is active, current metadata, and recovery state

The design constraint is simple: each larger work unit should reuse the smaller
one instead of replacing it.

When the current node runtime graduates from `graph-demo`, it should land as a
study subtype rather than as a new opaque work-unit class.

## Daily-Driver Loop

The intended loop is:

1. run documented verification from a fresh clone
2. open or create a study
3. promote that study into a composed scene when the work stops being single-part
4. save and reopen through the same project model
5. inspect and edit from a small shell and viewport
6. export deterministic output

Phase 16 owns step 2 and the beginning of step 3.
Phase 17 owns the durable save and reopen contract.
Phases 18 and 19 bridge that same model into the shell and viewport.

## Phase Design Boundaries

### Phase 16

- prove the modeling stack with edit-heavy studies and one composed scene
- keep the surface CLI-first and file-first

### Phase 17

- add persisted project state, bundle layout, and recovery expectations
- do not let persistence fork away from `.bzrecipe` and `.bzscene`

### Phase 18

- add a minimal native shell for open/save/session flow
- the shell is a client of project state, not a replacement for it

### Phase 19

- add a minimal viewport and narrow tools
- keep tool actions mapped to existing modeling operations where possible

### Phase 20

- harden reopen, packaging, second-machine verification, and failure recovery

## Current Implication

The highest-value work right now is still file-backed modeling flow, not UI
theater. The phase-16 study pack and composed scene are the last missing pieces
before persistence can become the next honest daily-driver bridge.

# Daily-Driver Contract

This is the authoritative definition of what `blender-zig` is trying to become.
Task files tell the team what to do next. Generated status docs show current
state. This file defines the product boundary those surfaces are supposed to
serve.

## Product Promise

`blender-zig` aims to become a local-first 3D authoring tool that can be used
repeatedly on macOS for real modeling work without depending on the original
Blender runtime or codebase.

The daily-driver promise is narrower than "rewrite all of Blender":

- strong local modeling loop over a bounded geometry kernel
- repeatable save, reopen, and export path
- explicit text-first authored state plus a documented universal/open interchange path
- native app shell with a minimal but real viewport and interaction layer
- contributor workflow that can be reproduced from a fresh clone

## Target User

The primary target user is a technically comfortable local creator who wants to:

- understand the modeling stack deeply by building with it
- replay authored studies deterministically
- inspect, edit, save, reopen, and export work without leaving the app
- iterate on the codebase without reverse-engineering hidden state

## Supported Workflow At Daily-Driver Status

Daily-driver means the following end-to-end loop works:

1. fresh clone and documented toolchain bootstrap
2. local verification from documented commands
3. open or create a study, scene, or project
4. inspect geometry in the app shell and viewport
5. perform a narrow but useful modeling session
6. save and reopen that work without reconstructing it by hand
7. export a deterministic result
8. repeat the same loop on a second machine with the same documented setup

## Hard Non-Goals

The contract does not promise:

- full Blender feature parity
- rendering parity
- DNA/RNA compatibility
- `.blend` compatibility
- asset browser parity
- scripting parity with Blender Python
- immediate support for every modeling mode at once

## Delivery Boundaries

The daily-driver path is intentionally staged:

- Phase 16: finish the bounded modeling stack
- Phase 17: persist and replay local work safely
- Phase 18: bridge the kernel into a native app shell
- Phase 19: add viewport and narrow interaction tooling
- Phase 20: harden reopen, release, and second-machine reproducibility

## Readiness Rubric

### Current

- native Zig geometry kernel
- direct modeling CLI
- recipes and scenes
- mesh and mixed OBJ roundtrips

### Daily-Driver Threshold

All of these must be true:

- local verification is documented and repeatable
- a saved work unit can be reopened after interruption
- the shell and viewport exercise the same geometry code used by the CLI
- the app supports a real inspect-edit-save-export loop
- exported work uses documented universal/open format semantics instead of shell-only state
- recovery expectations are explicit, not implied
- packaging and contributor handoff are documented enough to survive a machine change

## Release Gate

No slice can claim daily-driver progress unless it strengthens at least one of:

- local modeling depth
- persistence and recovery
- shell and viewport usability
- reproducible contributor verification

## Blender Comparison Boundary

The project should compare itself to Blender only at the workflow level:

- can the user model here repeatedly
- can the user understand and extend the toolchain
- can the user keep working after closing the app

It should not claim broad Blender equivalence until those workflow gates are real.

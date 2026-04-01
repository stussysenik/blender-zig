# Phase 20: Hardening And Release

## Intent

Close the gap between "usable on one machine" and "repeatable local daily driver"
by hardening reopen, verification, packaging, and contributor handoff.

## Workflows Unlocked

- reopen interrupted work reliably
- hand a release artifact or workflow to another contributor
- repeat the same verified local loop on another machine

## In Scope

- session recovery
- regression and performance floors
- optimized packaging
- signing and notarization hooks when credentials exist
- second-machine proof

## Exit Criteria

- reopen and recovery expectations are test-backed
- release packaging is documented and runnable
- the second-machine workflow is proven from documentation
- the daily-driver contract can be satisfied without undocumented recovery steps

## Execution Surface

- [tasks/phase-20.md](/Users/s3nik/Desktop/blender-zig/tasks/phase-20.md)
- [openspec/daily-driver/system/verification-and-release-gates.md](/Users/s3nik/Desktop/blender-zig/openspec/daily-driver/system/verification-and-release-gates.md)

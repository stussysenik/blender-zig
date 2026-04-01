# Execution

## Operating Model

1. Keep one active milestone and one bounded slice at a time.
2. Write the slice definition before implementation details diverge.
3. For phase-level direct-op work, keep one canonical slice spec under `openspec/daily-driver/slices/` per active slice.
4. Use parallel agents only when the interfaces are already fixed and the slices do not overlap.
5. Verify each slice with tests and real CLI output before landing.
6. Update the status docs and phase ledger in the same batch as the implementation.
7. Keep committed status docs generated from `status/hyperdata.json`; use `npm run status:live` for live git metadata instead of baking it into committed docs.
8. Use compatibility pointers under `docs/` only when older references still need to resolve.

## Slice Acceptance Criteria

A slice is not done until all of these are true:

- it has a clearly named command, recipe, scene, or shell path
- it has an execution spec when the slice is important enough to hand to parallel roles
- it has unit or integration tests
- it produces a real runtime artifact
- it is reflected in this spec bundle and the phase backlog
- it does not break the current verification or release path

## Verification Loop

- run `bash scripts/verify-local.sh` when the host `zig build` path is not healthy
- run the touched CLI command or recipe
- run the slice-specific commands from `openspec/daily-driver/slices/*.md` when a direct-op execution spec exists
- run the active phase dry-run before launching a new parallel round
- example:
  - `bash scripts/ralph-loop.sh --phase 16 --dry-run --once`
  - `bash scripts/team-loop.sh --task-file tasks/phase-16.md --dry-run`
- run `npm run status:update`
- run `npm run status:check`
- run `npm run status:live`
- run any relevant packaging or replay command
- if the phase numbering changes, fix `tasks/zig-rewrite.md` in the same batch

## Phase 16 Slice Contract

When the current work is a constrained-edit slice, use [openspec/daily-driver/slices/phase-16-delete-edge.md](/Users/s3nik/Desktop/blender-zig/openspec/daily-driver/slices/phase-16-delete-edge.md) as the source of truth for:

- the exact operator boundary
- the acceptance criteria
- the regression matrix
- the role handoff order
- the verification commands

Do not start widening the implementation until that slice spec is green and the phase notes reflect the same operator name and scope.

## Risks

- scope creep: keep slices bounded and park everything else in the next milestone
- doc drift: keep this bundle authoritative and regenerate the status docs from `status/hyperdata.json`
- topology correctness: keep the geometry tests close to the implementation
- packaging friction: defer signing and notarization until credentials and CI secrets are available
- contributor confusion: keep comments focused on module purpose and non-obvious algorithm steps, not line-by-line narration
- host toolchain drift: keep a host-safe verification script when the default `zig build` path is broken

## What To Do When A Slice Fails

- stop the batch at the failing slice
- capture the failing command and the expected output
- update the spec if the original acceptance criteria were too vague
- do not widen the scope until the current slice is stable

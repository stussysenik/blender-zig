# Execution

## Operating Model

1. Keep one active milestone and one bounded slice at a time.
2. Write the slice definition before implementation details diverge.
3. Use parallel agents only when the interfaces are already fixed and the slices do not overlap.
4. Verify each slice with tests and real CLI output before landing.
5. Update the status docs and phase ledger in the same batch as the implementation.

## Slice Acceptance Criteria

A slice is not done until all of these are true:

- it has a clearly named command, recipe, scene, or shell path
- it has unit or integration tests
- it produces a real runtime artifact
- it is reflected in this spec bundle and the phase backlog
- it does not break the current build or release path

## Verification Loop

- run `zig build test`
- run the touched CLI command or recipe
- run the active phase dry-run before launching a new parallel round
- example:
  - `bash scripts/ralph-loop.sh --phase 16 --dry-run --once`
  - `bash scripts/team-loop.sh --task-file tasks/phase-16.md --dry-run`
- run `npm run status:update`
- run `npm run status:check`
- run any relevant packaging or replay command
- if the phase numbering changes, fix `tasks/zig-rewrite.md` in the same batch

## Risks

- scope creep: keep slices bounded and park everything else in the next milestone
- doc drift: keep this bundle authoritative and regenerate the status docs from `status/hyperdata.json`
- topology correctness: keep the geometry tests close to the implementation
- packaging friction: defer signing and notarization until credentials and CI secrets are available
- contributor confusion: keep comments focused on module purpose and non-obvious algorithm steps, not line-by-line narration

## What To Do When A Slice Fails

- stop the batch at the failing slice
- capture the failing command and the expected output
- update the spec if the original acceptance criteria were too vague
- do not widen the scope until the current slice is stable

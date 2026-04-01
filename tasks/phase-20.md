# Phase 20 Task File

Use this task file when the daily-driver OpenSpec bundle is the active spec surface and the goal is to harden the native app shell into something repeatable on macOS instead of widening into new modeling scope.

The first four unchecked items are intentionally ordered for `scripts/team-loop.sh` with the default role set:
- `architect`
- `executor`
- `verifier`
- `release-manager`

## Round 1: Resume Flow Hardening
- [ ] define the minimum project and session reopen flow for daily-driver use, including the failure cases that must not lose work
- [ ] implement the reopen flow so a saved project or study can be restored without reconstructing the scene by hand
- [ ] verify reopen behavior through tests and a real local run that saves, quits, and restores the same work
- [ ] refresh the generated docs, phase notes, and daily-driver spec pointer after reopen support lands

## Round 2: Persistence Coverage
- [ ] define the persistence matrix for authored studies, scene recipes, selection state, and interaction state that Phase 20 must protect
- [ ] add the missing save/load coverage for the current app shell state without widening into unrelated file formats
- [ ] verify persistence through tests and a real local run that roundtrips at least one study and one scene
- [ ] update the daily-driver OpenSpec bundle and execution backlog after persistence coverage lands

## Round 3: Regression And Comparison
- [ ] define the regression matrix for modeling, persistence, and interaction so Phase 20 can be rerun deterministically
- [ ] add the missing regression tests that exercise the app shell and daily-driver interactions end to end
- [ ] verify the regression set through `zig build test` and one real CLI or shell run per critical path
- [ ] refresh phase notes and status surfaces after the regression coverage lands

## Round 4: Optimized Local Packaging
- [ ] define the optimized macOS packaging slice for the daily-driver build, including the artifacts that must be easy to rerun and compare
- [ ] implement the local packaging path for the app shell with release-friendly build settings and repeatable output locations
- [ ] verify the packaged build through a real optimized local run on macOS and compare it to the debug shell path
- [ ] update the OpenSpec bundle and generated docs after the packaging slice lands

## Round 5: Backlog Alignment
- [ ] verify the Ralph/operator flow against `tasks/phase-20.md` and the daily-driver OpenSpec bundle
- [ ] confirm the spec bundle and execution backlog stay aligned as the app shell matures
- [ ] keep the next post-Phase-20 slice bounded so the repo does not widen into UI or rendering work accidentally

## Exit Condition

Phase 20 ends when the repo can:

- reopen and resume local work reliably
- protect the critical save/load and interaction paths with regression coverage
- produce repeatable optimized macOS builds for the app shell
- hand the documented daily-driver workflow to another contributor without special recovery steps

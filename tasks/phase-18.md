# Phase 18 Task File

Use this task file when the goal is to establish the smallest native shell that can open local work without turning the app shell into a second rewrite.

The first four unchecked items are intentionally ordered for `scripts/team-loop.sh` with the default role set:
- `architect`
- `executor`
- `verifier`
- `release-manager`

## Round 1: Shell Scope
- [ ] define the minimum native app shell scope and project/session model
- [ ] implement the smallest shell entrypoint that can open a local project or study file
- [ ] verify shell launch and open paths through a real CLI smoke run
- [ ] refresh generated status surfaces after the shell scope lands

## Round 2: Kernel Bridge
- [ ] define the exact bridge between shell commands and the current geometry kernel
- [ ] implement one shell command that calls the existing modeling runtime
- [ ] verify shell-to-kernel execution through tests and command output
- [ ] update phase notes after the bridge lands

## Round 3: Inspect And Save
- [ ] define the minimal inspect/save loop the shell must support before viewport work
- [ ] implement one inspect path and one save path for local work
- [ ] verify open-edit-save-reopen through a bounded smoke test
- [ ] refresh docs once the loop is stable

## Round 4: Workflow Follow-Through
- [ ] verify the Ralph/operator flow against `tasks/phase-18.md`
- [ ] confirm the shell work stays narrower than viewport or editor UI
- [ ] capture the next interaction gap that should become phase 19
- [ ] update generated status surfaces after the phase-18 batch lands

## Exit Condition

Phase 18 ends when the repo can:

- open a local project or study in a native shell
- call the current modeling kernel from that shell
- save and reopen the same work without reconstructing it by hand
- stay testable and bounded enough to hand off to parallel agents

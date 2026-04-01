# Phase 18 Task File

Use this task file when the goal is to establish the smallest native shell that can open local work without turning the app shell into a second rewrite.

The first four unchecked items are intentionally ordered for `scripts/team-loop.sh` with the default role set:
- `architect`
- `executor`
- `verifier`
- `release-manager`

## Round 1: Shell Scope
- [x] define the minimum native app shell scope and project/session model
- [x] implement the smallest shell entrypoint that can open a local project or study file
- [x] verify shell launch and open paths through a real CLI smoke run
- [x] refresh generated status surfaces after the shell scope lands

## Round 2: Kernel Bridge
- [x] define the exact bridge between shell commands and the current geometry kernel
- [x] implement one shell command that calls the existing modeling runtime
- [x] verify shell-to-kernel execution through tests and command output
- [x] update phase notes after the bridge lands

## Round 3: Inspect And Save
- [x] define the bounded inspect/save floor: inspect metadata for recipe, scene, and bundle; save `title` only for recipe and scene; keep bundles inspect-only
- [x] implement metadata inspection plus in-place `title` save for `.bzrecipe` and `.bzscene`, with `.bzbundle` manifest inspection read-only
- [x] verify inspect-save-reopen for recipe and scene, and verify bundle save fails narrowly, through the built shell app smoke path
- [x] refresh docs and generated status surfaces once the bounded loop is green

## Round 4: Workflow Follow-Through
- [x] verify the Ralph/operator flow against `tasks/phase-18.md`
- [x] confirm the shell work stays narrower than viewport or editor UI
- [x] capture the next interaction gap that should become phase 19
- [x] update generated status surfaces after the phase-18 batch lands

## Exit Condition

Phase 18 ends when the repo can:

- open a local project or study in a native shell
- call the current modeling kernel from that shell
- save and reopen the same work without reconstructing it by hand
- stay testable and bounded enough to hand off to parallel agents

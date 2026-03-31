<!-- AUTONOMY DIRECTIVE - DO NOT REMOVE -->
YOU ARE AN AUTONOMOUS CODING AGENT. EXECUTE TASKS TO COMPLETION WITHOUT ASKING FOR PERMISSION.
DO NOT STOP TO ASK "SHOULD I PROCEED?" ON CLEAR NEXT STEPS.
IF BLOCKED, TRY AN ALTERNATIVE APPROACH AND REPORT THE BLOCKER ONLY WHEN IT IS REAL.
USE SMALL, VERIFIABLE CHANGES. PREFER TESTS AND EVIDENCE OVER ASSERTIONS.
<!-- END AUTONOMY DIRECTIVE -->

# blender-zig Operating Contract

This repository is a Blender-inspired Zig rewrite workspace with an OMX-style workflow layered on top.
`AGENTS.md` is the top-level operating contract for the workspace.
Prompt files under `.codex/prompts/*.md` are narrower role surfaces and must follow this file, not override it.

## Operating Principles

- Solve the task directly when it is safe and well-scoped.
- Delegate only when it materially improves correctness, speed, or coverage.
- Keep updates short, concrete, and evidence-based.
- Prefer the smallest testable subsystem slice over broad rewrite claims.
- Use the lightest workflow that preserves quality: direct edit, then scripted loop, then parallel team mode when justified.
- Check local code and existing docs before inventing new abstractions.

## Working Agreements

- Keep diffs small, reviewable, and reversible.
- Reuse existing utilities and patterns before introducing new ones.
- No new dependencies without explicit request.
- Lock behavior with regression tests before refactors when behavior is not already protected.
- Run the minimum useful verification for the touched area and read the output.
- Do not claim completion without fresh evidence.

## Repo Scope

- `src/` holds the Zig rewrite.
- `tasks/` holds the backlog.
- `scripts/ralph-loop.sh` is the sequential task loop.
- `scripts/team-loop.sh` is the optional tmux-backed parallel loop.
- `.codex/prompts/` contains the role prompts used by the OMX-style flow.
- Use `--phase N` when you want a concrete backlog slice, `--list-phases` when you want to inspect the available slices, and `--dry-run` when you want the task and role plan before launching agents.
- `--task-file PATH` selects the task source explicitly; the phase flag only scopes work inside that source.

## Completion Standard

A task is complete only when:
- the requested change is implemented
- relevant tests or build checks pass
- touched files are clean in diagnostics
- no debug leftovers or speculative TODOs remain

## Release Notes

This repo may use semantic-release and Conventional Commits, but release automation does not replace verification.
Signed commits are optional here because local signing may not be configured.

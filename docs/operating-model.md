# Operating Model

This repo is a Zig rewrite workspace with an agent workflow layered on top.

The workflow borrows two ideas:
- OMX-style role prompts and durable state files.
- Ralphy-style task loops and isolated worktrees.

Prompt resolution prefers `.codex/prompts/*.md` and falls back to `roles/*.md` for compatibility.

The planning contract for the path to a daily-driver local tool now lives in [openspec/daily-driver/README.md](/Users/s3nik/Desktop/blender-zig/openspec/daily-driver/README.md). Treat that bundle as the spec surface and treat `tasks/*.md` files as execution surfaces.

For the daily-driver path specifically, prefer `tasks/phase-16.md` through `tasks/phase-20.md` over scanning the global backlog once the current phase is known.

The intended path is:
1. Keep the backlog in `tasks/*.md`.
2. Check [openspec/daily-driver/README.md](/Users/s3nik/Desktop/blender-zig/openspec/daily-driver/README.md) first when it exists and treat it as the active spec for the current slice.
3. Run `scripts/ralph-loop.sh --phase N --dry-run` when you want to inspect a concrete phase slice before launching it.
4. Run `scripts/ralph-loop.sh --phase N` for a single task at a time inside that phase, or omit `--phase` to continue the first unchecked task in the file.
5. Use `scripts/team-loop.sh --phase N --dry-run` to preview a role-to-task assignment, then drop `--dry-run` to run several roles in parallel.
6. Use `--task-file PATH` whenever the task source should be something other than `tasks/zig-rewrite.md`.
7. Promote only verified work into release automation.
8. Re-anchor the backlog against `docs/blender-repo-scan.md` and the active spec path whenever the upstream target slice changes.

## Roles

- `architect` defines the smallest safe implementation.
- `executor` edits code.
- `verifier` runs checks and reports correctness.
- `release-manager` keeps release metadata consistent.

The root [AGENTS.md](/Users/s3nik/Desktop/blender-zig/AGENTS.md) is the workspace contract that these role prompts follow.

## Limits

- This repository does not assume tmux is installed.
- This repository does not assume signed commits are available.
- Semantic release is configured, but it still needs CI credentials and a populated `main` branch to publish.
- The scripts are scaffolding, not an opinionated replacement for engineering judgment.
- This repository is not attempting a whole-Blender rewrite in one pass. Work should advance by testable subsystem slices.
- Phase-scoped runs are preferred over bare task scanning when you already know the next slice.

## Release Policy

Commit messages should follow Conventional Commits.

Semantic release is configured to:
- analyze commits
- generate release notes
- update `CHANGELOG.md`
- commit release metadata back to the repo
- publish to GitHub releases when credentials are present

If commit signing is not configured locally, releases remain usable, but commit verification badges will not appear automatically.

# Operating Model

This repo is a Zig rewrite workspace with an agent workflow layered on top.

The workflow borrows two ideas:
- OMX-style role prompts and durable state files.
- Ralphy-style task loops and isolated worktrees.

Prompt resolution prefers `.codex/prompts/*.md` and falls back to `roles/*.md` for compatibility.

The intended path is:
1. Keep the backlog in `tasks/*.md`.
2. Run `scripts/ralph-loop.sh` for one task at a time.
3. Use `scripts/team-loop.sh` when you want several roles working in parallel.
4. Promote only verified work into release automation.
5. Re-anchor the backlog against `docs/blender-repo-scan.md` whenever the upstream target slice changes.

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

## Release Policy

Commit messages should follow Conventional Commits.

Semantic release is configured to:
- analyze commits
- generate release notes
- update `CHANGELOG.md`
- commit release metadata back to the repo
- publish to GitHub releases when credentials are present

If commit signing is not configured locally, releases remain usable, but commit verification badges will not appear automatically.

# Task Format

Keep rewrite work in plain markdown checklists.

Use one file per milestone stream, or a single backlog file with ordered tasks.

The current daily-driver execution path is:

- `tasks/phase-16.md`
- `tasks/phase-17.md`
- `tasks/phase-18.md`
- `tasks/phase-19.md`
- `tasks/phase-20.md`

Use `scripts/ralph-loop.sh --task-file tasks/phase-17.md --dry-run --once` or `scripts/team-loop.sh --task-file tasks/phase-17.md --dry-run` to preview a concrete phase round before you run it.

Rules:
- `- [ ]` means pending.
- `- [x]` means complete.
- Keep tasks small enough to verify in one pass.
- Put release- or verification-only work in separate tasks.

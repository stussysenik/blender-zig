# Release and Verification

Use this repo's release setup only after the Zig rewrite has real tests.

Minimum verification target:
- `zig test` for the package smoke target
- task-specific unit tests for geometry helpers
- release dry-run before a publish

Recommended release sequence:
1. Merge verified work to `main`.
2. Run `npm run release:dry-run`.
3. Inspect the generated notes.
4. Run `npm run release` in CI or a release job.

If your machine has no signing key configured, do not expect verified commits locally. That is a repository policy problem, not a script problem.


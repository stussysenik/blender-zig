# Verification And Release Gates

This is the authoritative verification ladder for the daily-driver path.

## Verification Tiers

### Slice Gate

A slice is landable only when all of these are true:

- bounded spec exists for the slice
- geometry or integration tests pass
- one real runtime command proves the behavior
- status docs and task files reflect the same scope

### Phase Gate

A phase is landable only when:

- every landed slice in that phase has a stable verification path
- phase notes and OpenSpec phase charter agree on what was shipped
- Ralph/team dry-runs target the same task file the humans are following

### Daily-Driver Gate

Daily-driver status requires:

- fresh-clone verification
- optimized local build
- app-shell open/edit/save/reopen flow
- deterministic export
- second-machine reproducibility

## Canonical Verification Commands

Current host-safe local verification:

```bash
bash scripts/verify-local.sh
bash scripts/verify-phase-16.sh
```

Phase dry-run surfaces:

```bash
bash scripts/ralph-loop.sh --task-file tasks/phase-16.md --dry-run --once
bash scripts/team-loop.sh --task-file tasks/phase-16.md --dry-run
```

Status surfaces:

```bash
npm run status:update
npm run status:check
npm run status:live
```

## Current Toolchain Exception

On this machine, Homebrew Zig `0.15.2` mislinks its native `zig build` runner
against the current macOS 26 host target. The repo therefore carries a direct
compile fallback that pins `aarch64-macos.15.0` for local verification on arm64
Darwin hosts.

This is a host/toolchain exception, not a permanent product promise. The goal is
still to restore the simpler `zig build` path once the host toolchain supports it.

## Release Gates

No release candidate is considered meaningful unless it includes:

- verified local tests
- verified runtime commands or replayed studies
- up-to-date status surfaces
- packaging artifacts when the touched slice affects distribution

## Generated Surface Rules

- `status/hyperdata.json` is the source of truth for generated status docs
- generated docs point to authoritative specs; they do not invent scope
- runtime verification commands belong in specs and scripts, not only in commit messages

# Daily-Driver OpenSpec

This directory is the authoritative planning bundle for the path from the current
CLI geometry tool to a realistic local daily-driver `blender-zig`.

Keep three layers distinct:

- product contract: what daily-driver means
- system and phase contracts: what each stage must accomplish
- execution files: what the Ralph/team loop should run next

Generated status docs are dashboards only. They point here; they do not define scope.

## Active Phase

- Phase 19
- phase charter: [openspec/daily-driver/phases/phase-19-viewport-and-tools.md](/Users/s3nik/Desktop/blender-zig/openspec/daily-driver/phases/phase-19-viewport-and-tools.md)
- active slice: [openspec/daily-driver/slices/phase-19-workflow-follow-through.md](/Users/s3nik/Desktop/blender-zig/openspec/daily-driver/slices/phase-19-workflow-follow-through.md)

## Doc Map

Authoritative product and system contracts:

- [daily-driver-contract.md](/Users/s3nik/Desktop/blender-zig/openspec/daily-driver/daily-driver-contract.md)
- [vision.md](/Users/s3nik/Desktop/blender-zig/openspec/daily-driver/vision.md)
- [design.md](/Users/s3nik/Desktop/blender-zig/openspec/daily-driver/design.md)
- [milestones.md](/Users/s3nik/Desktop/blender-zig/openspec/daily-driver/milestones.md)
- [execution.md](/Users/s3nik/Desktop/blender-zig/openspec/daily-driver/execution.md)
- [system/interchange-and-file-format-strategy.md](/Users/s3nik/Desktop/blender-zig/openspec/daily-driver/system/interchange-and-file-format-strategy.md)
- [system/stable-modeling-and-graph-path.md](/Users/s3nik/Desktop/blender-zig/openspec/daily-driver/system/stable-modeling-and-graph-path.md)
- [system/project-state-and-recovery.md](/Users/s3nik/Desktop/blender-zig/openspec/daily-driver/system/project-state-and-recovery.md)
- [system/verification-and-release-gates.md](/Users/s3nik/Desktop/blender-zig/openspec/daily-driver/system/verification-and-release-gates.md)

Phase charters:

- [phases/phase-16-modeling-stack.md](/Users/s3nik/Desktop/blender-zig/openspec/daily-driver/phases/phase-16-modeling-stack.md)
- [phases/phase-17-persistence-and-bundles.md](/Users/s3nik/Desktop/blender-zig/openspec/daily-driver/phases/phase-17-persistence-and-bundles.md)
- [phases/phase-18-app-shell.md](/Users/s3nik/Desktop/blender-zig/openspec/daily-driver/phases/phase-18-app-shell.md)
- [phases/phase-19-viewport-and-tools.md](/Users/s3nik/Desktop/blender-zig/openspec/daily-driver/phases/phase-19-viewport-and-tools.md)
- [phases/phase-20-hardening-and-release.md](/Users/s3nik/Desktop/blender-zig/openspec/daily-driver/phases/phase-20-hardening-and-release.md)

Current slice spec:

- [slices/phase-19-workflow-follow-through.md](/Users/s3nik/Desktop/blender-zig/openspec/daily-driver/slices/phase-19-workflow-follow-through.md)
- [slices/phase-19-focused-recipe-subdivide.md](/Users/s3nik/Desktop/blender-zig/openspec/daily-driver/slices/phase-19-focused-recipe-subdivide.md)

Compatibility pointers kept for older links:

- [docs/phase-16-plan.md](/Users/s3nik/Desktop/blender-zig/docs/phase-16-plan.md)
- [docs/specs/phase-16-constrained-edit.md](/Users/s3nik/Desktop/blender-zig/docs/specs/phase-16-constrained-edit.md)

## Phase-To-Milestone Map

- Phase 16 -> M1
- Phase 17 -> M2 and the persistence half of M3
- Phase 18 -> M4
- Phase 19 -> M5
- Phase 20 -> M6 and the recovery half of M3

## Execution Files

- [tasks/phase-16.md](/Users/s3nik/Desktop/blender-zig/tasks/phase-16.md)
- [tasks/phase-17.md](/Users/s3nik/Desktop/blender-zig/tasks/phase-17.md)
- [tasks/phase-18.md](/Users/s3nik/Desktop/blender-zig/tasks/phase-18.md)
- [tasks/phase-19.md](/Users/s3nik/Desktop/blender-zig/tasks/phase-19.md)
- [tasks/phase-20.md](/Users/s3nik/Desktop/blender-zig/tasks/phase-20.md)

## Generated Surfaces

- [README.md](/Users/s3nik/Desktop/blender-zig/README.md)
- [progress.md](/Users/s3nik/Desktop/blender-zig/progress.md)
- [ROADMAP.md](/Users/s3nik/Desktop/blender-zig/ROADMAP.md)

## Operating Rules

- change the contract here before widening implementation scope
- keep `tasks/*.md` execution-oriented
- keep generated docs generated
- keep compatibility pointers small and non-authoritative

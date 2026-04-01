# Daily-Driver OpenSpec

This folder is the active planning bundle for the path from the current repo state to a realistic daily-driver `blender-zig`.

Use it as the source of truth for the current slice. Keep the broader planning docs aligned to it instead of duplicating the same slice definition in multiple places.

## Files

- [vision.md](/Users/s3nik/Desktop/blender-zig/openspec/daily-driver/vision.md)
- [milestones.md](/Users/s3nik/Desktop/blender-zig/openspec/daily-driver/milestones.md)
- [execution.md](/Users/s3nik/Desktop/blender-zig/openspec/daily-driver/execution.md)

## Execution Files

Work the daily-driver path in order through these task files:

- [tasks/phase-16.md](/Users/s3nik/Desktop/blender-zig/tasks/phase-16.md)
- [tasks/phase-17.md](/Users/s3nik/Desktop/blender-zig/tasks/phase-17.md)
- [tasks/phase-18.md](/Users/s3nik/Desktop/blender-zig/tasks/phase-18.md)
- [tasks/phase-19.md](/Users/s3nik/Desktop/blender-zig/tasks/phase-19.md)
- [tasks/phase-20.md](/Users/s3nik/Desktop/blender-zig/tasks/phase-20.md)

Use the milestone file to understand why a phase exists, then use the phase task file to drive the actual loop.

## Operating Rules

- If the daily-driver definition changes, update this bundle first.
- If phase numbering changes, clean up `tasks/zig-rewrite.md` in the same batch.
- If a slice is not runnable and testable, it is not ready to land.

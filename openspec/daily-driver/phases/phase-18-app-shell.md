# Phase 18: App Shell

## Intent

Bridge the geometry kernel and durable project state into a small native shell so
work is no longer trapped behind one-off CLI invocations.

## Workflows Unlocked

- open local work from an app shell
- inspect and save without scripting commands manually
- keep the CLI and shell pointed at the same underlying project model

## In Scope

- minimal native shell
- session lifecycle
- open/save bridge to project state
- shell-level error handling

## Exit Criteria

- shell can open current project or study state
- shell can save changes back through the documented persistence path
- shell path does not fork the geometry logic away from the CLI

## Execution Surface

- [tasks/phase-18.md](/Users/s3nik/Desktop/blender-zig/tasks/phase-18.md)

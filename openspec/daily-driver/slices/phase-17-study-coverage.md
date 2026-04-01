# Phase 17 Slice: Study Coverage

## Goal

Exercise the new replay metadata and bundle path with a small set of practical,
edit-heavy studies instead of only synthetic verification geometry.

## Scope

In scope:

- at least two replayable `.bzrecipe` studies under `recipes/phase-17/`
- one `.bzscene` that composes those studies with an imported `.obj` part
- varied seed choice, edit selection shape, and persisted placement
- verification through `mesh-pipeline`, `mesh-scene`, and one persisted roundtrip

Out of scope:

- new operator semantics
- shell or viewport work
- project/session state
- new import formats

## Study Set

The phase-17 study set should prove all of these:

- one study uses explicit face-domain selection through `delete-face:index=...`
- one study uses the constrained shared-edge path through `bevel-edge`, `delete-edge`, or `dissolve`
- at least one study stores recipe-level transforms so replay preserves authored placement
- one composed scene uses scene-level placement plus one imported `.obj` reference

## Acceptance Criteria

This slice is complete only when all of these are true:

- two or more replayable phase-17 studies exist with replay metadata
- one scene composes those studies and one imported asset reference
- the studies replay through `mesh-pipeline`
- the scene replays through `mesh-scene`
- the scene result can roundtrip through the documented import or bundle path

## Verification

```bash
bash scripts/verify-phase-17.sh
./zig-out/bin/blender-zig-direct mesh-pipeline --recipe recipes/phase-17/pocket-platform-study.bzrecipe
./zig-out/bin/blender-zig-direct mesh-pipeline --recipe recipes/phase-17/rail-bevel-study.bzrecipe
./zig-out/bin/blender-zig-direct mesh-scene --recipe recipes/phase-17/persistence-workbench.bzscene
./zig-out/bin/blender-zig-direct mesh-import zig-out/phase-17-persistence-workbench.obj zig-out/phase-17-persistence-workbench-roundtrip.obj
```

## Follow-On Slice

Once these studies are green, the next honest phase-17 work is workflow
follow-through against `tasks/phase-17.md`, then the first shell scope in phase
18.

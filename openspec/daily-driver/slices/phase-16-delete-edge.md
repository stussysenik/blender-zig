# Phase 16 Slice: Delete Edge

This is the canonical slice contract for the current constrained-edit landing.

## Intent

Add one bounded edge-domain delete operator that pairs cleanly with the existing
face delete, inset-region, and extrude-region stack.

## Operator

Primary operator target: `mesh-delete-edge`

## Scope

- delete one selected edge only
- if the edge is loose, remove only that loose edge
- if the edge has one or two incident faces, delete those faces and keep the exposed border as loose wire
- preserve surviving vertices, unrelated loose edges, and untouched attributes
- reject ambiguous multi-edge or non-manifold selections deterministically

## Non-Goals

- no general dissolve
- no broad repair pass
- no multi-edge region inference
- no delete-mode matrix

## Verification Matrix

- loose-edge removal keeps the rest of the wire
- boundary-edge delete removes the single incident face
- shared-edge delete removes both incident faces and leaves a loose perimeter
- invalid, multi-edge, and non-manifold selections fail deterministically
- direct CLI path emits the expected counts
- pipeline recipe emits the same result

## Canonical Verification Commands

```bash
bash scripts/verify-phase-16.sh
```

Expected runtime counts:

- `mesh-delete-edge`: `vertices=6 edges=6 faces=0`
- `mesh-pipeline --recipe recipes/phase-16/wire-cleanup.bzrecipe`: `vertices=6 edges=6 faces=0`

## Implementation Files

- [src/geometry/mesh_delete_edge.zig](/Users/s3nik/Desktop/blender-zig/src/geometry/mesh_delete_edge.zig)
- [src/pipeline.zig](/Users/s3nik/Desktop/blender-zig/src/pipeline.zig)
- [src/main.zig](/Users/s3nik/Desktop/blender-zig/src/main.zig)

## Execution Surface

- [tasks/phase-16.md](/Users/s3nik/Desktop/blender-zig/tasks/phase-16.md)

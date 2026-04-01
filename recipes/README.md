# Recipe Format

`mesh-pipeline` can run directly from saved recipe files:

```bash
zig build run -- mesh-pipeline --recipe recipes/grid-study.bzrecipe
```

The format is intentionally line-oriented and reuses the same step tokens as the CLI:

```text
# blender-zig pipeline v1
seed=grid:verts-x=8,verts-y=5,size-x=4.0,size-y=2.0,uvs=true
write=../zig-out/grid-study.obj

step=subdivide:repeat=2
step=extrude:distance=0.75
step=inset:factor=0.1
```

Rules:

- `seed=` is required and must appear once.
- optional replay metadata keys can appear before `seed=`:
  - `format-version`: currently only `1`
  - `id`: stable replay identifier
  - `title`: human-readable label
- seed parameters use the same `name:param=value,...` grammar as steps.
- supported seed overrides:
  - `grid`: `verts-x`, `verts-y`, `size-x`, `size-y`, `uvs`
  - `cuboid`: `size-x`, `size-y`, `size-z`, `verts-x`, `verts-y`, `verts-z`, `uvs`
  - `cylinder`: `radius`, `height`, `segments`, `top-cap`, `bottom-cap`, `uvs`
  - `sphere`: `radius`, `segments`, `rings`, `uvs`
- `write=` is optional and, when relative, resolves from the recipe file's directory.
- `step=` can appear many times and runs in file order.
- blank lines and `#` comments are ignored.
- step parameter syntax is exactly the same as inline `mesh-pipeline` usage.
- metadata-bearing recipes print their replay metadata during CLI runs.
- transform and composition steps currently supported:
  - `translate`: `x`, `y`, `z`
  - `scale`: `x`, `y`, `z`
  - `rotate-z`: `degrees`
  - `array`: either `count` with `offset-x`, `offset-y`, `offset-z`, or axis counts like `count-x`, `count-y`, `count-z`

Checked-in studies:

- [grid-study.bzrecipe](/Users/s3nik/Desktop/blender-zig/recipes/grid-study.bzrecipe): wider grid seed with explicit resolution and bounds, then subdivide + extrude + inset.
- [cuboid-facet-study.bzrecipe](/Users/s3nik/Desktop/blender-zig/recipes/cuboid-facet-study.bzrecipe): sized cuboid seed with explicit face counts, then subdivide + extrude + triangulate to ASCII PLY.
- [cylinder-panel-study.bzrecipe](/Users/s3nik/Desktop/blender-zig/recipes/cylinder-panel-study.bzrecipe): taller segmented cylinder seed, then inset + extrude + triangulate.

Transform and array studies:

- [courtyard-plaza-study.bzrecipe](/Users/s3nik/Desktop/blender-zig/recipes/courtyard-plaza-study.bzrecipe): a tiled plaza study that reads as translate + scale + grid repetition.
- [walkway-bays-study.bzrecipe](/Users/s3nik/Desktop/blender-zig/recipes/walkway-bays-study.bzrecipe): a short cuboid run that reads as staggered bays through scale + linear array + rotate-z.
- [tower-stack-study.bzrecipe](/Users/s3nik/Desktop/blender-zig/recipes/tower-stack-study.bzrecipe): a vertical cylinder stack for checking Z repetition and transform order.

Phase-16 edit-heavy studies:

- [phase-16/wire-cleanup.bzrecipe](/Users/s3nik/Desktop/blender-zig/recipes/phase-16/wire-cleanup.bzrecipe): the minimal constrained-edit baseline that deletes one shared edge and leaves a loose perimeter.
- [phase-16/wire-rebuild.bzrecipe](/Users/s3nik/Desktop/blender-zig/recipes/phase-16/wire-rebuild.bzrecipe): rebuilds that loose perimeter into a filled, inset, and extruded plate.
- [phase-16/panel-lift.bzrecipe](/Users/s3nik/Desktop/blender-zig/recipes/phase-16/panel-lift.bzrecipe): removes one panel face, then runs open-region inset and extrusion on the surrounding surface.
- [phase-16/chamfer-recovery.bzrecipe](/Users/s3nik/Desktop/blender-zig/recipes/phase-16/chamfer-recovery.bzrecipe): chains bevel, constrained edge delete, dissolve, inset, and extrusion on a thin cuboid.

Phase-17 persistence studies:

- [phase-17/pocket-platform-study.bzrecipe](/Users/s3nik/Desktop/blender-zig/recipes/phase-17/pocket-platform-study.bzrecipe): a grid-based pocket study with explicit face selection, open-region repair, and recipe-owned placement.
- [phase-17/rail-bevel-study.bzrecipe](/Users/s3nik/Desktop/blender-zig/recipes/phase-17/rail-bevel-study.bzrecipe): a cuboid rail study that replays shared-edge growth, constrained deletion, dissolve, and recipe-owned placement.
- [phase-19/viewport-gallery.bzscene](/Users/s3nik/Desktop/blender-zig/recipes/phase-19/viewport-gallery.bzscene): the current viewport demo scene, composed to keep several replayable forms and one imported ground plate visible in the same camera orbit.

These studies are meant to stay contributor-readable, with comments that explain the intended shape rather than the low-level mechanics.

Scene recipes for `mesh-scene` use the same line-oriented style, but they compose
existing studies or meshes instead of generating a single study from a seed:

```text
# blender-zig scene v1
# Combine two existing studies into one exported scene.

part=courtyard-plaza-study.bzrecipe
part=tower-stack-study.bzrecipe|translate:x=1.1,y=-0.2,z=0.0|rotate-z:degrees=18
write=../zig-out/courtyard-tower-scene.obj
```

Rules for scene recipes:

- optional replay metadata keys can appear before the first `part=`:
  - `format-version`: currently only `1`
  - `id`: stable replay identifier
  - `title`: human-readable label
- `part=` is required and can appear many times.
- each `part=` must point at an existing `.bzrecipe` study or `.obj` asset.
- placement tokens can follow the part path with `|`, reusing the existing pipeline
  step grammar for `translate`, `scale`, and `rotate-z`.
- `write=` is optional and, when relative, resolves from the scene recipe's directory.
- scene parts are appended in file order after any scene-level placement tokens are applied.
- `#` comments should explain the intended composition so the file stays readable for contributors.
- metadata-bearing scenes print their replay metadata during CLI runs.

Checked-in scene recipes:

- [courtyard-tower-scene.bzscene](/Users/s3nik/Desktop/blender-zig/recipes/courtyard-tower-scene.bzscene): the courtyard plaza study paired with the tower stack study.
- [walkway-plaza-scene.bzscene](/Users/s3nik/Desktop/blender-zig/recipes/walkway-plaza-scene.bzscene): the walkway bays study paired with the courtyard plaza study.
- [phase-16/modeling-bench.bzscene](/Users/s3nik/Desktop/blender-zig/recipes/phase-16/modeling-bench.bzscene): a single review scene that composes the phase-16 edit studies with scene-owned placement.
- [phase-17/persistence-workbench.bzscene](/Users/s3nik/Desktop/blender-zig/recipes/phase-17/persistence-workbench.bzscene): a phase-17 persistence scene that composes replayable studies with one imported OBJ plate.

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

These studies are meant to stay contributor-readable, with comments that explain the intended shape rather than the low-level mechanics.

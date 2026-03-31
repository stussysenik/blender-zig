# Recipe Format

`mesh-pipeline` can run directly from saved recipe files:

```bash
zig build run -- mesh-pipeline --recipe recipes/grid-study.bzrecipe
```

The format is intentionally line-oriented and reuses the same step tokens as the CLI:

```text
# blender-zig pipeline v1
seed=grid
write=../zig-out/grid-study.obj

step=subdivide:repeat=2
step=extrude:distance=0.75
step=inset:factor=0.1
```

Rules:

- `seed=` is required and must appear once.
- `write=` is optional and, when relative, resolves from the recipe file's directory.
- `step=` can appear many times and runs in file order.
- blank lines and `#` comments are ignored.
- step parameter syntax is exactly the same as inline `mesh-pipeline` usage.

Checked-in studies:

- [grid-study.bzrecipe](/Users/s3nik/Desktop/blender-zig/recipes/grid-study.bzrecipe): subdivide + extrude + inset on the flat grid seed.
- [cuboid-facet-study.bzrecipe](/Users/s3nik/Desktop/blender-zig/recipes/cuboid-facet-study.bzrecipe): subdivide + extrude + triangulate, written to ASCII PLY.
- [cylinder-panel-study.bzrecipe](/Users/s3nik/Desktop/blender-zig/recipes/cylinder-panel-study.bzrecipe): inset + extrude + triangulate on the cylindrical seed.

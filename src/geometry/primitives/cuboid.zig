const std = @import("std");
const math = @import("../../math.zig");
const mesh_mod = @import("../../mesh.zig");

const LatticeKey = struct {
    x: u32,
    y: u32,
    z: u32,
};

pub fn createCuboidMesh(
    allocator: std.mem.Allocator,
    size: math.Vec3,
    verts_x: usize,
    verts_y: usize,
    verts_z: usize,
    with_uvs: bool,
) !mesh_mod.Mesh {
    if (verts_x < 2 or verts_y < 2 or verts_z < 2) return error.InvalidResolution;

    var mesh = try mesh_mod.Mesh.init(allocator);
    errdefer mesh.deinit();

    var lookup = std.AutoHashMap(LatticeKey, u32).init(allocator);
    defer lookup.deinit();

    const max_x = verts_x - 1;
    const max_y = verts_y - 1;
    const max_z = verts_z - 1;

    const Helpers = struct {
        fn getOrCreateVertex(
            local_mesh: *mesh_mod.Mesh,
            map: *std.AutoHashMap(LatticeKey, u32),
            cuboid_size: math.Vec3,
            x: usize,
            y: usize,
            z: usize,
            mx: usize,
            my: usize,
            mz: usize,
        ) !u32 {
            const key = LatticeKey{
                .x = @intCast(x),
                .y = @intCast(y),
                .z = @intCast(z),
            };
            if (map.get(key)) |existing| return existing;

            const position = math.Vec3{
                .x = interpolateAxis(cuboid_size.x, x, mx),
                .y = interpolateAxis(cuboid_size.y, y, my),
                .z = interpolateAxis(cuboid_size.z, z, mz),
            };
            const index = try local_mesh.appendVertex(position);
            try map.put(key, index);
            return index;
        }

        fn interpolateAxis(size_axis: f32, index: usize, max_index: usize) f32 {
            if (max_index == 0) return 0;
            const t = @as(f32, @floatFromInt(index)) / @as(f32, @floatFromInt(max_index));
            return -size_axis * 0.5 + size_axis * t;
        }

        fn appendQuad(
            local_mesh: *mesh_mod.Mesh,
            map: *std.AutoHashMap(LatticeKey, u32),
            cuboid_size: math.Vec3,
            a: [3]usize,
            b: [3]usize,
            c: [3]usize,
            d: [3]usize,
            mx: usize,
            my: usize,
            mz: usize,
            maybe_uvs: ?[]const math.Vec2,
        ) !void {
            const verts = [_]u32{
                try getOrCreateVertex(local_mesh, map, cuboid_size, a[0], a[1], a[2], mx, my, mz),
                try getOrCreateVertex(local_mesh, map, cuboid_size, b[0], b[1], b[2], mx, my, mz),
                try getOrCreateVertex(local_mesh, map, cuboid_size, c[0], c[1], c[2], mx, my, mz),
                try getOrCreateVertex(local_mesh, map, cuboid_size, d[0], d[1], d[2], mx, my, mz),
            };
            try local_mesh.appendFace(&verts, maybe_uvs);
        }
    };

    const uv_quad = [_]math.Vec2{
        .{ .x = 0, .y = 0 },
        .{ .x = 1, .y = 0 },
        .{ .x = 1, .y = 1 },
        .{ .x = 0, .y = 1 },
    };
    const maybe_uvs: ?[]const math.Vec2 = if (with_uvs) &uv_quad else null;

    for (0..max_x) |x| {
        for (0..max_y) |y| {
            try Helpers.appendQuad(&mesh, &lookup, size, .{ x, y, 0 }, .{ x + 1, y, 0 }, .{ x + 1, y + 1, 0 }, .{ x, y + 1, 0 }, max_x, max_y, max_z, maybe_uvs);
            try Helpers.appendQuad(&mesh, &lookup, size, .{ x, y + 1, max_z }, .{ x + 1, y + 1, max_z }, .{ x + 1, y, max_z }, .{ x, y, max_z }, max_x, max_y, max_z, maybe_uvs);
        }
    }

    for (0..max_x) |x| {
        for (0..max_z) |z| {
            try Helpers.appendQuad(&mesh, &lookup, size, .{ x, 0, z }, .{ x + 1, 0, z }, .{ x + 1, 0, z + 1 }, .{ x, 0, z + 1 }, max_x, max_y, max_z, maybe_uvs);
            try Helpers.appendQuad(&mesh, &lookup, size, .{ x, max_y, z + 1 }, .{ x + 1, max_y, z + 1 }, .{ x + 1, max_y, z }, .{ x, max_y, z }, max_x, max_y, max_z, maybe_uvs);
        }
    }

    for (0..max_y) |y| {
        for (0..max_z) |z| {
            try Helpers.appendQuad(&mesh, &lookup, size, .{ 0, y, z + 1 }, .{ 0, y + 1, z + 1 }, .{ 0, y + 1, z }, .{ 0, y, z }, max_x, max_y, max_z, maybe_uvs);
            try Helpers.appendQuad(&mesh, &lookup, size, .{ max_x, y, z }, .{ max_x, y + 1, z }, .{ max_x, y + 1, z + 1 }, .{ max_x, y, z + 1 }, max_x, max_y, max_z, maybe_uvs);
        }
    }

    try mesh.rebuildEdgesFromFaces();
    return mesh;
}

test "cuboid reuses boundary vertices" {
    var mesh = try createCuboidMesh(std.testing.allocator, math.Vec3.init(2, 3, 4), 2, 2, 2, false);
    defer mesh.deinit();

    try std.testing.expectEqual(@as(usize, 8), mesh.positions.items.len);
    try std.testing.expectEqual(@as(usize, 6), mesh.faceCount());
    try std.testing.expectEqual(@as(usize, 12), mesh.edges.items.len);
}

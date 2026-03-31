const std = @import("std");
const math = @import("../math.zig");
const mesh_mod = @import("../mesh.zig");

// Delete-loose is the narrow cleanup companion to the direct modeling ops: keep only
// vertices that participate in faces, preserve those faces and their UVs, and drop
// loose edges or isolated points that would otherwise pollute bounds or exports.
pub fn deleteLoose(
    allocator: std.mem.Allocator,
    mesh: *const mesh_mod.Mesh,
) !mesh_mod.Mesh {
    var result = try mesh_mod.Mesh.init(allocator);
    errdefer result.deinit();

    if (mesh.faceCount() == 0) {
        return result;
    }

    const used_vertices = try allocator.alloc(bool, mesh.vertexCount());
    defer allocator.free(used_vertices);
    @memset(used_vertices, false);

    for (mesh.corner_verts.items) |vertex| {
        used_vertices[vertex] = true;
    }

    const remap = try allocator.alloc(u32, mesh.vertexCount());
    defer allocator.free(remap);
    @memset(remap, std.math.maxInt(u32));

    for (mesh.positions.items, 0..) |position, old_index| {
        if (!used_vertices[old_index]) continue;
        remap[old_index] = try result.appendVertex(position);
    }

    const has_corner_uvs = mesh.hasCornerUvs();
    for (0..mesh.faceCount()) |face_index| {
        const range = mesh.faceVertexRange(face_index);
        const source_verts = mesh.corner_verts.items[range.start..range.end];
        const source_uvs = if (has_corner_uvs) mesh.corner_uvs.items[range.start..range.end] else &[_]math.Vec2{};

        const remapped_verts = try allocator.alloc(u32, source_verts.len);
        defer allocator.free(remapped_verts);

        for (source_verts, 0..) |vertex, local_index| {
            remapped_verts[local_index] = remap[vertex];
        }

        const maybe_uvs: ?[]const math.Vec2 = if (has_corner_uvs) source_uvs else null;
        try result.appendFace(remapped_verts, maybe_uvs);
    }

    try result.rebuildEdgesFromFaces();
    return result;
}

fn hasEdge(mesh: *const mesh_mod.Mesh, a: u32, b: u32) bool {
    const lo = @min(a, b);
    const hi = @max(a, b);
    for (mesh.edges.items) |edge| {
        if (edge.a == lo and edge.b == hi) return true;
    }
    return false;
}

test "delete loose preserves faces and drops loose edges or isolated points" {
    var mesh = try mesh_mod.Mesh.init(std.testing.allocator);
    defer mesh.deinit();

    _ = try mesh.appendVertex(.{ .x = -1, .y = -1, .z = 0 });
    _ = try mesh.appendVertex(.{ .x = 1, .y = -1, .z = 0 });
    _ = try mesh.appendVertex(.{ .x = 1, .y = 1, .z = 0 });
    _ = try mesh.appendVertex(.{ .x = -1, .y = 1, .z = 0 });
    _ = try mesh.appendVertex(.{ .x = 4, .y = 0, .z = 0 });
    _ = try mesh.appendVertex(.{ .x = 5, .y = 0, .z = 0 });
    _ = try mesh.appendVertex(.{ .x = 9, .y = 2, .z = 0 });

    const quad_uvs = [_]math.Vec2{
        .{ .x = 0, .y = 0 },
        .{ .x = 1, .y = 0 },
        .{ .x = 1, .y = 1 },
        .{ .x = 0, .y = 1 },
    };
    try mesh.appendFace(&[_]u32{ 0, 1, 2, 3 }, &quad_uvs);
    try mesh.rebuildEdgesFromFaces();
    try mesh.appendEdge(4, 5);

    var cleaned = try deleteLoose(std.testing.allocator, &mesh);
    defer cleaned.deinit();

    try std.testing.expectEqual(@as(usize, 4), cleaned.vertexCount());
    try std.testing.expectEqual(@as(usize, 1), cleaned.faceCount());
    try std.testing.expectEqual(@as(usize, 4), cleaned.edges.items.len);
    try std.testing.expect(cleaned.hasCornerUvs());
    try std.testing.expectEqual(@as(usize, 4), cleaned.corner_uvs.items.len);
    try std.testing.expectEqualSlices(u32, &[_]u32{ 0, 1, 2, 3 }, cleaned.corner_verts.items);
    try std.testing.expect(!hasEdge(&cleaned, 4, 5));
    try std.testing.expect(cleaned.bounds != null);
    try std.testing.expect(math.vec3ApproxEq(cleaned.bounds.?.min, .{ .x = -1, .y = -1, .z = 0 }, 0.0001));
    try std.testing.expect(math.vec3ApproxEq(cleaned.bounds.?.max, .{ .x = 1, .y = 1, .z = 0 }, 0.0001));
}

test "delete loose turns edge-only meshes into empty meshes" {
    var mesh = try mesh_mod.Mesh.init(std.testing.allocator);
    defer mesh.deinit();

    _ = try mesh.appendVertex(.{ .x = 0, .y = 0, .z = 0 });
    _ = try mesh.appendVertex(.{ .x = 1, .y = 0, .z = 0 });
    _ = try mesh.appendVertex(.{ .x = 2, .y = 0, .z = 0 });
    try mesh.appendEdge(0, 1);
    try mesh.appendEdge(1, 2);

    var cleaned = try deleteLoose(std.testing.allocator, &mesh);
    defer cleaned.deinit();

    try std.testing.expectEqual(@as(usize, 0), cleaned.vertexCount());
    try std.testing.expectEqual(@as(usize, 0), cleaned.faceCount());
    try std.testing.expectEqual(@as(usize, 0), cleaned.edges.items.len);
    try std.testing.expect(cleaned.bounds == null);
}

test "delete loose keeps shared face topology while compacting surviving vertices" {
    var mesh = try mesh_mod.Mesh.init(std.testing.allocator);
    defer mesh.deinit();

    _ = try mesh.appendVertex(.{ .x = -1, .y = -1, .z = 0 });
    _ = try mesh.appendVertex(.{ .x = 0, .y = -1, .z = 0 });
    _ = try mesh.appendVertex(.{ .x = 0, .y = 1, .z = 0 });
    _ = try mesh.appendVertex(.{ .x = -1, .y = 1, .z = 0 });
    _ = try mesh.appendVertex(.{ .x = 1, .y = -1, .z = 0 });
    _ = try mesh.appendVertex(.{ .x = 1, .y = 1, .z = 0 });
    _ = try mesh.appendVertex(.{ .x = 12, .y = 0, .z = 0 });

    try mesh.appendFace(&[_]u32{ 0, 1, 2, 3 }, null);
    try mesh.appendFace(&[_]u32{ 1, 4, 5, 2 }, null);
    try mesh.rebuildEdgesFromFaces();
    try mesh.appendEdge(5, 6);

    var cleaned = try deleteLoose(std.testing.allocator, &mesh);
    defer cleaned.deinit();

    try std.testing.expectEqual(@as(usize, 6), cleaned.vertexCount());
    try std.testing.expectEqual(@as(usize, 2), cleaned.faceCount());
    try std.testing.expectEqual(@as(usize, 7), cleaned.edges.items.len);
    try std.testing.expectEqualSlices(u32, &[_]u32{
        0, 1, 2, 3,
        1, 4, 5, 2,
    }, cleaned.corner_verts.items);
}

const std = @import("std");
const math = @import("../math.zig");
const mesh_mod = @import("../mesh.zig");

// This is intentionally narrow for the current rewrite stage: it fan-triangulates
// convex polygon faces while preserving corner UV alignment and loose edges.
pub fn triangulateMesh(
    allocator: std.mem.Allocator,
    mesh: *const mesh_mod.Mesh,
) !mesh_mod.Mesh {
    var result = try mesh_mod.Mesh.init(allocator);
    errdefer result.deinit();

    for (mesh.positions.items) |position| {
        _ = try result.appendVertex(position);
    }

    // Track which source edges came from faces so any extra loose edges can be appended
    // back afterwards without duplicating the face-derived edge table.
    var face_edge_keys = std.AutoHashMap(u64, void).init(allocator);
    defer face_edge_keys.deinit();

    const has_corner_uvs = mesh.hasCornerUvs();

    for (0..mesh.faceCount()) |face_index| {
        const range = mesh.faceVertexRange(face_index);
        const face_verts = mesh.corner_verts.items[range.start..range.end];
        if (face_verts.len < 3) return error.InvalidFace;

        const maybe_face_uvs: ?[]const math.Vec2 = if (has_corner_uvs) mesh.corner_uvs.items[range.start..range.end] else null;

        for (face_verts, 0..) |vert, local_index| {
            const next_vert = face_verts[(local_index + 1) % face_verts.len];
            try face_edge_keys.put(packUndirectedEdge(vert, next_vert), {});
        }

        if (face_verts.len == 3) {
            try result.appendFace(face_verts, maybe_face_uvs);
            continue;
        }

        for (1..face_verts.len - 1) |triangle_index| {
            const tri_verts = [_]u32{
                face_verts[0],
                face_verts[triangle_index],
                face_verts[triangle_index + 1],
            };
            if (maybe_face_uvs) |face_uvs| {
                const tri_uvs = [_]math.Vec2{
                    face_uvs[0],
                    face_uvs[triangle_index],
                    face_uvs[triangle_index + 1],
                };
                try result.appendFace(&tri_verts, &tri_uvs);
            } else {
                try result.appendFace(&tri_verts, null);
            }
        }
    }

    try result.rebuildEdgesFromFaces();

    for (mesh.edges.items) |edge| {
        if (!face_edge_keys.contains(packUndirectedEdge(edge.a, edge.b))) {
            try result.appendEdge(edge.a, edge.b);
        }
    }

    return result;
}

fn packUndirectedEdge(a: u32, b: u32) u64 {
    const lo = @min(a, b);
    const hi = @max(a, b);
    return (@as(u64, hi) << 32) | @as(u64, lo);
}

fn hasEdge(mesh: *const mesh_mod.Mesh, a: u32, b: u32) bool {
    for (mesh.edges.items) |edge| {
        if ((edge.a == a and edge.b == b) or (edge.a == b and edge.b == a)) {
            return true;
        }
    }
    return false;
}

test "triangulate mesh fans quads while preserving loose edges and uvs" {
    var mesh = try mesh_mod.Mesh.init(std.testing.allocator);
    defer mesh.deinit();

    _ = try mesh.appendVertex(.{ .x = -1, .y = -1, .z = 0 });
    _ = try mesh.appendVertex(.{ .x = 1, .y = -1, .z = 0 });
    _ = try mesh.appendVertex(.{ .x = 1, .y = 1, .z = 0 });
    _ = try mesh.appendVertex(.{ .x = -1, .y = 1, .z = 0 });
    _ = try mesh.appendVertex(.{ .x = 3, .y = 0, .z = 0 });
    _ = try mesh.appendVertex(.{ .x = 4, .y = 0, .z = 0 });

    const quad_uvs = [_]math.Vec2{
        .{ .x = 0, .y = 0 },
        .{ .x = 1, .y = 0 },
        .{ .x = 1, .y = 1 },
        .{ .x = 0, .y = 1 },
    };
    try mesh.appendFace(&[_]u32{ 0, 1, 2, 3 }, &quad_uvs);
    try mesh.rebuildEdgesFromFaces();
    try mesh.appendEdge(4, 5);

    var triangulated = try triangulateMesh(std.testing.allocator, &mesh);
    defer triangulated.deinit();

    try std.testing.expectEqual(@as(usize, 6), triangulated.vertexCount());
    try std.testing.expectEqual(@as(usize, 2), triangulated.faceCount());
    try std.testing.expectEqual(@as(usize, 6), triangulated.edges.items.len);
    try std.testing.expect(triangulated.hasCornerUvs());
    try std.testing.expectEqual(@as(usize, 6), triangulated.corner_uvs.items.len);
    try std.testing.expectEqualSlices(u32, &[_]u32{ 0, 1, 2, 0, 2, 3 }, triangulated.corner_verts.items);
    try std.testing.expect(math.vec2ApproxEq(triangulated.corner_uvs.items[0], quad_uvs[0], 0.0001));
    try std.testing.expect(math.vec2ApproxEq(triangulated.corner_uvs.items[4], quad_uvs[2], 0.0001));
    try std.testing.expect(hasEdge(&triangulated, 4, 5));
    try std.testing.expect(triangulated.bounds != null);
    try std.testing.expect(math.vec3ApproxEq(triangulated.bounds.?.min, .{ .x = -1, .y = -1, .z = 0 }, 0.0001));
    try std.testing.expect(math.vec3ApproxEq(triangulated.bounds.?.max, .{ .x = 4, .y = 1, .z = 0 }, 0.0001));

    for (0..triangulated.faceCount()) |face_index| {
        const range = triangulated.faceVertexRange(face_index);
        try std.testing.expectEqual(@as(usize, 3), range.end - range.start);
    }
}

test "triangulate mesh fans ngons in source corner order" {
    var mesh = try mesh_mod.Mesh.init(std.testing.allocator);
    defer mesh.deinit();

    _ = try mesh.appendVertex(.{ .x = 0, .y = 0, .z = 0 });
    _ = try mesh.appendVertex(.{ .x = 2, .y = 0, .z = 0 });
    _ = try mesh.appendVertex(.{ .x = 3, .y = 1, .z = 0 });
    _ = try mesh.appendVertex(.{ .x = 1.5, .y = 3, .z = 0 });
    _ = try mesh.appendVertex(.{ .x = 0, .y = 2, .z = 0 });

    try mesh.appendFace(&[_]u32{ 0, 1, 2, 3, 4 }, null);

    var triangulated = try triangulateMesh(std.testing.allocator, &mesh);
    defer triangulated.deinit();

    try std.testing.expectEqual(@as(usize, 3), triangulated.faceCount());
    try std.testing.expectEqualSlices(u32, &[_]u32{
        0, 1, 2,
        0, 2, 3,
        0, 3, 4,
    }, triangulated.corner_verts.items);
}

test "triangulate mesh leaves loose-edge meshes untouched" {
    var mesh = try mesh_mod.Mesh.init(std.testing.allocator);
    defer mesh.deinit();

    _ = try mesh.appendVertex(.{ .x = 0, .y = 0, .z = 0 });
    _ = try mesh.appendVertex(.{ .x = 1, .y = 0, .z = 0 });
    _ = try mesh.appendVertex(.{ .x = 2, .y = 0, .z = 0 });
    try mesh.appendEdge(0, 1);
    try mesh.appendEdge(1, 2);

    var triangulated = try triangulateMesh(std.testing.allocator, &mesh);
    defer triangulated.deinit();

    try std.testing.expectEqual(@as(usize, 3), triangulated.vertexCount());
    try std.testing.expectEqual(@as(usize, 0), triangulated.faceCount());
    try std.testing.expectEqual(@as(usize, 2), triangulated.edges.items.len);
    try std.testing.expect(hasEdge(&triangulated, 0, 1));
    try std.testing.expect(hasEdge(&triangulated, 1, 2));
}

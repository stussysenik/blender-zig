const std = @import("std");
const math = @import("../math.zig");
const mesh_mod = @import("../mesh.zig");

pub const InsetOptions = struct {
    factor: f32 = 0.25,
};

// Start with the individual-face inset case because it fits the current mesh model:
// every source face can be processed independently without needing a full region graph.
pub fn insetIndividual(
    allocator: std.mem.Allocator,
    mesh: *const mesh_mod.Mesh,
    options: InsetOptions,
) !mesh_mod.Mesh {
    if (options.factor <= 0.0 or options.factor >= 1.0) return error.InvalidInsetFactor;

    var result = try mesh_mod.Mesh.init(allocator);
    errdefer result.deinit();

    for (mesh.positions.items) |position| {
        _ = try result.appendVertex(position);
    }

    var source_face_edge_keys = std.AutoHashMap(u64, void).init(allocator);
    defer source_face_edge_keys.deinit();

    const has_corner_uvs = mesh.hasCornerUvs();
    for (0..mesh.faceCount()) |face_index| {
        const range = mesh.faceVertexRange(face_index);
        const face_verts = mesh.corner_verts.items[range.start..range.end];
        if (face_verts.len < 3) return error.InvalidFace;

        const face_uvs = if (has_corner_uvs) mesh.corner_uvs.items[range.start..range.end] else &[_]math.Vec2{};

        for (face_verts, 0..) |vertex, local_index| {
            const next_vertex = face_verts[(local_index + 1) % face_verts.len];
            try source_face_edge_keys.put(packUndirectedEdge(vertex, next_vertex), {});
        }

        const centroid = faceCentroid(mesh, face_verts);
        const uv_centroid = if (has_corner_uvs) faceUvCentroid(face_uvs) else math.Vec2.init(0, 0);

        var inner_verts = std.ArrayList(u32).empty;
        defer inner_verts.deinit(allocator);
        var inner_uvs = std.ArrayList(math.Vec2).empty;
        defer inner_uvs.deinit(allocator);

        for (face_verts, 0..) |vertex, local_index| {
            const position = mesh.positions.items[vertex];
            const inner_position = lerpVec3(position, centroid, options.factor);
            try inner_verts.append(allocator, try result.appendVertex(inner_position));
            if (has_corner_uvs) {
                try inner_uvs.append(allocator, lerpVec2(face_uvs[local_index], uv_centroid, options.factor));
            }
        }

        // Build quads between each outer edge and the corresponding inner edge, then
        // cap the inset with a new inner face.
        for (face_verts, 0..) |outer_vertex, local_index| {
            const next_index = (local_index + 1) % face_verts.len;
            const side_face = [_]u32{
                outer_vertex,
                face_verts[next_index],
                inner_verts.items[next_index],
                inner_verts.items[local_index],
            };
            if (has_corner_uvs) {
                const side_uvs = [_]math.Vec2{
                    face_uvs[local_index],
                    face_uvs[next_index],
                    inner_uvs.items[next_index],
                    inner_uvs.items[local_index],
                };
                try result.appendFace(&side_face, &side_uvs);
            } else {
                try result.appendFace(&side_face, null);
            }
        }

        const maybe_inner_uvs: ?[]const math.Vec2 = if (has_corner_uvs) inner_uvs.items else null;
        try result.appendFace(inner_verts.items, maybe_inner_uvs);
    }

    try result.rebuildEdgesFromFaces();

    var result_face_edge_keys = std.AutoHashMap(u64, void).init(allocator);
    defer result_face_edge_keys.deinit();
    for (result.edges.items) |edge| {
        try result_face_edge_keys.put(packUndirectedEdge(edge.a, edge.b), {});
    }

    for (mesh.edges.items) |edge| {
        if (source_face_edge_keys.contains(packUndirectedEdge(edge.a, edge.b))) continue;
        const key = packUndirectedEdge(edge.a, edge.b);
        if (result_face_edge_keys.contains(key)) continue;
        try result_face_edge_keys.put(key, {});
        try result.appendEdge(@min(edge.a, edge.b), @max(edge.a, edge.b));
    }

    return result;
}

fn faceCentroid(mesh: *const mesh_mod.Mesh, face_verts: []const u32) math.Vec3 {
    var sum = math.Vec3.init(0, 0, 0);
    for (face_verts) |vertex| {
        sum = sum.add(mesh.positions.items[vertex]);
    }
    return sum.scale(1.0 / @as(f32, @floatFromInt(face_verts.len)));
}

fn faceUvCentroid(face_uvs: []const math.Vec2) math.Vec2 {
    var x: f32 = 0;
    var y: f32 = 0;
    for (face_uvs) |uv| {
        x += uv.x;
        y += uv.y;
    }
    const inv_count = 1.0 / @as(f32, @floatFromInt(face_uvs.len));
    return .{ .x = x * inv_count, .y = y * inv_count };
}

fn lerpVec3(a: math.Vec3, b: math.Vec3, factor: f32) math.Vec3 {
    return a.scale(1.0 - factor).add(b.scale(factor));
}

fn lerpVec2(a: math.Vec2, b: math.Vec2, factor: f32) math.Vec2 {
    return .{
        .x = a.x * (1.0 - factor) + b.x * factor,
        .y = a.y * (1.0 - factor) + b.y * factor,
    };
}

fn packUndirectedEdge(a: u32, b: u32) u64 {
    const lo = @min(a, b);
    const hi = @max(a, b);
    return (@as(u64, hi) << 32) | @as(u64, lo);
}

fn hasEdge(mesh: *const mesh_mod.Mesh, a: u32, b: u32) bool {
    const lo = @min(a, b);
    const hi = @max(a, b);
    for (mesh.edges.items) |edge| {
        if (edge.a == lo and edge.b == hi) return true;
    }
    return false;
}

test "individual inset turns a quad into side walls plus an inner face" {
    var mesh = try mesh_mod.Mesh.init(std.testing.allocator);
    defer mesh.deinit();

    _ = try mesh.appendVertex(.{ .x = -1, .y = -1, .z = 0 });
    _ = try mesh.appendVertex(.{ .x = 1, .y = -1, .z = 0 });
    _ = try mesh.appendVertex(.{ .x = 1, .y = 1, .z = 0 });
    _ = try mesh.appendVertex(.{ .x = -1, .y = 1, .z = 0 });

    const face_uvs = [_]math.Vec2{
        .{ .x = 0, .y = 0 },
        .{ .x = 1, .y = 0 },
        .{ .x = 1, .y = 1 },
        .{ .x = 0, .y = 1 },
    };
    try mesh.appendFace(&[_]u32{ 0, 1, 2, 3 }, &face_uvs);
    try mesh.rebuildEdgesFromFaces();

    var inset = try insetIndividual(std.testing.allocator, &mesh, .{ .factor = 0.25 });
    defer inset.deinit();

    try std.testing.expectEqual(@as(usize, 8), inset.vertexCount());
    try std.testing.expectEqual(@as(usize, 5), inset.faceCount());
    try std.testing.expectEqual(@as(usize, 12), inset.edges.items.len);
    try std.testing.expect(inset.hasCornerUvs());
    try std.testing.expectEqual(@as(usize, 20), inset.corner_uvs.items.len);
    try std.testing.expect(math.vec3ApproxEq(inset.positions.items[4], .{ .x = -0.75, .y = -0.75, .z = 0 }, 0.0001));
}

test "individual inset preserves loose edges from edge-only meshes" {
    var mesh = try mesh_mod.Mesh.init(std.testing.allocator);
    defer mesh.deinit();

    _ = try mesh.appendVertex(.{ .x = 0, .y = 0, .z = 0 });
    _ = try mesh.appendVertex(.{ .x = 1, .y = 0, .z = 0 });
    _ = try mesh.appendVertex(.{ .x = 2, .y = 0, .z = 0 });
    try mesh.appendEdge(0, 1);
    try mesh.appendEdge(1, 2);

    var inset = try insetIndividual(std.testing.allocator, &mesh, .{ .factor = 0.25 });
    defer inset.deinit();

    try std.testing.expectEqual(@as(usize, 3), inset.vertexCount());
    try std.testing.expectEqual(@as(usize, 0), inset.faceCount());
    try std.testing.expectEqual(@as(usize, 2), inset.edges.items.len);
    try std.testing.expect(hasEdge(&inset, 0, 1));
    try std.testing.expect(hasEdge(&inset, 1, 2));
}

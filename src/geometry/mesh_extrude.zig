const std = @import("std");
const math = @import("../math.zig");
const mesh_mod = @import("../mesh.zig");

pub const ExtrudeOptions = struct {
    distance: f32 = 1.0,
};

// Start with the individual-face case because it produces a meaningful modeling
// operation without needing region selection, adjacency tagging, or BMesh-style state.
pub fn extrudeIndividual(
    allocator: std.mem.Allocator,
    mesh: *const mesh_mod.Mesh,
    options: ExtrudeOptions,
) !mesh_mod.Mesh {
    if (options.distance == 0.0) return error.InvalidExtrudeDistance;

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

        const normal = faceNormal(mesh, face_verts);
        const offset = normal.scale(options.distance);

        const maybe_base_uvs: ?[]const math.Vec2 = if (has_corner_uvs) face_uvs else null;
        try result.appendFace(face_verts, maybe_base_uvs);

        var cap_verts = std.ArrayList(u32).empty;
        defer cap_verts.deinit(allocator);
        var cap_uvs = std.ArrayList(math.Vec2).empty;
        defer cap_uvs.deinit(allocator);

        for (face_verts, 0..) |vertex, local_index| {
            const cap_position = mesh.positions.items[vertex].add(offset);
            try cap_verts.append(allocator, try result.appendVertex(cap_position));
            if (has_corner_uvs) {
                try cap_uvs.append(allocator, face_uvs[local_index]);
            }
        }

        const maybe_cap_uvs: ?[]const math.Vec2 = if (has_corner_uvs) cap_uvs.items else null;
        try result.appendFace(cap_verts.items, maybe_cap_uvs);

        // Build wall quads around the source boundary. Side UVs are generated from the
        // source edge length and extrusion depth so every extruded wall has valid,
        // deterministic coordinates without needing a full unwrap system yet.
        for (face_verts, 0..) |outer_vertex, local_index| {
            const next_index = (local_index + 1) % face_verts.len;
            const side_face = [_]u32{
                outer_vertex,
                face_verts[next_index],
                cap_verts.items[next_index],
                cap_verts.items[local_index],
            };
            if (has_corner_uvs) {
                const side_uvs = sideFaceUvs(
                    mesh.positions.items[outer_vertex],
                    mesh.positions.items[face_verts[next_index]],
                    options.distance,
                );
                try result.appendFace(&side_face, &side_uvs);
            } else {
                try result.appendFace(&side_face, null);
            }
        }
    }

    try result.rebuildEdgesFromFaces();

    var result_face_edge_keys = std.AutoHashMap(u64, void).init(allocator);
    defer result_face_edge_keys.deinit();
    for (result.edges.items) |edge| {
        try result_face_edge_keys.put(packUndirectedEdge(edge.a, edge.b), {});
    }

    for (mesh.edges.items) |edge| {
        const key = packUndirectedEdge(edge.a, edge.b);
        if (source_face_edge_keys.contains(key)) continue;
        if (result_face_edge_keys.contains(key)) continue;

        try result_face_edge_keys.put(key, {});
        try result.appendEdge(@min(edge.a, edge.b), @max(edge.a, edge.b));
    }

    return result;
}

fn faceNormal(mesh: *const mesh_mod.Mesh, face_verts: []const u32) math.Vec3 {
    const origin = mesh.positions.items[face_verts[0]];
    var normal = math.Vec3.init(0, 0, 0);
    for (1..face_verts.len - 1) |triangle_index| {
        const edge_a = mesh.positions.items[face_verts[triangle_index]].sub(origin);
        const edge_b = mesh.positions.items[face_verts[triangle_index + 1]].sub(origin);
        normal = normal.add(edge_a.cross(edge_b));
    }
    return normal.normalizedOr(math.Vec3.init(0, 0, 1));
}

fn sideFaceUvs(a: math.Vec3, b: math.Vec3, distance: f32) [4]math.Vec2 {
    const u = @max(a.sub(b).length(), 1e-6);
    const v = @max(@abs(distance), 1e-6);
    return .{
        .{ .x = 0.0, .y = 0.0 },
        .{ .x = u, .y = 0.0 },
        .{ .x = u, .y = v },
        .{ .x = 0.0, .y = v },
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

test "individual extrude turns a quad into a capped box-like shell" {
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

    var extruded = try extrudeIndividual(std.testing.allocator, &mesh, .{ .distance = 1.0 });
    defer extruded.deinit();

    try std.testing.expectEqual(@as(usize, 8), extruded.vertexCount());
    try std.testing.expectEqual(@as(usize, 6), extruded.faceCount());
    try std.testing.expectEqual(@as(usize, 12), extruded.edges.items.len);
    try std.testing.expect(extruded.hasCornerUvs());
    try std.testing.expectEqual(@as(usize, 24), extruded.corner_uvs.items.len);
    try std.testing.expect(math.vec3ApproxEq(extruded.positions.items[4], .{ .x = -1, .y = -1, .z = 1 }, 0.0001));

    const cap_range = extruded.faceVertexRange(1);
    try std.testing.expectEqual(@as(usize, 4), cap_range.end - cap_range.start);
    try std.testing.expect(math.vec2ApproxEq(extruded.corner_uvs.items[cap_range.start], face_uvs[0], 0.0001));
    try std.testing.expect(math.vec2ApproxEq(extruded.corner_uvs.items[cap_range.start + 2], face_uvs[2], 0.0001));
}

test "individual extrude handles ngons by keeping a matching cap" {
    var mesh = try mesh_mod.Mesh.init(std.testing.allocator);
    defer mesh.deinit();

    _ = try mesh.appendVertex(.{ .x = 0, .y = 0, .z = 0 });
    _ = try mesh.appendVertex(.{ .x = 2, .y = 0, .z = 0 });
    _ = try mesh.appendVertex(.{ .x = 3, .y = 1, .z = 0 });
    _ = try mesh.appendVertex(.{ .x = 1.5, .y = 3, .z = 0 });
    _ = try mesh.appendVertex(.{ .x = 0, .y = 2, .z = 0 });
    try mesh.appendFace(&[_]u32{ 0, 1, 2, 3, 4 }, null);
    try mesh.rebuildEdgesFromFaces();

    var extruded = try extrudeIndividual(std.testing.allocator, &mesh, .{ .distance = 0.5 });
    defer extruded.deinit();

    try std.testing.expectEqual(@as(usize, 10), extruded.vertexCount());
    try std.testing.expectEqual(@as(usize, 7), extruded.faceCount());
    const cap_range = extruded.faceVertexRange(1);
    try std.testing.expectEqual(@as(usize, 5), cap_range.end - cap_range.start);
}

test "individual extrude preserves loose edges from edge-only meshes" {
    var mesh = try mesh_mod.Mesh.init(std.testing.allocator);
    defer mesh.deinit();

    _ = try mesh.appendVertex(.{ .x = 0, .y = 0, .z = 0 });
    _ = try mesh.appendVertex(.{ .x = 1, .y = 0, .z = 0 });
    _ = try mesh.appendVertex(.{ .x = 2, .y = 0, .z = 0 });
    try mesh.appendEdge(0, 1);
    try mesh.appendEdge(1, 2);

    var extruded = try extrudeIndividual(std.testing.allocator, &mesh, .{ .distance = 1.0 });
    defer extruded.deinit();

    try std.testing.expectEqual(@as(usize, 3), extruded.vertexCount());
    try std.testing.expectEqual(@as(usize, 0), extruded.faceCount());
    try std.testing.expectEqual(@as(usize, 2), extruded.edges.items.len);
    try std.testing.expect(hasEdge(&extruded, 0, 1));
    try std.testing.expect(hasEdge(&extruded, 1, 2));
}

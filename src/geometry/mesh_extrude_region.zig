const std = @import("std");
const math = @import("../math.zig");
const mesh_mod = @import("../mesh.zig");

pub const ExtrudeRegionOptions = struct {
    distance: f32 = 1.0,
};

const BoundaryUse = struct {
    face_index: usize,
    local_index: usize,
};

const EdgeBoundary = struct {
    count: u8 = 0,
    first_use: ?BoundaryUse = null,
};

// This is the first region-style modeling slice for the rewrite: extrude the mesh-wide
// open face region as one shell, bridge only boundary edges, and keep loose edges
// untouched. Closed shells currently no-op instead of creating disconnected duplicates.
pub fn extrudeRegion(
    allocator: std.mem.Allocator,
    mesh: *const mesh_mod.Mesh,
    options: ExtrudeRegionOptions,
) !mesh_mod.Mesh {
    if (options.distance == 0.0) return error.InvalidExtrudeDistance;

    var source_face_edge_keys = std.AutoHashMap(u64, void).init(allocator);
    defer source_face_edge_keys.deinit();

    var boundary_edges = std.AutoHashMap(u64, EdgeBoundary).init(allocator);
    defer boundary_edges.deinit();

    const used_by_face = try allocator.alloc(bool, mesh.vertexCount());
    defer allocator.free(used_by_face);
    @memset(used_by_face, false);

    const vertex_normal_sums = try allocator.alloc(math.Vec3, mesh.vertexCount());
    defer allocator.free(vertex_normal_sums);
    @memset(vertex_normal_sums, math.Vec3.init(0, 0, 0));

    for (0..mesh.faceCount()) |face_index| {
        const range = mesh.faceVertexRange(face_index);
        const face_verts = mesh.corner_verts.items[range.start..range.end];
        if (face_verts.len < 3) return error.InvalidFace;

        const normal = faceNormal(mesh, face_verts);
        for (face_verts) |vertex| {
            used_by_face[vertex] = true;
            vertex_normal_sums[vertex] = vertex_normal_sums[vertex].add(normal);
        }

        for (face_verts, 0..) |vertex, local_index| {
            const next_vertex = face_verts[(local_index + 1) % face_verts.len];
            const edge_key = packUndirectedEdge(vertex, next_vertex);
            try source_face_edge_keys.put(edge_key, {});

            const entry = try boundary_edges.getOrPut(edge_key);
            if (!entry.found_existing) {
                entry.value_ptr.* = .{
                    .count = 1,
                    .first_use = .{
                        .face_index = face_index,
                        .local_index = local_index,
                    },
                };
            } else {
                entry.value_ptr.count += 1;
            }
        }
    }

    var boundary_count: usize = 0;
    var boundary_iter = boundary_edges.valueIterator();
    while (boundary_iter.next()) |edge| {
        if (edge.count == 1) boundary_count += 1;
    }

    if (boundary_count == 0) {
        return mesh.clone(allocator);
    }

    var result = try mesh_mod.Mesh.init(allocator);
    errdefer result.deinit();

    for (mesh.positions.items) |position| {
        _ = try result.appendVertex(position);
    }

    const cap_vertex_remap = try allocator.alloc(u32, mesh.vertexCount());
    defer allocator.free(cap_vertex_remap);
    @memset(cap_vertex_remap, std.math.maxInt(u32));

    for (mesh.positions.items, 0..) |position, vertex_index| {
        if (!used_by_face[vertex_index]) continue;
        const normal = vertex_normal_sums[vertex_index].normalizedOr(math.Vec3.init(0, 0, 1));
        cap_vertex_remap[vertex_index] = try result.appendVertex(position.add(normal.scale(options.distance)));
    }

    const has_corner_uvs = mesh.hasCornerUvs();
    for (0..mesh.faceCount()) |face_index| {
        const range = mesh.faceVertexRange(face_index);
        const face_verts = mesh.corner_verts.items[range.start..range.end];
        const face_uvs = if (has_corner_uvs) mesh.corner_uvs.items[range.start..range.end] else &[_]math.Vec2{};

        const maybe_face_uvs: ?[]const math.Vec2 = if (has_corner_uvs) face_uvs else null;
        try result.appendFace(face_verts, maybe_face_uvs);

        const cap_verts = try allocator.alloc(u32, face_verts.len);
        defer allocator.free(cap_verts);
        for (face_verts, 0..) |vertex, local_index| {
            cap_verts[local_index] = cap_vertex_remap[vertex];
        }
        try result.appendFace(cap_verts, maybe_face_uvs);
    }

    var edge_iter = boundary_edges.iterator();
    while (edge_iter.next()) |entry| {
        if (entry.value_ptr.count != 1) continue;

        const use = entry.value_ptr.first_use.?;
        const range = mesh.faceVertexRange(use.face_index);
        const face_verts = mesh.corner_verts.items[range.start..range.end];
        const a = face_verts[use.local_index];
        const b = face_verts[(use.local_index + 1) % face_verts.len];
        const side_face = [_]u32{
            a,
            b,
            cap_vertex_remap[b],
            cap_vertex_remap[a],
        };

        if (has_corner_uvs) {
            const side_uvs = sideFaceUvs(mesh.positions.items[a], mesh.positions.items[b], options.distance);
            try result.appendFace(&side_face, &side_uvs);
        } else {
            try result.appendFace(&side_face, null);
        }
    }

    try result.rebuildEdgesFromFaces();

    var result_face_edge_keys = std.AutoHashMap(u64, void).init(allocator);
    defer result_face_edge_keys.deinit();
    for (result.edges.items) |edge| {
        try result_face_edge_keys.put(packUndirectedEdge(edge.a, edge.b), {});
    }

    for (mesh.edges.items) |edge| {
        const edge_key = packUndirectedEdge(edge.a, edge.b);
        if (source_face_edge_keys.contains(edge_key)) continue;
        if (result_face_edge_keys.contains(edge_key)) continue;

        try result_face_edge_keys.put(edge_key, {});
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

test "region extrude bridges only the outer boundary of adjacent quads" {
    var mesh = try mesh_mod.Mesh.init(std.testing.allocator);
    defer mesh.deinit();

    _ = try mesh.appendVertex(.{ .x = -1, .y = -1, .z = 0 });
    _ = try mesh.appendVertex(.{ .x = 0, .y = -1, .z = 0 });
    _ = try mesh.appendVertex(.{ .x = 1, .y = -1, .z = 0 });
    _ = try mesh.appendVertex(.{ .x = -1, .y = 1, .z = 0 });
    _ = try mesh.appendVertex(.{ .x = 0, .y = 1, .z = 0 });
    _ = try mesh.appendVertex(.{ .x = 1, .y = 1, .z = 0 });

    const face_uvs = [_]math.Vec2{
        .{ .x = 0, .y = 0 },
        .{ .x = 1, .y = 0 },
        .{ .x = 1, .y = 1 },
        .{ .x = 0, .y = 1 },
    };
    try mesh.appendFace(&[_]u32{ 0, 1, 4, 3 }, &face_uvs);
    try mesh.appendFace(&[_]u32{ 1, 2, 5, 4 }, &face_uvs);
    try mesh.rebuildEdgesFromFaces();

    var extruded = try extrudeRegion(std.testing.allocator, &mesh, .{ .distance = 1.0 });
    defer extruded.deinit();

    try std.testing.expectEqual(@as(usize, 12), extruded.vertexCount());
    try std.testing.expectEqual(@as(usize, 10), extruded.faceCount());
    try std.testing.expectEqual(@as(usize, 20), extruded.edges.items.len);
    try std.testing.expect(extruded.hasCornerUvs());
    try std.testing.expectEqual(@as(usize, 40), extruded.corner_uvs.items.len);
    try std.testing.expect(math.vec3ApproxEq(extruded.positions.items[6], .{ .x = -1, .y = -1, .z = 1 }, 0.0001));
    try std.testing.expect(hasEdge(&extruded, 1, 4));
    try std.testing.expect(hasEdge(&extruded, 7, 10));
}

test "region extrude preserves loose edges outside the face region" {
    var mesh = try mesh_mod.Mesh.init(std.testing.allocator);
    defer mesh.deinit();

    _ = try mesh.appendVertex(.{ .x = -1, .y = -1, .z = 0 });
    _ = try mesh.appendVertex(.{ .x = 1, .y = -1, .z = 0 });
    _ = try mesh.appendVertex(.{ .x = 1, .y = 1, .z = 0 });
    _ = try mesh.appendVertex(.{ .x = -1, .y = 1, .z = 0 });
    _ = try mesh.appendVertex(.{ .x = 4, .y = 0, .z = 0 });
    _ = try mesh.appendVertex(.{ .x = 5, .y = 0, .z = 0 });

    try mesh.appendFace(&[_]u32{ 0, 1, 2, 3 }, null);
    try mesh.rebuildEdgesFromFaces();
    try mesh.appendEdge(4, 5);

    var extruded = try extrudeRegion(std.testing.allocator, &mesh, .{ .distance = 0.5 });
    defer extruded.deinit();

    try std.testing.expectEqual(@as(usize, 10), extruded.vertexCount());
    try std.testing.expectEqual(@as(usize, 6), extruded.faceCount());
    try std.testing.expectEqual(@as(usize, 13), extruded.edges.items.len);
    try std.testing.expect(hasEdge(&extruded, 4, 5));
}

test "region extrude no-ops on closed shells" {
    var mesh = try mesh_mod.Mesh.init(std.testing.allocator);
    defer mesh.deinit();

    _ = try mesh.appendVertex(.{ .x = -1, .y = -1, .z = -1 });
    _ = try mesh.appendVertex(.{ .x = 1, .y = -1, .z = -1 });
    _ = try mesh.appendVertex(.{ .x = 1, .y = 1, .z = -1 });
    _ = try mesh.appendVertex(.{ .x = -1, .y = 1, .z = -1 });
    _ = try mesh.appendVertex(.{ .x = -1, .y = -1, .z = 1 });
    _ = try mesh.appendVertex(.{ .x = 1, .y = -1, .z = 1 });
    _ = try mesh.appendVertex(.{ .x = 1, .y = 1, .z = 1 });
    _ = try mesh.appendVertex(.{ .x = -1, .y = 1, .z = 1 });

    try mesh.appendFace(&[_]u32{ 0, 1, 2, 3 }, null);
    try mesh.appendFace(&[_]u32{ 4, 5, 6, 7 }, null);
    try mesh.appendFace(&[_]u32{ 0, 1, 5, 4 }, null);
    try mesh.appendFace(&[_]u32{ 1, 2, 6, 5 }, null);
    try mesh.appendFace(&[_]u32{ 2, 3, 7, 6 }, null);
    try mesh.appendFace(&[_]u32{ 3, 0, 4, 7 }, null);
    try mesh.rebuildEdgesFromFaces();

    var extruded = try extrudeRegion(std.testing.allocator, &mesh, .{ .distance = 1.0 });
    defer extruded.deinit();

    try std.testing.expectEqual(mesh.vertexCount(), extruded.vertexCount());
    try std.testing.expectEqual(mesh.faceCount(), extruded.faceCount());
    try std.testing.expectEqual(mesh.edges.items.len, extruded.edges.items.len);
    try std.testing.expectEqualDeep(mesh.positions.items, extruded.positions.items);
}

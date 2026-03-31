const std = @import("std");
const math = @import("../math.zig");
const mesh_mod = @import("../mesh.zig");

pub const DissolveOptions = struct {};

const FaceEdgeUse = struct {
    face_index: usize,
    local_index: usize,
};

const EdgeUses = struct {
    count: u8 = 0,
    uses: [3]FaceEdgeUse = undefined,
};

const MergePair = struct {
    face_a: usize,
    face_b: usize,
    edge_key: u64,
};

const BoundaryCorner = struct {
    start: u32,
    end: u32,
    uv: math.Vec2,
};

// This is the first Blender-like dissolve slice for the current mesh model: remove a
// selected manifold shared edge between two faces, splice the two face loops into one
// ngon, and rebuild the explicit edge table afterwards.
pub fn dissolveEdges(
    allocator: std.mem.Allocator,
    mesh: *const mesh_mod.Mesh,
    edges_to_dissolve: []const mesh_mod.Edge,
) !mesh_mod.Mesh {
    var result = try mesh_mod.Mesh.init(allocator);
    errdefer result.deinit();

    for (mesh.positions.items) |position| {
        _ = try result.appendVertex(position);
    }

    var source_face_edge_keys = std.AutoHashMap(u64, void).init(allocator);
    defer source_face_edge_keys.deinit();

    var selected_edge_uses = std.AutoHashMap(u64, EdgeUses).init(allocator);
    defer selected_edge_uses.deinit();

    var selected_keys = std.AutoHashMap(u64, void).init(allocator);
    defer selected_keys.deinit();
    for (edges_to_dissolve) |edge| {
        try selected_keys.put(packUndirectedEdge(edge.a, edge.b), {});
    }

    for (0..mesh.faceCount()) |face_index| {
        const range = mesh.faceVertexRange(face_index);
        const face_verts = mesh.corner_verts.items[range.start..range.end];
        if (face_verts.len < 3) return error.InvalidFace;

        for (face_verts, 0..) |vertex, local_index| {
            const next_vertex = face_verts[(local_index + 1) % face_verts.len];
            const edge_key = packUndirectedEdge(vertex, next_vertex);
            try source_face_edge_keys.put(edge_key, {});
            if (!selected_keys.contains(edge_key)) continue;

            const entry = try selected_edge_uses.getOrPut(edge_key);
            if (!entry.found_existing) {
                entry.value_ptr.* = .{};
            }
            if (entry.value_ptr.count < entry.value_ptr.uses.len) {
                entry.value_ptr.uses[entry.value_ptr.count] = .{
                    .face_index = face_index,
                    .local_index = local_index,
                };
            }
            entry.value_ptr.count += 1;
        }
    }

    const face_reserved = try allocator.alloc(bool, mesh.faceCount());
    defer allocator.free(face_reserved);
    @memset(face_reserved, false);

    var pairs_by_primary = std.AutoHashMap(usize, MergePair).init(allocator);
    defer pairs_by_primary.deinit();

    var processed_keys = std.AutoHashMap(u64, void).init(allocator);
    defer processed_keys.deinit();

    for (edges_to_dissolve) |edge| {
        const edge_key = packUndirectedEdge(edge.a, edge.b);
        if (processed_keys.contains(edge_key)) continue;
        try processed_keys.put(edge_key, {});

        const edge_uses = selected_edge_uses.get(edge_key) orelse continue;
        if (edge_uses.count != 2) continue;

        const face_a = edge_uses.uses[0].face_index;
        const face_b = edge_uses.uses[1].face_index;
        if (face_a == face_b) continue;
        if (face_reserved[face_a] or face_reserved[face_b]) continue;

        face_reserved[face_a] = true;
        face_reserved[face_b] = true;
        const primary = @min(face_a, face_b);
        const secondary = @max(face_a, face_b);
        try pairs_by_primary.put(primary, .{
            .face_a = primary,
            .face_b = secondary,
            .edge_key = edge_key,
        });
    }

    const face_written = try allocator.alloc(bool, mesh.faceCount());
    defer allocator.free(face_written);
    @memset(face_written, false);

    for (0..mesh.faceCount()) |face_index| {
        if (face_written[face_index]) continue;

        if (pairs_by_primary.get(face_index)) |pair| {
            if (try appendMergedFacePair(allocator, mesh, pair, &result)) {
                face_written[pair.face_a] = true;
                face_written[pair.face_b] = true;
                continue;
            }
        }

        try appendSourceFace(mesh, face_index, &result);
        face_written[face_index] = true;
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

fn appendMergedFacePair(
    allocator: std.mem.Allocator,
    mesh: *const mesh_mod.Mesh,
    pair: MergePair,
    result: *mesh_mod.Mesh,
) !bool {
    var boundary = std.ArrayList(BoundaryCorner).empty;
    defer boundary.deinit(allocator);

    try appendFaceBoundary(allocator, mesh, pair.face_a, pair.edge_key, &boundary);
    try appendFaceBoundary(allocator, mesh, pair.face_b, pair.edge_key, &boundary);

    if (boundary.items.len < 3) return false;

    var next_by_start = std.AutoHashMap(u32, usize).init(allocator);
    defer next_by_start.deinit();
    for (boundary.items, 0..) |corner, corner_index| {
        const entry = try next_by_start.getOrPut(corner.start);
        if (entry.found_existing) {
            return false;
        }
        entry.value_ptr.* = corner_index;
    }

    var merged_verts = std.ArrayList(u32).empty;
    defer merged_verts.deinit(allocator);

    var merged_uvs = std.ArrayList(math.Vec2).empty;
    defer merged_uvs.deinit(allocator);

    const visited = try allocator.alloc(bool, boundary.items.len);
    defer allocator.free(visited);
    @memset(visited, false);

    const start_vertex = boundary.items[0].start;
    var current_vertex = start_vertex;
    while (true) {
        const corner_index = next_by_start.get(current_vertex) orelse return false;
        if (visited[corner_index]) break;

        visited[corner_index] = true;
        const corner = boundary.items[corner_index];
        try merged_verts.append(allocator, corner.start);
        if (mesh.hasCornerUvs()) {
            try merged_uvs.append(allocator, corner.uv);
        }
        current_vertex = corner.end;
    }

    if (current_vertex != start_vertex) return false;
    for (visited) |did_visit| {
        if (!did_visit) return false;
    }
    if (merged_verts.items.len < 3 or hasRepeatedVertex(merged_verts.items)) return false;

    const maybe_uvs: ?[]const math.Vec2 = if (mesh.hasCornerUvs()) merged_uvs.items else null;
    try result.appendFace(merged_verts.items, maybe_uvs);
    return true;
}

fn appendFaceBoundary(
    allocator: std.mem.Allocator,
    mesh: *const mesh_mod.Mesh,
    face_index: usize,
    shared_edge_key: u64,
    boundary: *std.ArrayList(BoundaryCorner),
) !void {
    const range = mesh.faceVertexRange(face_index);
    const face_verts = mesh.corner_verts.items[range.start..range.end];
    const face_uvs = if (mesh.hasCornerUvs()) mesh.corner_uvs.items[range.start..range.end] else &[_]math.Vec2{};

    for (face_verts, 0..) |vertex, local_index| {
        const next_vertex = face_verts[(local_index + 1) % face_verts.len];
        const edge_key = packUndirectedEdge(vertex, next_vertex);
        if (edge_key == shared_edge_key) continue;

        try boundary.append(allocator, .{
            .start = vertex,
            .end = next_vertex,
            .uv = if (mesh.hasCornerUvs()) face_uvs[local_index] else math.Vec2.init(0, 0),
        });
    }
}

fn appendSourceFace(
    mesh: *const mesh_mod.Mesh,
    face_index: usize,
    result: *mesh_mod.Mesh,
) !void {
    const range = mesh.faceVertexRange(face_index);
    const face_verts = mesh.corner_verts.items[range.start..range.end];
    const maybe_uvs: ?[]const math.Vec2 = if (mesh.hasCornerUvs()) mesh.corner_uvs.items[range.start..range.end] else null;
    try result.appendFace(face_verts, maybe_uvs);
}

fn hasRepeatedVertex(verts: []const u32) bool {
    for (verts, 0..) |vertex, index| {
        for (verts[index + 1 ..]) |other| {
            if (vertex == other) return true;
        }
    }
    return false;
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

test "dissolve shared edge merges two quads into one ngon and preserves loose edges" {
    var mesh = try mesh_mod.Mesh.init(std.testing.allocator);
    defer mesh.deinit();

    _ = try mesh.appendVertex(.{ .x = -1, .y = -0.5, .z = 0 });
    _ = try mesh.appendVertex(.{ .x = -1, .y = 0.5, .z = 0 });
    _ = try mesh.appendVertex(.{ .x = 0, .y = -0.5, .z = 0 });
    _ = try mesh.appendVertex(.{ .x = 0, .y = 0.5, .z = 0 });
    _ = try mesh.appendVertex(.{ .x = 1, .y = -0.5, .z = 0 });
    _ = try mesh.appendVertex(.{ .x = 1, .y = 0.5, .z = 0 });
    _ = try mesh.appendVertex(.{ .x = 2, .y = 0, .z = 0 });
    _ = try mesh.appendVertex(.{ .x = 3, .y = 0, .z = 0 });

    const left_uvs = [_]math.Vec2{
        .{ .x = 0.0, .y = 0.0 },
        .{ .x = 0.5, .y = 0.0 },
        .{ .x = 0.5, .y = 1.0 },
        .{ .x = 0.0, .y = 1.0 },
    };
    const right_uvs = [_]math.Vec2{
        .{ .x = 0.5, .y = 0.0 },
        .{ .x = 1.0, .y = 0.0 },
        .{ .x = 1.0, .y = 1.0 },
        .{ .x = 0.5, .y = 1.0 },
    };
    try mesh.appendFace(&[_]u32{ 0, 2, 3, 1 }, &left_uvs);
    try mesh.appendFace(&[_]u32{ 2, 4, 5, 3 }, &right_uvs);
    try mesh.rebuildEdgesFromFaces();
    try mesh.appendEdge(6, 7);

    var dissolved = try dissolveEdges(std.testing.allocator, &mesh, &[_]mesh_mod.Edge{
        .{ .a = 2, .b = 3 },
    });
    defer dissolved.deinit();

    try std.testing.expectEqual(@as(usize, 8), dissolved.vertexCount());
    try std.testing.expectEqual(@as(usize, 1), dissolved.faceCount());
    try std.testing.expectEqual(@as(usize, 7), dissolved.edges.items.len);
    try std.testing.expect(dissolved.hasCornerUvs());
    try std.testing.expectEqual(@as(usize, 6), dissolved.corner_uvs.items.len);
    try std.testing.expectEqualSlices(u32, &[_]u32{ 0, 2, 4, 5, 3, 1 }, dissolved.corner_verts.items);
    try std.testing.expect(math.vec2ApproxEq(dissolved.corner_uvs.items[0], .{ .x = 0.0, .y = 0.0 }, 0.0001));
    try std.testing.expect(math.vec2ApproxEq(dissolved.corner_uvs.items[2], .{ .x = 1.0, .y = 0.0 }, 0.0001));
    try std.testing.expect(math.vec2ApproxEq(dissolved.corner_uvs.items[5], .{ .x = 0.0, .y = 1.0 }, 0.0001));
    try std.testing.expect(hasEdge(&dissolved, 6, 7));
}

test "dissolve boundary edge leaves mesh unchanged" {
    var mesh = try mesh_mod.Mesh.init(std.testing.allocator);
    defer mesh.deinit();

    _ = try mesh.appendVertex(.{ .x = 0, .y = 0, .z = 0 });
    _ = try mesh.appendVertex(.{ .x = 1, .y = 0, .z = 0 });
    _ = try mesh.appendVertex(.{ .x = 2, .y = 0, .z = 0 });
    _ = try mesh.appendVertex(.{ .x = 0, .y = 1, .z = 0 });
    _ = try mesh.appendVertex(.{ .x = 1, .y = 1, .z = 0 });
    _ = try mesh.appendVertex(.{ .x = 2, .y = 1, .z = 0 });

    try mesh.appendFace(&[_]u32{ 0, 1, 4, 3 }, null);
    try mesh.appendFace(&[_]u32{ 1, 2, 5, 4 }, null);
    try mesh.rebuildEdgesFromFaces();

    var dissolved = try dissolveEdges(std.testing.allocator, &mesh, &[_]mesh_mod.Edge{
        .{ .a = 0, .b = 1 },
    });
    defer dissolved.deinit();

    try std.testing.expectEqual(mesh.vertexCount(), dissolved.vertexCount());
    try std.testing.expectEqual(mesh.faceCount(), dissolved.faceCount());
    try std.testing.expectEqualSlices(u32, mesh.corner_verts.items, dissolved.corner_verts.items);
    try std.testing.expectEqual(@as(usize, 7), dissolved.edges.items.len);
}

test "dissolve ignores overlapping selections in one pass" {
    var mesh = try mesh_mod.Mesh.init(std.testing.allocator);
    defer mesh.deinit();

    _ = try mesh.appendVertex(.{ .x = -1, .y = 0, .z = 0 });
    _ = try mesh.appendVertex(.{ .x = 0, .y = 0, .z = 0 });
    _ = try mesh.appendVertex(.{ .x = 1, .y = 0, .z = 0 });
    _ = try mesh.appendVertex(.{ .x = 2, .y = 0, .z = 0 });
    _ = try mesh.appendVertex(.{ .x = -1, .y = 1, .z = 0 });
    _ = try mesh.appendVertex(.{ .x = 0, .y = 1, .z = 0 });
    _ = try mesh.appendVertex(.{ .x = 1, .y = 1, .z = 0 });
    _ = try mesh.appendVertex(.{ .x = 2, .y = 1, .z = 0 });

    try mesh.appendFace(&[_]u32{ 0, 1, 5, 4 }, null);
    try mesh.appendFace(&[_]u32{ 1, 2, 6, 5 }, null);
    try mesh.appendFace(&[_]u32{ 2, 3, 7, 6 }, null);
    try mesh.rebuildEdgesFromFaces();

    var dissolved = try dissolveEdges(std.testing.allocator, &mesh, &[_]mesh_mod.Edge{
        .{ .a = 1, .b = 5 },
        .{ .a = 2, .b = 6 },
    });
    defer dissolved.deinit();

    try std.testing.expectEqual(@as(usize, 2), dissolved.faceCount());
    try std.testing.expectEqual(@as(usize, 8), dissolved.vertexCount());
}

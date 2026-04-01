const std = @import("std");
const math = @import("../math.zig");
const mesh_mod = @import("../mesh.zig");
const mesh_delete_faces = @import("mesh_delete_faces.zig");

pub const DeleteEdgeOptions = struct {};

const FaceEdgeUse = struct {
    face_index: usize,
};

const EdgeUses = struct {
    count: u8 = 0,
    uses: [3]FaceEdgeUse = undefined,
};

// This is the first bounded edge-domain delete slice: resolve one selected edge into
// either direct loose-edge removal or deletion of the incident faces, then preserve
// the resulting exposed border as loose wire through the existing face-delete path.
pub fn deleteEdges(
    allocator: std.mem.Allocator,
    mesh: *const mesh_mod.Mesh,
    edges_to_delete: []const mesh_mod.Edge,
    _: DeleteEdgeOptions,
) !mesh_mod.Mesh {
    if (edges_to_delete.len == 0) {
        return mesh.clone(allocator);
    }
    if (edges_to_delete.len != 1) return error.InvalidEdgeSelectionCount;

    const selected_key = packUndirectedEdge(edges_to_delete[0].a, edges_to_delete[0].b);

    var source_face_edge_keys = std.AutoHashMap(u64, void).init(allocator);
    defer source_face_edge_keys.deinit();

    var selected_edge_uses = EdgeUses{};
    for (0..mesh.faceCount()) |face_index| {
        const range = mesh.faceVertexRange(face_index);
        const face_verts = mesh.corner_verts.items[range.start..range.end];
        if (face_verts.len < 3) return error.InvalidFace;

        for (face_verts, 0..) |vertex, local_index| {
            const next_vertex = face_verts[(local_index + 1) % face_verts.len];
            const edge_key = packUndirectedEdge(vertex, next_vertex);
            try source_face_edge_keys.put(edge_key, {});

            if (edge_key != selected_key) continue;
            if (selected_edge_uses.count < selected_edge_uses.uses.len) {
                selected_edge_uses.uses[selected_edge_uses.count] = .{ .face_index = face_index };
            }
            selected_edge_uses.count += 1;
        }
    }

    if (selected_edge_uses.count > 2) return error.NonManifoldEdgeSelection;

    if (selected_edge_uses.count > 0) {
        const faces = try allocator.alloc(usize, selected_edge_uses.count);
        defer allocator.free(faces);
        for (0..selected_edge_uses.count) |use_index| {
            faces[use_index] = selected_edge_uses.uses[use_index].face_index;
        }
        return mesh_delete_faces.deleteFaces(allocator, mesh, faces, .{});
    }

    for (mesh.edges.items) |edge| {
        if (source_face_edge_keys.contains(packUndirectedEdge(edge.a, edge.b))) continue;
        if (packUndirectedEdge(edge.a, edge.b) == selected_key) {
            return deleteLooseEdge(allocator, mesh, selected_key);
        }
    }

    return error.InvalidEdgeSelection;
}

fn deleteLooseEdge(
    allocator: std.mem.Allocator,
    mesh: *const mesh_mod.Mesh,
    selected_key: u64,
) !mesh_mod.Mesh {
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
        const face_uvs = if (has_corner_uvs) mesh.corner_uvs.items[range.start..range.end] else &[_]math.Vec2{};

        for (face_verts, 0..) |vertex, local_index| {
            const next_vertex = face_verts[(local_index + 1) % face_verts.len];
            try source_face_edge_keys.put(packUndirectedEdge(vertex, next_vertex), {});
        }

        const maybe_uvs: ?[]const math.Vec2 = if (has_corner_uvs) face_uvs else null;
        try result.appendFace(face_verts, maybe_uvs);
    }

    try result.rebuildEdgesFromFaces();

    var result_edge_keys = std.AutoHashMap(u64, void).init(allocator);
    defer result_edge_keys.deinit();
    for (result.edges.items) |edge| {
        try result_edge_keys.put(packUndirectedEdge(edge.a, edge.b), {});
    }

    for (mesh.edges.items) |edge| {
        const edge_key = packUndirectedEdge(edge.a, edge.b);
        if (source_face_edge_keys.contains(edge_key)) continue;
        if (edge_key == selected_key) continue;
        if (result_edge_keys.contains(edge_key)) continue;

        try result_edge_keys.put(edge_key, {});
        try result.appendEdge(@min(edge.a, edge.b), @max(edge.a, edge.b));
    }

    return result;
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

test "delete edge removes one loose edge while preserving the rest of a wire chain" {
    var mesh = try mesh_mod.Mesh.init(std.testing.allocator);
    defer mesh.deinit();

    _ = try mesh.appendVertex(.{ .x = 0, .y = 0, .z = 0 });
    _ = try mesh.appendVertex(.{ .x = 1, .y = 0, .z = 0 });
    _ = try mesh.appendVertex(.{ .x = 2, .y = 0, .z = 0 });
    try mesh.appendEdge(0, 1);
    try mesh.appendEdge(1, 2);

    var deleted = try deleteEdges(std.testing.allocator, &mesh, &[_]mesh_mod.Edge{
        .{ .a = 0, .b = 1 },
    }, .{});
    defer deleted.deinit();

    try std.testing.expectEqual(@as(usize, 3), deleted.vertexCount());
    try std.testing.expectEqual(@as(usize, 0), deleted.faceCount());
    try std.testing.expectEqual(@as(usize, 1), deleted.edges.items.len);
    try std.testing.expect(!hasEdge(&deleted, 0, 1));
    try std.testing.expect(hasEdge(&deleted, 1, 2));
}

test "delete edge removes both incident faces of a shared edge and keeps the outer border wire" {
    var mesh = try mesh_mod.Mesh.init(std.testing.allocator);
    defer mesh.deinit();

    _ = try mesh.appendVertex(.{ .x = -1, .y = -1, .z = 0 });
    _ = try mesh.appendVertex(.{ .x = 0, .y = -1, .z = 0 });
    _ = try mesh.appendVertex(.{ .x = 1, .y = -1, .z = 0 });
    _ = try mesh.appendVertex(.{ .x = -1, .y = 1, .z = 0 });
    _ = try mesh.appendVertex(.{ .x = 0, .y = 1, .z = 0 });
    _ = try mesh.appendVertex(.{ .x = 1, .y = 1, .z = 0 });

    const left_uvs = [_]math.Vec2{
        .{ .x = 0, .y = 0 },
        .{ .x = 1, .y = 0 },
        .{ .x = 1, .y = 1 },
        .{ .x = 0, .y = 1 },
    };
    const right_uvs = [_]math.Vec2{
        .{ .x = 1, .y = 0 },
        .{ .x = 2, .y = 0 },
        .{ .x = 2, .y = 1 },
        .{ .x = 1, .y = 1 },
    };
    try mesh.appendFace(&[_]u32{ 0, 1, 4, 3 }, &left_uvs);
    try mesh.appendFace(&[_]u32{ 1, 2, 5, 4 }, &right_uvs);
    try mesh.rebuildEdgesFromFaces();

    var deleted = try deleteEdges(std.testing.allocator, &mesh, &[_]mesh_mod.Edge{
        .{ .a = 1, .b = 4 },
    }, .{});
    defer deleted.deinit();

    try std.testing.expectEqual(@as(usize, 6), deleted.vertexCount());
    try std.testing.expectEqual(@as(usize, 0), deleted.faceCount());
    try std.testing.expectEqual(@as(usize, 6), deleted.edges.items.len);
    try std.testing.expect(!hasEdge(&deleted, 1, 4));
    try std.testing.expect(hasEdge(&deleted, 0, 1));
    try std.testing.expect(hasEdge(&deleted, 1, 2));
    try std.testing.expect(hasEdge(&deleted, 2, 5));
    try std.testing.expect(hasEdge(&deleted, 4, 5));
    try std.testing.expect(hasEdge(&deleted, 3, 4));
    try std.testing.expect(hasEdge(&deleted, 0, 3));
}

test "delete edge removes the single incident face of a boundary edge" {
    var mesh = try mesh_mod.Mesh.init(std.testing.allocator);
    defer mesh.deinit();

    _ = try mesh.appendVertex(.{ .x = -1, .y = -1, .z = 0 });
    _ = try mesh.appendVertex(.{ .x = 1, .y = -1, .z = 0 });
    _ = try mesh.appendVertex(.{ .x = 1, .y = 1, .z = 0 });
    _ = try mesh.appendVertex(.{ .x = -1, .y = 1, .z = 0 });
    try mesh.appendFace(&[_]u32{ 0, 1, 2, 3 }, null);
    try mesh.rebuildEdgesFromFaces();

    var deleted = try deleteEdges(std.testing.allocator, &mesh, &[_]mesh_mod.Edge{
        .{ .a = 0, .b = 1 },
    }, .{});
    defer deleted.deinit();

    try std.testing.expectEqual(@as(usize, 4), deleted.vertexCount());
    try std.testing.expectEqual(@as(usize, 0), deleted.faceCount());
    try std.testing.expectEqual(@as(usize, 4), deleted.edges.items.len);
}

test "delete edge rejects multiple selected edges in one call" {
    var mesh = try mesh_mod.Mesh.init(std.testing.allocator);
    defer mesh.deinit();

    _ = try mesh.appendVertex(.{ .x = 0, .y = 0, .z = 0 });
    _ = try mesh.appendVertex(.{ .x = 1, .y = 0, .z = 0 });
    _ = try mesh.appendVertex(.{ .x = 2, .y = 0, .z = 0 });
    try mesh.appendEdge(0, 1);
    try mesh.appendEdge(1, 2);

    try std.testing.expectError(error.InvalidEdgeSelectionCount, deleteEdges(std.testing.allocator, &mesh, &[_]mesh_mod.Edge{
        .{ .a = 0, .b = 1 },
        .{ .a = 1, .b = 2 },
    }, .{}));
}

test "delete edge rejects invalid or non-manifold selections" {
    var mesh = try mesh_mod.Mesh.init(std.testing.allocator);
    defer mesh.deinit();

    _ = try mesh.appendVertex(.{ .x = 0, .y = 0, .z = 0 });
    _ = try mesh.appendVertex(.{ .x = 1, .y = 0, .z = 0 });
    _ = try mesh.appendVertex(.{ .x = 0, .y = 1, .z = 0 });
    _ = try mesh.appendVertex(.{ .x = 0, .y = -1, .z = 0 });
    _ = try mesh.appendVertex(.{ .x = 1, .y = 1, .z = 0 });
    try mesh.appendFace(&[_]u32{ 0, 1, 2 }, null);
    try mesh.appendFace(&[_]u32{ 1, 0, 3 }, null);
    try mesh.appendFace(&[_]u32{ 0, 1, 4 }, null);
    try mesh.rebuildEdgesFromFaces();

    try std.testing.expectError(error.InvalidEdgeSelection, deleteEdges(std.testing.allocator, &mesh, &[_]mesh_mod.Edge{
        .{ .a = 2, .b = 4 },
    }, .{}));
    try std.testing.expectError(error.NonManifoldEdgeSelection, deleteEdges(std.testing.allocator, &mesh, &[_]mesh_mod.Edge{
        .{ .a = 0, .b = 1 },
    }, .{}));
}

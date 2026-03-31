const std = @import("std");
const math = @import("../math.zig");
const mesh_mod = @import("../mesh.zig");

pub const DeleteFacesOptions = struct {};

const FaceEdgeUses = struct {
    selected_count: u8 = 0,
    kept_count: u8 = 0,
};

// This is the first bounded edit-style delete slice: remove selected faces, keep the
// surviving face topology, preserve the exposed boundary of the deleted region as
// loose edges, and carry through any pre-existing loose edges outside the selection.
pub fn deleteFaces(
    allocator: std.mem.Allocator,
    mesh: *const mesh_mod.Mesh,
    faces_to_delete: []const usize,
    _: DeleteFacesOptions,
) !mesh_mod.Mesh {
    if (faces_to_delete.len == 0) {
        return mesh.clone(allocator);
    }

    const selected_faces = try allocator.alloc(bool, mesh.faceCount());
    defer allocator.free(selected_faces);
    @memset(selected_faces, false);

    for (faces_to_delete) |face_index| {
        if (face_index >= mesh.faceCount()) return error.InvalidFaceSelection;
        selected_faces[face_index] = true;
    }

    var source_face_edge_keys = std.AutoHashMap(u64, void).init(allocator);
    defer source_face_edge_keys.deinit();

    var face_edge_uses = std.AutoHashMap(u64, FaceEdgeUses).init(allocator);
    defer face_edge_uses.deinit();

    const kept_vertices = try allocator.alloc(bool, mesh.vertexCount());
    defer allocator.free(kept_vertices);
    @memset(kept_vertices, false);

    for (0..mesh.faceCount()) |face_index| {
        const range = mesh.faceVertexRange(face_index);
        const face_verts = mesh.corner_verts.items[range.start..range.end];
        if (face_verts.len < 3) return error.InvalidFace;

        const delete_face = selected_faces[face_index];
        if (!delete_face) {
            for (face_verts) |vertex| {
                kept_vertices[vertex] = true;
            }
        }

        for (face_verts, 0..) |vertex, local_index| {
            const next_vertex = face_verts[(local_index + 1) % face_verts.len];
            const edge_key = packUndirectedEdge(vertex, next_vertex);
            try source_face_edge_keys.put(edge_key, {});

            const entry = try face_edge_uses.getOrPut(edge_key);
            if (!entry.found_existing) {
                entry.value_ptr.* = .{};
            }
            if (delete_face) {
                entry.value_ptr.selected_count += 1;
            } else {
                entry.value_ptr.kept_count += 1;
            }
        }
    }

    var deleted_boundary_edges = std.ArrayList(mesh_mod.Edge).empty;
    defer deleted_boundary_edges.deinit(allocator);

    var face_edge_iter = face_edge_uses.iterator();
    while (face_edge_iter.next()) |entry| {
        const uses = entry.value_ptr.*;
        // Only keep the outer border of the deleted region as loose wire. Shared edges
        // between kept faces and deleted faces are rebuilt from the kept faces, while
        // edges buried inside the deleted region disappear with the deleted faces.
        if (uses.selected_count != 1 or uses.kept_count != 0) continue;

        const edge = unpackUndirectedEdge(entry.key_ptr.*);
        kept_vertices[edge.a] = true;
        kept_vertices[edge.b] = true;
        try deleted_boundary_edges.append(allocator, edge);
    }

    for (mesh.edges.items) |edge| {
        const edge_key = packUndirectedEdge(edge.a, edge.b);
        if (source_face_edge_keys.contains(edge_key)) continue;
        kept_vertices[edge.a] = true;
        kept_vertices[edge.b] = true;
    }

    var result = try mesh_mod.Mesh.init(allocator);
    errdefer result.deinit();

    const remap = try allocator.alloc(u32, mesh.vertexCount());
    defer allocator.free(remap);
    @memset(remap, std.math.maxInt(u32));

    for (mesh.positions.items, 0..) |position, old_index| {
        if (!kept_vertices[old_index]) continue;
        remap[old_index] = try result.appendVertex(position);
    }

    const has_corner_uvs = mesh.hasCornerUvs();
    for (0..mesh.faceCount()) |face_index| {
        if (selected_faces[face_index]) continue;

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

    var result_edge_keys = std.AutoHashMap(u64, void).init(allocator);
    defer result_edge_keys.deinit();
    for (result.edges.items) |edge| {
        try result_edge_keys.put(packUndirectedEdge(edge.a, edge.b), {});
    }

    for (deleted_boundary_edges.items) |edge| {
        try appendLooseEdge(&result, &result_edge_keys, remap[edge.a], remap[edge.b]);
    }

    for (mesh.edges.items) |edge| {
        const edge_key = packUndirectedEdge(edge.a, edge.b);
        if (source_face_edge_keys.contains(edge_key)) continue;
        try appendLooseEdge(&result, &result_edge_keys, remap[edge.a], remap[edge.b]);
    }

    return result;
}

fn appendLooseEdge(
    result: *mesh_mod.Mesh,
    edge_keys: *std.AutoHashMap(u64, void),
    a: u32,
    b: u32,
) !void {
    if (a == std.math.maxInt(u32) or b == std.math.maxInt(u32)) return;

    const edge_key = packUndirectedEdge(a, b);
    if (edge_keys.contains(edge_key)) return;
    try edge_keys.put(edge_key, {});
    try result.appendEdge(@min(a, b), @max(a, b));
}

fn packUndirectedEdge(a: u32, b: u32) u64 {
    const lo = @min(a, b);
    const hi = @max(a, b);
    return (@as(u64, hi) << 32) | @as(u64, lo);
}

fn unpackUndirectedEdge(key: u64) mesh_mod.Edge {
    return .{
        .a = @intCast(key & 0xffffffff),
        .b = @intCast(key >> 32),
    };
}

fn hasEdge(mesh: *const mesh_mod.Mesh, a: u32, b: u32) bool {
    const lo = @min(a, b);
    const hi = @max(a, b);
    for (mesh.edges.items) |edge| {
        if (edge.a == lo and edge.b == hi) return true;
    }
    return false;
}

test "delete faces keeps the remaining face and exposes the deleted border as loose wire" {
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

    var deleted = try deleteFaces(std.testing.allocator, &mesh, &[_]usize{0}, .{});
    defer deleted.deinit();

    try std.testing.expectEqual(@as(usize, 6), deleted.vertexCount());
    try std.testing.expectEqual(@as(usize, 1), deleted.faceCount());
    try std.testing.expectEqual(@as(usize, 7), deleted.edges.items.len);
    try std.testing.expect(deleted.hasCornerUvs());
    try std.testing.expectEqual(@as(usize, 4), deleted.corner_uvs.items.len);
    try std.testing.expect(hasEdge(&deleted, 0, 1));
    try std.testing.expect(hasEdge(&deleted, 0, 3));
    try std.testing.expect(hasEdge(&deleted, 3, 4));
    try std.testing.expect(hasEdge(&deleted, 1, 4));
}

test "delete faces turns a single quad into its loose border" {
    var mesh = try mesh_mod.Mesh.init(std.testing.allocator);
    defer mesh.deinit();

    _ = try mesh.appendVertex(.{ .x = -1, .y = -1, .z = 0 });
    _ = try mesh.appendVertex(.{ .x = 1, .y = -1, .z = 0 });
    _ = try mesh.appendVertex(.{ .x = 1, .y = 1, .z = 0 });
    _ = try mesh.appendVertex(.{ .x = -1, .y = 1, .z = 0 });

    try mesh.appendFace(&[_]u32{ 0, 1, 2, 3 }, null);
    try mesh.rebuildEdgesFromFaces();

    var deleted = try deleteFaces(std.testing.allocator, &mesh, &[_]usize{0}, .{});
    defer deleted.deinit();

    try std.testing.expectEqual(@as(usize, 4), deleted.vertexCount());
    try std.testing.expectEqual(@as(usize, 0), deleted.faceCount());
    try std.testing.expectEqual(@as(usize, 4), deleted.edges.items.len);
    try std.testing.expect(hasEdge(&deleted, 0, 1));
    try std.testing.expect(hasEdge(&deleted, 1, 2));
    try std.testing.expect(hasEdge(&deleted, 2, 3));
    try std.testing.expect(hasEdge(&deleted, 0, 3));
}

test "delete faces preserves loose edges outside the deleted region" {
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

    var deleted = try deleteFaces(std.testing.allocator, &mesh, &[_]usize{0}, .{});
    defer deleted.deinit();

    try std.testing.expectEqual(@as(usize, 6), deleted.vertexCount());
    try std.testing.expectEqual(@as(usize, 0), deleted.faceCount());
    try std.testing.expectEqual(@as(usize, 5), deleted.edges.items.len);
    try std.testing.expect(hasEdge(&deleted, 4, 5));
}

test "delete faces with an empty selection is a no-op clone" {
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

    var deleted = try deleteFaces(std.testing.allocator, &mesh, &[_]usize{}, .{});
    defer deleted.deinit();

    try std.testing.expectEqual(mesh.vertexCount(), deleted.vertexCount());
    try std.testing.expectEqual(mesh.faceCount(), deleted.faceCount());
    try std.testing.expectEqual(mesh.edges.items.len, deleted.edges.items.len);
    try std.testing.expectEqualDeep(mesh.corner_verts.items, deleted.corner_verts.items);
    try std.testing.expectEqualDeep(mesh.corner_uvs.items, deleted.corner_uvs.items);
}

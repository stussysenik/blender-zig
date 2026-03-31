const std = @import("std");
const disjoint_set = @import("../blenlib/disjoint_set.zig");
const math = @import("../math.zig");
const mesh_mod = @import("../mesh.zig");

pub const MergeByDistanceOptions = struct {
    distance: f32 = 0.0001,
};

// This is the cleanup-oriented companion to triangulation: a bounded weld pass for the
// current mesh model that merges nearby vertices, rebuilds topology, and keeps loose
// edges that still survive after remapping.
pub fn mergeByDistance(
    allocator: std.mem.Allocator,
    mesh: *const mesh_mod.Mesh,
    options: MergeByDistanceOptions,
) !mesh_mod.Mesh {
    if (options.distance < 0) return error.InvalidDistance;

    var result = try mesh_mod.Mesh.init(allocator);
    errdefer result.deinit();

    if (mesh.vertexCount() == 0) {
        return result;
    }

    var sets = try buildVertexClusters(allocator, mesh, options.distance);
    defer sets.deinit();

    var remap = try buildVertexRemap(allocator, mesh, &sets);
    defer remap.deinit(allocator);

    for (remap.cluster_sums.items, 0..) |sum, cluster_index| {
        const count = remap.cluster_counts.items[cluster_index];
        const inv_count = 1.0 / @as(f32, @floatFromInt(count));
        _ = try result.appendVertex(sum.scale(inv_count));
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

        var cleaned_verts = std.ArrayList(u32).empty;
        defer cleaned_verts.deinit(allocator);

        var cleaned_uvs = std.ArrayList(math.Vec2).empty;
        defer cleaned_uvs.deinit(allocator);

        for (face_verts, 0..) |vertex, local_index| {
            const merged_vertex = remap.old_to_new[vertex];
            if (cleaned_verts.items.len > 0 and cleaned_verts.items[cleaned_verts.items.len - 1] == merged_vertex) {
                continue;
            }
            try cleaned_verts.append(allocator, merged_vertex);
            if (has_corner_uvs) {
                try cleaned_uvs.append(allocator, face_uvs[local_index]);
            }
        }

        // When the first and last corners weld together, collapse the duplicate closing
        // corner before validating the face.
        if (cleaned_verts.items.len > 1 and cleaned_verts.items[0] == cleaned_verts.items[cleaned_verts.items.len - 1]) {
            _ = cleaned_verts.pop();
            if (has_corner_uvs) {
                _ = cleaned_uvs.pop();
            }
        }

        if (cleaned_verts.items.len < 3 or hasRepeatedVertex(cleaned_verts.items)) {
            continue;
        }

        const maybe_uvs: ?[]const math.Vec2 = if (has_corner_uvs) cleaned_uvs.items else null;
        try result.appendFace(cleaned_verts.items, maybe_uvs);
    }

    try result.rebuildEdgesFromFaces();

    var result_face_edge_keys = std.AutoHashMap(u64, void).init(allocator);
    defer result_face_edge_keys.deinit();
    for (result.edges.items) |edge| {
        try result_face_edge_keys.put(packUndirectedEdge(edge.a, edge.b), {});
    }

    var appended_loose_edges = std.AutoHashMap(u64, void).init(allocator);
    defer appended_loose_edges.deinit();

    for (mesh.edges.items) |edge| {
        const source_key = packUndirectedEdge(edge.a, edge.b);
        if (source_face_edge_keys.contains(source_key)) continue;

        const merged_a = remap.old_to_new[edge.a];
        const merged_b = remap.old_to_new[edge.b];
        if (merged_a == merged_b) continue;

        const merged_key = packUndirectedEdge(merged_a, merged_b);
        if (result_face_edge_keys.contains(merged_key) or appended_loose_edges.contains(merged_key)) {
            continue;
        }

        try appended_loose_edges.put(merged_key, {});
        try result.appendEdge(@min(merged_a, merged_b), @max(merged_a, merged_b));
    }

    return result;
}

const VertexRemap = struct {
    old_to_new: []u32,
    cluster_sums: std.ArrayList(math.Vec3),
    cluster_counts: std.ArrayList(u32),

    fn deinit(self: *VertexRemap, allocator: std.mem.Allocator) void {
        allocator.free(self.old_to_new);
        self.cluster_sums.deinit(allocator);
        self.cluster_counts.deinit(allocator);
    }
};

fn buildVertexClusters(
    allocator: std.mem.Allocator,
    mesh: *const mesh_mod.Mesh,
    distance: f32,
) !disjoint_set.DisjointSet {
    var sets = try disjoint_set.DisjointSet.init(allocator, mesh.vertexCount());
    errdefer sets.deinit();

    const distance_squared = distance * distance;
    // The current rewrite only targets relatively small generated meshes, so an O(n^2)
    // proximity pass is acceptable until spatial acceleration becomes worth the weight.
    for (mesh.positions.items, 0..) |position_a, index_a| {
        for (mesh.positions.items[index_a + 1 ..], 0..) |position_b, offset_b| {
            if (position_a.sub(position_b).lengthSquared() <= distance_squared) {
                _ = sets.join(@intCast(index_a), @intCast(index_a + 1 + offset_b));
            }
        }
    }

    return sets;
}

fn buildVertexRemap(
    allocator: std.mem.Allocator,
    mesh: *const mesh_mod.Mesh,
    sets: *disjoint_set.DisjointSet,
) !VertexRemap {
    var root_to_cluster = std.AutoHashMap(u32, u32).init(allocator);
    defer root_to_cluster.deinit();

    const old_to_new = try allocator.alloc(u32, mesh.vertexCount());
    errdefer allocator.free(old_to_new);

    var cluster_sums: std.ArrayList(math.Vec3) = .empty;
    errdefer cluster_sums.deinit(allocator);

    var cluster_counts: std.ArrayList(u32) = .empty;
    errdefer cluster_counts.deinit(allocator);

    for (mesh.positions.items, 0..) |position, old_index| {
        const root = sets.findRoot(@intCast(old_index));
        const entry = try root_to_cluster.getOrPut(root);
        if (!entry.found_existing) {
            entry.value_ptr.* = @intCast(cluster_sums.items.len);
            try cluster_sums.append(allocator, position);
            try cluster_counts.append(allocator, 1);
        } else {
            cluster_sums.items[entry.value_ptr.*] = cluster_sums.items[entry.value_ptr.*].add(position);
            cluster_counts.items[entry.value_ptr.*] += 1;
        }
        old_to_new[old_index] = entry.value_ptr.*;
    }

    return .{
        .old_to_new = old_to_new,
        .cluster_sums = cluster_sums,
        .cluster_counts = cluster_counts,
    };
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

test "merge by distance welds duplicated seam vertices while preserving faces and uvs" {
    var mesh = try mesh_mod.Mesh.init(std.testing.allocator);
    defer mesh.deinit();

    _ = try mesh.appendVertex(.{ .x = -1, .y = -1, .z = 0 });
    _ = try mesh.appendVertex(.{ .x = 0, .y = -1, .z = 0 });
    _ = try mesh.appendVertex(.{ .x = 0, .y = 1, .z = 0 });
    _ = try mesh.appendVertex(.{ .x = -1, .y = 1, .z = 0 });
    _ = try mesh.appendVertex(.{ .x = 0, .y = -1, .z = 0 });
    _ = try mesh.appendVertex(.{ .x = 1, .y = -1, .z = 0 });
    _ = try mesh.appendVertex(.{ .x = 1, .y = 1, .z = 0 });
    _ = try mesh.appendVertex(.{ .x = 0, .y = 1, .z = 0 });

    const face_uvs = [_]math.Vec2{
        .{ .x = 0, .y = 0 },
        .{ .x = 1, .y = 0 },
        .{ .x = 1, .y = 1 },
        .{ .x = 0, .y = 1 },
    };
    try mesh.appendFace(&[_]u32{ 0, 1, 2, 3 }, &face_uvs);
    try mesh.appendFace(&[_]u32{ 4, 5, 6, 7 }, &face_uvs);
    try mesh.rebuildEdgesFromFaces();

    var merged = try mergeByDistance(std.testing.allocator, &mesh, .{ .distance = 0.01 });
    defer merged.deinit();

    try std.testing.expectEqual(@as(usize, 6), merged.vertexCount());
    try std.testing.expectEqual(@as(usize, 2), merged.faceCount());
    try std.testing.expectEqual(@as(usize, 7), merged.edges.items.len);
    try std.testing.expect(merged.hasCornerUvs());
    try std.testing.expectEqual(@as(usize, 8), merged.corner_uvs.items.len);
    try std.testing.expectEqualSlices(u32, &[_]u32{ 0, 1, 2, 3, 1, 4, 5, 2 }, merged.corner_verts.items);
    try std.testing.expect(math.vec2ApproxEq(merged.corner_uvs.items[4], .{ .x = 0, .y = 0 }, 0.0001));
}

test "merge by distance drops degenerate faces and collapsed loose edges" {
    var mesh = try mesh_mod.Mesh.init(std.testing.allocator);
    defer mesh.deinit();

    _ = try mesh.appendVertex(.{ .x = 0.0, .y = 0.0, .z = 0.0 });
    _ = try mesh.appendVertex(.{ .x = 0.001, .y = 0.0, .z = 0.0 });
    _ = try mesh.appendVertex(.{ .x = 1.0, .y = 0.0, .z = 0.0 });
    _ = try mesh.appendVertex(.{ .x = 3.0, .y = 0.0, .z = 0.0 });
    _ = try mesh.appendVertex(.{ .x = 3.0005, .y = 0.0, .z = 0.0 });

    try mesh.appendFace(&[_]u32{ 0, 1, 2 }, null);
    try mesh.rebuildEdgesFromFaces();
    try mesh.appendEdge(3, 4);

    var merged = try mergeByDistance(std.testing.allocator, &mesh, .{ .distance = 0.01 });
    defer merged.deinit();

    try std.testing.expectEqual(@as(usize, 3), merged.vertexCount());
    try std.testing.expectEqual(@as(usize, 0), merged.faceCount());
    try std.testing.expectEqual(@as(usize, 0), merged.edges.items.len);
}

test "merge by distance keeps surviving loose edges after remapping" {
    var mesh = try mesh_mod.Mesh.init(std.testing.allocator);
    defer mesh.deinit();

    _ = try mesh.appendVertex(.{ .x = 0.0, .y = 0.0, .z = 0.0 });
    _ = try mesh.appendVertex(.{ .x = 0.0005, .y = 0.0, .z = 0.0 });
    _ = try mesh.appendVertex(.{ .x = 1.0, .y = 0.0, .z = 0.0 });
    _ = try mesh.appendVertex(.{ .x = 2.0, .y = 0.0, .z = 0.0 });
    try mesh.appendEdge(0, 2);
    try mesh.appendEdge(1, 3);

    var merged = try mergeByDistance(std.testing.allocator, &mesh, .{ .distance = 0.01 });
    defer merged.deinit();

    try std.testing.expectEqual(@as(usize, 3), merged.vertexCount());
    try std.testing.expectEqual(@as(usize, 2), merged.edges.items.len);
    try std.testing.expect(hasEdge(&merged, 0, 1));
    try std.testing.expect(hasEdge(&merged, 0, 2));
}

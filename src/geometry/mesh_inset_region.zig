const std = @import("std");
const math = @import("../math.zig");
const mesh_mod = @import("../mesh.zig");

pub const InsetRegionOptions = struct {
    width: f32 = 0.2,
    normal_epsilon: f32 = 1e-4,
    plane_epsilon: f32 = 1e-4,
};

const BoundaryUse = struct {
    face_index: usize,
    local_index: usize,
};

const EdgeBoundary = struct {
    count: u8 = 0,
    first_use: ?BoundaryUse = null,
};

// This is the first bounded region-inset slice in the rewrite: offset the outer
// boundary of one planar open face region inward, keep the interior cap topology, and
// fill the new border with quads. It intentionally rejects non-planar inputs instead
// of pretending to implement Blender's full general bevel machinery.
pub fn insetRegion(
    allocator: std.mem.Allocator,
    mesh: *const mesh_mod.Mesh,
    options: InsetRegionOptions,
) !mesh_mod.Mesh {
    if (options.width <= 0.0) return error.InvalidInsetRegionWidth;
    if (options.normal_epsilon < 0.0 or options.plane_epsilon < 0.0) return error.InvalidInsetRegionTolerance;

    if (mesh.faceCount() == 0) {
        return mesh.clone(allocator);
    }

    const face_normals = try allocator.alloc(math.Vec3, mesh.faceCount());
    defer allocator.free(face_normals);

    const plane_anchor = blk: {
        const range = mesh.faceVertexRange(0);
        break :blk mesh.positions.items[mesh.corner_verts.items[range.start]];
    };

    var region_normal_sum = math.Vec3.init(0, 0, 0);
    for (0..mesh.faceCount()) |face_index| {
        const range = mesh.faceVertexRange(face_index);
        const face_verts = mesh.corner_verts.items[range.start..range.end];
        if (face_verts.len < 3) return error.InvalidFace;

        const normal = faceNormal(mesh, face_verts);
        face_normals[face_index] = normal;
        region_normal_sum = region_normal_sum.add(normal);
    }

    const region_normal = region_normal_sum.normalizedOr(math.Vec3.init(0, 0, 1));
    for (0..mesh.faceCount()) |face_index| {
        if (face_normals[face_index].dot(region_normal) < 1.0 - options.normal_epsilon) {
            return error.NonPlanarInsetRegion;
        }

        const range = mesh.faceVertexRange(face_index);
        const face_verts = mesh.corner_verts.items[range.start..range.end];
        for (face_verts) |vertex| {
            const plane_distance = @abs(mesh.positions.items[vertex].sub(plane_anchor).dot(region_normal));
            if (plane_distance > options.plane_epsilon) {
                return error.NonPlanarInsetRegion;
            }
        }
    }

    var source_face_edge_keys = std.AutoHashMap(u64, void).init(allocator);
    defer source_face_edge_keys.deinit();

    var boundary_edges = std.AutoHashMap(u64, EdgeBoundary).init(allocator);
    defer boundary_edges.deinit();

    const boundary_inward_sums = try allocator.alloc(math.Vec3, mesh.vertexCount());
    defer allocator.free(boundary_inward_sums);
    @memset(boundary_inward_sums, math.Vec3.init(0, 0, 0));

    const boundary_vertices = try allocator.alloc(bool, mesh.vertexCount());
    defer allocator.free(boundary_vertices);
    @memset(boundary_vertices, false);

    for (0..mesh.faceCount()) |face_index| {
        const range = mesh.faceVertexRange(face_index);
        const face_verts = mesh.corner_verts.items[range.start..range.end];
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
    var boundary_iter = boundary_edges.iterator();
    while (boundary_iter.next()) |entry| {
        if (entry.value_ptr.count != 1) continue;
        boundary_count += 1;

        const use = entry.value_ptr.first_use.?;
        const range = mesh.faceVertexRange(use.face_index);
        const face_verts = mesh.corner_verts.items[range.start..range.end];
        const a = face_verts[use.local_index];
        const b = face_verts[(use.local_index + 1) % face_verts.len];
        const inward = inwardForEdge(mesh.positions.items[a], mesh.positions.items[b], region_normal);
        boundary_inward_sums[a] = boundary_inward_sums[a].add(inward);
        boundary_inward_sums[b] = boundary_inward_sums[b].add(inward);
        boundary_vertices[a] = true;
        boundary_vertices[b] = true;
    }

    // Closed shells have no exposed boundary to inset. For this bounded slice, treat
    // them as a no-op instead of manufacturing bevel-style interior topology.
    if (boundary_count == 0) {
        return mesh.clone(allocator);
    }

    const boundary_dirs = try allocator.alloc(math.Vec3, mesh.vertexCount());
    defer allocator.free(boundary_dirs);
    @memset(boundary_dirs, math.Vec3.init(0, 0, 0));

    for (boundary_vertices, 0..) |is_boundary, vertex_index| {
        if (!is_boundary) continue;
        boundary_dirs[vertex_index] = boundary_inward_sums[vertex_index].normalizedOr(math.Vec3.init(0, 0, 0));
    }

    const scale_denominators = try allocator.alloc(f32, mesh.vertexCount());
    defer allocator.free(scale_denominators);
    @memset(scale_denominators, 0.0);

    boundary_iter = boundary_edges.iterator();
    while (boundary_iter.next()) |entry| {
        if (entry.value_ptr.count != 1) continue;

        const use = entry.value_ptr.first_use.?;
        const range = mesh.faceVertexRange(use.face_index);
        const face_verts = mesh.corner_verts.items[range.start..range.end];
        const a = face_verts[use.local_index];
        const b = face_verts[(use.local_index + 1) % face_verts.len];
        const inward = inwardForEdge(mesh.positions.items[a], mesh.positions.items[b], region_normal);

        scale_denominators[a] = @max(scale_denominators[a], boundary_dirs[a].dot(inward));
        scale_denominators[b] = @max(scale_denominators[b], boundary_dirs[b].dot(inward));
    }

    var result = try mesh_mod.Mesh.init(allocator);
    errdefer result.deinit();

    for (mesh.positions.items) |position| {
        _ = try result.appendVertex(position);
    }

    const inset_vertex_remap = try allocator.alloc(u32, mesh.vertexCount());
    defer allocator.free(inset_vertex_remap);
    @memset(inset_vertex_remap, std.math.maxInt(u32));

    for (boundary_vertices, 0..) |is_boundary, vertex_index| {
        if (!is_boundary) continue;

        const scale = options.width / @max(scale_denominators[vertex_index], 0.25);
        const offset = boundary_dirs[vertex_index].scale(scale);
        inset_vertex_remap[vertex_index] = try result.appendVertex(mesh.positions.items[vertex_index].add(offset));
    }

    const has_corner_uvs = mesh.hasCornerUvs();
    for (0..mesh.faceCount()) |face_index| {
        const range = mesh.faceVertexRange(face_index);
        const face_verts = mesh.corner_verts.items[range.start..range.end];
        const face_uvs = if (has_corner_uvs) mesh.corner_uvs.items[range.start..range.end] else &[_]math.Vec2{};

        // The cap keeps the source face layout intact and only remaps the boundary
        // corners to their inset copies, which makes the resulting topology easy to
        // reason about in tests and later region-style ports.
        const cap_verts = try allocator.alloc(u32, face_verts.len);
        defer allocator.free(cap_verts);
        for (face_verts, 0..) |vertex, local_index| {
            cap_verts[local_index] = if (boundary_vertices[vertex]) inset_vertex_remap[vertex] else @as(u32, @intCast(vertex));
        }

        const maybe_uvs: ?[]const math.Vec2 = if (has_corner_uvs) face_uvs else null;
        try result.appendFace(cap_verts, maybe_uvs);
    }

    boundary_iter = boundary_edges.iterator();
    while (boundary_iter.next()) |entry| {
        if (entry.value_ptr.count != 1) continue;

        const use = entry.value_ptr.first_use.?;
        const range = mesh.faceVertexRange(use.face_index);
        const face_verts = mesh.corner_verts.items[range.start..range.end];
        const a = face_verts[use.local_index];
        const b = face_verts[(use.local_index + 1) % face_verts.len];
        const side_face = [_]u32{
            a,
            b,
            inset_vertex_remap[b],
            inset_vertex_remap[a],
        };

        if (has_corner_uvs) {
            const side_uvs = sideFaceUvs(mesh.positions.items[a], mesh.positions.items[b], options.width);
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

        // Re-attach loose source edges after rebuilding face topology so cleanup or
        // authoring steps that rely on explicit loose segments do not silently lose them.
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

fn inwardForEdge(a: math.Vec3, b: math.Vec3, region_normal: math.Vec3) math.Vec3 {
    const direction = b.sub(a).normalizedOr(math.Vec3.init(1, 0, 0));
    return region_normal.cross(direction).normalizedOr(math.Vec3.init(0, 1, 0));
}

fn sideFaceUvs(a: math.Vec3, b: math.Vec3, width: f32) [4]math.Vec2 {
    const u = @max(a.sub(b).length(), 1e-6);
    const v = @max(@abs(width), 1e-6);
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

test "region inset keeps a single quad cap and adds a border ring" {
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

    var inset = try insetRegion(std.testing.allocator, &mesh, .{ .width = 0.25 });
    defer inset.deinit();

    try std.testing.expectEqual(@as(usize, 8), inset.vertexCount());
    try std.testing.expectEqual(@as(usize, 5), inset.faceCount());
    try std.testing.expectEqual(@as(usize, 12), inset.edges.items.len);
    try std.testing.expect(inset.hasCornerUvs());
    try std.testing.expectEqual(@as(usize, 20), inset.corner_uvs.items.len);
    try std.testing.expect(math.vec3ApproxEq(inset.positions.items[4], .{ .x = -0.75, .y = -0.75, .z = 0 }, 0.0001));
}

test "region inset offsets an adjacent quad strip as one region" {
    var mesh = try mesh_mod.Mesh.init(std.testing.allocator);
    defer mesh.deinit();

    _ = try mesh.appendVertex(.{ .x = -1, .y = -1, .z = 0 });
    _ = try mesh.appendVertex(.{ .x = 0, .y = -1, .z = 0 });
    _ = try mesh.appendVertex(.{ .x = 1, .y = -1, .z = 0 });
    _ = try mesh.appendVertex(.{ .x = -1, .y = 1, .z = 0 });
    _ = try mesh.appendVertex(.{ .x = 0, .y = 1, .z = 0 });
    _ = try mesh.appendVertex(.{ .x = 1, .y = 1, .z = 0 });

    try mesh.appendFace(&[_]u32{ 0, 1, 4, 3 }, null);
    try mesh.appendFace(&[_]u32{ 1, 2, 5, 4 }, null);
    try mesh.rebuildEdgesFromFaces();

    var inset = try insetRegion(std.testing.allocator, &mesh, .{ .width = 0.2 });
    defer inset.deinit();

    try std.testing.expectEqual(@as(usize, 12), inset.vertexCount());
    try std.testing.expectEqual(@as(usize, 8), inset.faceCount());
    try std.testing.expectEqual(@as(usize, 19), inset.edges.items.len);
    try std.testing.expect(math.vec3ApproxEq(inset.positions.items[6], .{ .x = -0.8, .y = -0.8, .z = 0 }, 0.0001));
    try std.testing.expect(hasEdge(&inset, 7, 10));
}

test "region inset preserves loose edges outside the face region" {
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

    var inset = try insetRegion(std.testing.allocator, &mesh, .{ .width = 0.25 });
    defer inset.deinit();

    try std.testing.expectEqual(@as(usize, 10), inset.vertexCount());
    try std.testing.expectEqual(@as(usize, 5), inset.faceCount());
    try std.testing.expectEqual(@as(usize, 13), inset.edges.items.len);
    try std.testing.expect(hasEdge(&inset, 4, 5));
}

test "region inset rejects non-planar open regions" {
    var mesh = try mesh_mod.Mesh.init(std.testing.allocator);
    defer mesh.deinit();

    _ = try mesh.appendVertex(.{ .x = -1, .y = -1, .z = 0 });
    _ = try mesh.appendVertex(.{ .x = 1, .y = -1, .z = 0 });
    _ = try mesh.appendVertex(.{ .x = 1, .y = 1, .z = 0.5 });
    _ = try mesh.appendVertex(.{ .x = -1, .y = 1, .z = 0 });

    try mesh.appendFace(&[_]u32{ 0, 1, 2, 3 }, null);
    try mesh.rebuildEdgesFromFaces();

    try std.testing.expectError(
        error.NonPlanarInsetRegion,
        insetRegion(std.testing.allocator, &mesh, .{ .width = 0.25 }),
    );
}

const std = @import("std");
const math = @import("../math.zig");
const mesh_mod = @import("../mesh.zig");

pub const SubdivideOptions = struct {};

// Start with a bounded face subdivision pass that works on the current face-corner
// mesh model: reuse one midpoint vertex per shared edge, add one face center per face,
// and rebuild the smaller quads from those pieces.
pub fn subdivideFaces(
    allocator: std.mem.Allocator,
    mesh: *const mesh_mod.Mesh,
    options: SubdivideOptions,
) !mesh_mod.Mesh {
    _ = options;

    var result = try mesh_mod.Mesh.init(allocator);
    errdefer result.deinit();

    for (mesh.positions.items) |position| {
        _ = try result.appendVertex(position);
    }

    var source_face_edge_keys = std.AutoHashMap(u64, void).init(allocator);
    defer source_face_edge_keys.deinit();

    // Edge midpoint vertices are shared across adjacent faces so the subdivided output
    // stays connected instead of turning into independent per-face patches.
    var midpoint_vertices = std.AutoHashMap(u64, u32).init(allocator);
    defer midpoint_vertices.deinit();

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

        const center_vertex = try result.appendVertex(faceCentroid(mesh, face_verts));
        const center_uv = if (has_corner_uvs) faceUvCentroid(face_uvs) else math.Vec2.init(0, 0);

        for (face_verts, 0..) |current_vertex, local_index| {
            const next_index = (local_index + 1) % face_verts.len;
            const previous_index = (local_index + face_verts.len - 1) % face_verts.len;

            const next_midpoint = try getOrCreateEdgeMidpoint(
                &result,
                &midpoint_vertices,
                mesh,
                current_vertex,
                face_verts[next_index],
            );
            const previous_midpoint = try getOrCreateEdgeMidpoint(
                &result,
                &midpoint_vertices,
                mesh,
                face_verts[previous_index],
                current_vertex,
            );

            const quad = [_]u32{
                current_vertex,
                next_midpoint,
                center_vertex,
                previous_midpoint,
            };

            if (has_corner_uvs) {
                const quad_uvs = [_]math.Vec2{
                    face_uvs[local_index],
                    lerpVec2(face_uvs[local_index], face_uvs[next_index], 0.5),
                    center_uv,
                    lerpVec2(face_uvs[previous_index], face_uvs[local_index], 0.5),
                };
                try result.appendFace(&quad, &quad_uvs);
            } else {
                try result.appendFace(&quad, null);
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

fn getOrCreateEdgeMidpoint(
    result: *mesh_mod.Mesh,
    midpoint_vertices: *std.AutoHashMap(u64, u32),
    source_mesh: *const mesh_mod.Mesh,
    a: u32,
    b: u32,
) !u32 {
    const key = packUndirectedEdge(a, b);
    const entry = try midpoint_vertices.getOrPut(key);
    if (entry.found_existing) {
        return entry.value_ptr.*;
    }

    const midpoint = lerpVec3(source_mesh.positions.items[a], source_mesh.positions.items[b], 0.5);
    entry.value_ptr.* = try result.appendVertex(midpoint);
    return entry.value_ptr.*;
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

test "subdivide turns one quad into four smaller quads with shared midpoints" {
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

    var subdivided = try subdivideFaces(std.testing.allocator, &mesh, .{});
    defer subdivided.deinit();

    try std.testing.expectEqual(@as(usize, 9), subdivided.vertexCount());
    try std.testing.expectEqual(@as(usize, 4), subdivided.faceCount());
    try std.testing.expectEqual(@as(usize, 12), subdivided.edges.items.len);
    try std.testing.expect(subdivided.hasCornerUvs());
    try std.testing.expectEqual(@as(usize, 16), subdivided.corner_uvs.items.len);
    try std.testing.expect(math.vec3ApproxEq(subdivided.positions.items[4], .{ .x = 0, .y = 0, .z = 0 }, 0.0001));
    try std.testing.expect(math.vec3ApproxEq(subdivided.positions.items[5], .{ .x = 0, .y = -1, .z = 0 }, 0.0001));
}

test "subdivide reuses shared edge midpoints across adjacent quads" {
    var mesh = try mesh_mod.Mesh.init(std.testing.allocator);
    defer mesh.deinit();

    _ = try mesh.appendVertex(.{ .x = -1, .y = -1, .z = 0 });
    _ = try mesh.appendVertex(.{ .x = -1, .y = 1, .z = 0 });
    _ = try mesh.appendVertex(.{ .x = 0, .y = -1, .z = 0 });
    _ = try mesh.appendVertex(.{ .x = 0, .y = 1, .z = 0 });
    _ = try mesh.appendVertex(.{ .x = 1, .y = -1, .z = 0 });
    _ = try mesh.appendVertex(.{ .x = 1, .y = 1, .z = 0 });
    try mesh.appendFace(&[_]u32{ 0, 2, 3, 1 }, null);
    try mesh.appendFace(&[_]u32{ 2, 4, 5, 3 }, null);
    try mesh.rebuildEdgesFromFaces();

    var subdivided = try subdivideFaces(std.testing.allocator, &mesh, .{});
    defer subdivided.deinit();

    try std.testing.expectEqual(@as(usize, 15), subdivided.vertexCount());
    try std.testing.expectEqual(@as(usize, 8), subdivided.faceCount());
    try std.testing.expectEqual(@as(usize, 22), subdivided.edges.items.len);
}

test "subdivide preserves loose edges from edge-only meshes" {
    var mesh = try mesh_mod.Mesh.init(std.testing.allocator);
    defer mesh.deinit();

    _ = try mesh.appendVertex(.{ .x = 0, .y = 0, .z = 0 });
    _ = try mesh.appendVertex(.{ .x = 1, .y = 0, .z = 0 });
    _ = try mesh.appendVertex(.{ .x = 2, .y = 0, .z = 0 });
    try mesh.appendEdge(0, 1);
    try mesh.appendEdge(1, 2);

    var subdivided = try subdivideFaces(std.testing.allocator, &mesh, .{});
    defer subdivided.deinit();

    try std.testing.expectEqual(@as(usize, 3), subdivided.vertexCount());
    try std.testing.expectEqual(@as(usize, 0), subdivided.faceCount());
    try std.testing.expectEqual(@as(usize, 2), subdivided.edges.items.len);
    try std.testing.expect(hasEdge(&subdivided, 0, 1));
    try std.testing.expect(hasEdge(&subdivided, 1, 2));
}

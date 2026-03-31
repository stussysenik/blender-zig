const std = @import("std");
const math = @import("../math.zig");
const mesh_mod = @import("../mesh.zig");

pub const FillHoleOptions = struct {
    plane_epsilon: f32 = 1e-4,
};

// This is the first bounded repair/fill slice: find exactly one simple planar loose
// edge loop, turn it into one ngon cap, and preserve the rest of the mesh as-is.
// It deliberately avoids grid fill, bridge logic, and selected multi-loop behavior.
pub fn fillHole(
    allocator: std.mem.Allocator,
    mesh: *const mesh_mod.Mesh,
    options: FillHoleOptions,
) !mesh_mod.Mesh {
    if (options.plane_epsilon < 0.0) return error.InvalidFillHoleTolerance;

    var source_face_edge_keys = std.AutoHashMap(u64, void).init(allocator);
    defer source_face_edge_keys.deinit();

    for (0..mesh.faceCount()) |face_index| {
        const range = mesh.faceVertexRange(face_index);
        const face_verts = mesh.corner_verts.items[range.start..range.end];
        if (face_verts.len < 3) return error.InvalidFace;

        for (face_verts, 0..) |vertex, local_index| {
            const next_vertex = face_verts[(local_index + 1) % face_verts.len];
            try source_face_edge_keys.put(packUndirectedEdge(vertex, next_vertex), {});
        }
    }

    var loose_edges = std.ArrayList(mesh_mod.Edge).empty;
    defer loose_edges.deinit(allocator);

    for (mesh.edges.items) |edge| {
        if (source_face_edge_keys.contains(packUndirectedEdge(edge.a, edge.b))) continue;
        try loose_edges.append(allocator, edge);
    }

    if (loose_edges.items.len == 0) return error.NoFillHoleLoop;

    const incident = try allocator.alloc(std.ArrayListUnmanaged(usize), mesh.vertexCount());
    defer {
        for (incident) |*list| {
            list.deinit(allocator);
        }
        allocator.free(incident);
    }
    for (incident) |*list| {
        list.* = .{};
    }

    for (loose_edges.items, 0..) |edge, edge_index| {
        try incident[edge.a].append(allocator, edge_index);
        try incident[edge.b].append(allocator, edge_index);
    }

    const vertex_seen = try allocator.alloc(bool, mesh.vertexCount());
    defer allocator.free(vertex_seen);
    @memset(vertex_seen, false);

    const edge_seen = try allocator.alloc(bool, loose_edges.items.len);
    defer allocator.free(edge_seen);
    @memset(edge_seen, false);

    var fill_component_vertices = std.ArrayList(u32).empty;
    defer fill_component_vertices.deinit(allocator);

    var fill_component_edges = std.ArrayList(usize).empty;
    defer fill_component_edges.deinit(allocator);

    var cycle_count: usize = 0;
    var queue = std.ArrayList(u32).empty;
    defer queue.deinit(allocator);

    for (0..mesh.vertexCount()) |vertex_index| {
        if (incident[vertex_index].items.len == 0 or vertex_seen[vertex_index]) continue;

        queue.clearRetainingCapacity();
        try queue.append(allocator, @intCast(vertex_index));
        vertex_seen[vertex_index] = true;

        var component_vertices = std.ArrayList(u32).empty;
        defer component_vertices.deinit(allocator);
        var component_edges = std.ArrayList(usize).empty;
        defer component_edges.deinit(allocator);

        var queue_index: usize = 0;
        while (queue_index < queue.items.len) : (queue_index += 1) {
            const vertex = queue.items[queue_index];
            try component_vertices.append(allocator, vertex);

            for (incident[vertex].items) |edge_index| {
                if (!edge_seen[edge_index]) {
                    edge_seen[edge_index] = true;
                    try component_edges.append(allocator, edge_index);
                }

                const edge = loose_edges.items[edge_index];
                const other = if (edge.a == vertex) edge.b else edge.a;
                if (!vertex_seen[other]) {
                    vertex_seen[other] = true;
                    try queue.append(allocator, other);
                }
            }
        }

        if (!componentIsSimpleCycle(incident, component_vertices.items, component_edges.items)) continue;

        cycle_count += 1;
        if (cycle_count > 1) return error.MultipleFillHoleLoops;

        fill_component_vertices.clearRetainingCapacity();
        try fill_component_vertices.appendSlice(allocator, component_vertices.items);

        fill_component_edges.clearRetainingCapacity();
        try fill_component_edges.appendSlice(allocator, component_edges.items);
    }

    if (cycle_count == 0) return error.NoFillHoleLoop;

    const ordered_loop = try orderCycleVertices(allocator, incident, loose_edges.items, fill_component_vertices.items);
    defer allocator.free(ordered_loop);

    const normal = polygonNormal(mesh, ordered_loop);
    if (normal.length() <= 1e-6) return error.InvalidFillHoleLoop;
    const plane_normal = normal.normalizedOr(math.Vec3.init(0, 0, 1));
    const plane_anchor = mesh.positions.items[ordered_loop[0]];
    for (ordered_loop) |vertex| {
        const plane_distance = @abs(mesh.positions.items[vertex].sub(plane_anchor).dot(plane_normal));
        if (plane_distance > options.plane_epsilon) return error.NonPlanarFillHoleLoop;
    }

    var result = try mesh_mod.Mesh.init(allocator);
    errdefer result.deinit();

    for (mesh.positions.items) |position| {
        _ = try result.appendVertex(position);
    }

    const has_corner_uvs = mesh.hasCornerUvs();
    for (0..mesh.faceCount()) |face_index| {
        const range = mesh.faceVertexRange(face_index);
        const face_verts = mesh.corner_verts.items[range.start..range.end];
        const face_uvs = if (has_corner_uvs) mesh.corner_uvs.items[range.start..range.end] else &[_]math.Vec2{};
        const maybe_uvs: ?[]const math.Vec2 = if (has_corner_uvs) face_uvs else null;
        try result.appendFace(face_verts, maybe_uvs);
    }

    const fill_uvs = if (has_corner_uvs) try buildPlanarUvs(allocator, mesh, ordered_loop, plane_normal) else &[_]math.Vec2{};
    defer if (has_corner_uvs) allocator.free(fill_uvs);

    const maybe_fill_uvs: ?[]const math.Vec2 = if (has_corner_uvs) fill_uvs else null;
    try result.appendFace(ordered_loop, maybe_fill_uvs);
    try result.rebuildEdgesFromFaces();

    var result_edge_keys = std.AutoHashMap(u64, void).init(allocator);
    defer result_edge_keys.deinit();
    for (result.edges.items) |edge| {
        try result_edge_keys.put(packUndirectedEdge(edge.a, edge.b), {});
    }

    const filled_edge_mask = try allocator.alloc(bool, loose_edges.items.len);
    defer allocator.free(filled_edge_mask);
    @memset(filled_edge_mask, false);
    for (fill_component_edges.items) |edge_index| {
        filled_edge_mask[edge_index] = true;
    }

    for (loose_edges.items, 0..) |edge, edge_index| {
        if (filled_edge_mask[edge_index]) continue;
        const edge_key = packUndirectedEdge(edge.a, edge.b);
        if (result_edge_keys.contains(edge_key)) continue;
        try result_edge_keys.put(edge_key, {});
        try result.appendEdge(@min(edge.a, edge.b), @max(edge.a, edge.b));
    }

    return result;
}

fn componentIsSimpleCycle(
    incident: []const std.ArrayListUnmanaged(usize),
    vertices: []const u32,
    edges: []const usize,
) bool {
    if (vertices.len < 3 or vertices.len != edges.len) return false;
    for (vertices) |vertex| {
        if (incident[vertex].items.len != 2) return false;
    }
    return true;
}

fn orderCycleVertices(
    allocator: std.mem.Allocator,
    incident: []const std.ArrayListUnmanaged(usize),
    loose_edges: []const mesh_mod.Edge,
    component_vertices: []const u32,
) ![]u32 {
    var start_vertex = component_vertices[0];
    for (component_vertices[1..]) |vertex| {
        if (vertex < start_vertex) start_vertex = vertex;
    }

    const first_edge = loose_edges[incident[start_vertex].items[0]];
    const second_edge = loose_edges[incident[start_vertex].items[1]];
    const first_neighbor = otherVertex(first_edge, start_vertex);
    const second_neighbor = otherVertex(second_edge, start_vertex);
    const initial_next = @min(first_neighbor, second_neighbor);

    const ordered = try allocator.alloc(u32, component_vertices.len);
    errdefer allocator.free(ordered);

    var previous: u32 = std.math.maxInt(u32);
    var current: u32 = start_vertex;
    var index: usize = 0;

    while (index < ordered.len) : (index += 1) {
        ordered[index] = current;
        if (index == ordered.len - 1) break;

        const edges = incident[current].items;
        const edge_a = loose_edges[edges[0]];
        const edge_b = loose_edges[edges[1]];
        const neighbor_a = otherVertex(edge_a, current);
        const neighbor_b = otherVertex(edge_b, current);

        const next = if (previous == std.math.maxInt(u32))
            initial_next
        else if (neighbor_a == previous)
            neighbor_b
        else
            neighbor_a;

        previous = current;
        current = next;
    }

    const final_edges = incident[current].items;
    const closes =
        otherVertex(loose_edges[final_edges[0]], current) == start_vertex or
        otherVertex(loose_edges[final_edges[1]], current) == start_vertex;
    if (!closes) return error.InvalidFillHoleLoop;
    return ordered;
}

fn otherVertex(edge: mesh_mod.Edge, vertex: u32) u32 {
    return if (edge.a == vertex) edge.b else edge.a;
}

fn polygonNormal(mesh: *const mesh_mod.Mesh, loop: []const u32) math.Vec3 {
    var normal = math.Vec3.init(0, 0, 0);
    for (loop, 0..) |vertex, index| {
        const current = mesh.positions.items[vertex];
        const next = mesh.positions.items[loop[(index + 1) % loop.len]];
        normal.x += (current.y - next.y) * (current.z + next.z);
        normal.y += (current.z - next.z) * (current.x + next.x);
        normal.z += (current.x - next.x) * (current.y + next.y);
    }
    return normal;
}

fn buildPlanarUvs(
    allocator: std.mem.Allocator,
    mesh: *const mesh_mod.Mesh,
    loop: []const u32,
    normal: math.Vec3,
) ![]math.Vec2 {
    const helper = if (@abs(normal.z) < 0.9) math.Vec3.init(0, 0, 1) else math.Vec3.init(0, 1, 0);
    const tangent = helper.cross(normal).normalizedOr(math.Vec3.init(1, 0, 0));
    const bitangent = normal.cross(tangent).normalizedOr(math.Vec3.init(0, 1, 0));

    const projected = try allocator.alloc(math.Vec2, loop.len);
    defer allocator.free(projected);

    var min_u: f32 = std.math.floatMax(f32);
    var min_v: f32 = std.math.floatMax(f32);
    var max_u: f32 = -std.math.floatMax(f32);
    var max_v: f32 = -std.math.floatMax(f32);

    for (loop, 0..) |vertex, index| {
        const position = mesh.positions.items[vertex];
        const u = position.dot(tangent);
        const v = position.dot(bitangent);
        projected[index] = .{ .x = u, .y = v };
        min_u = @min(min_u, u);
        min_v = @min(min_v, v);
        max_u = @max(max_u, u);
        max_v = @max(max_v, v);
    }

    const u_extent = @max(max_u - min_u, 1e-6);
    const v_extent = @max(max_v - min_v, 1e-6);

    const uvs = try allocator.alloc(math.Vec2, loop.len);
    for (projected, 0..) |uv, index| {
        uvs[index] = .{
            .x = (uv.x - min_u) / u_extent,
            .y = (uv.y - min_v) / v_extent,
        };
    }
    return uvs;
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

test "fill hole turns one loose quad loop into one face" {
    var mesh = try mesh_mod.Mesh.init(std.testing.allocator);
    defer mesh.deinit();

    _ = try mesh.appendVertex(.{ .x = -1, .y = -1, .z = 0 });
    _ = try mesh.appendVertex(.{ .x = 1, .y = -1, .z = 0 });
    _ = try mesh.appendVertex(.{ .x = 1, .y = 1, .z = 0 });
    _ = try mesh.appendVertex(.{ .x = -1, .y = 1, .z = 0 });
    try mesh.appendEdge(0, 1);
    try mesh.appendEdge(1, 2);
    try mesh.appendEdge(2, 3);
    try mesh.appendEdge(3, 0);

    var filled = try fillHole(std.testing.allocator, &mesh, .{});
    defer filled.deinit();

    try std.testing.expectEqual(@as(usize, 4), filled.vertexCount());
    try std.testing.expectEqual(@as(usize, 1), filled.faceCount());
    try std.testing.expectEqual(@as(usize, 4), filled.edges.items.len);
    try std.testing.expectEqualSlices(u32, &[_]u32{ 0, 1, 2, 3 }, filled.corner_verts.items);
}

test "fill hole preserves unrelated faces and loose edges" {
    var mesh = try mesh_mod.Mesh.init(std.testing.allocator);
    defer mesh.deinit();

    _ = try mesh.appendVertex(.{ .x = -4, .y = -1, .z = 0 });
    _ = try mesh.appendVertex(.{ .x = -2, .y = -1, .z = 0 });
    _ = try mesh.appendVertex(.{ .x = -2, .y = 1, .z = 0 });
    _ = try mesh.appendVertex(.{ .x = -4, .y = 1, .z = 0 });
    _ = try mesh.appendVertex(.{ .x = 1, .y = -1, .z = 0 });
    _ = try mesh.appendVertex(.{ .x = 3, .y = -1, .z = 0 });
    _ = try mesh.appendVertex(.{ .x = 3, .y = 1, .z = 0 });
    _ = try mesh.appendVertex(.{ .x = 1, .y = 1, .z = 0 });
    _ = try mesh.appendVertex(.{ .x = 6, .y = 0, .z = 0 });
    _ = try mesh.appendVertex(.{ .x = 7, .y = 0, .z = 0 });

    const left_uvs = [_]math.Vec2{
        .{ .x = 0, .y = 0 },
        .{ .x = 1, .y = 0 },
        .{ .x = 1, .y = 1 },
        .{ .x = 0, .y = 1 },
    };
    try mesh.appendFace(&[_]u32{ 0, 1, 2, 3 }, &left_uvs);
    try mesh.rebuildEdgesFromFaces();
    try mesh.appendEdge(4, 5);
    try mesh.appendEdge(5, 6);
    try mesh.appendEdge(6, 7);
    try mesh.appendEdge(7, 4);
    try mesh.appendEdge(8, 9);

    var filled = try fillHole(std.testing.allocator, &mesh, .{});
    defer filled.deinit();

    try std.testing.expectEqual(@as(usize, 10), filled.vertexCount());
    try std.testing.expectEqual(@as(usize, 2), filled.faceCount());
    try std.testing.expectEqual(@as(usize, 9), filled.edges.items.len);
    try std.testing.expect(filled.hasCornerUvs());
    try std.testing.expectEqual(@as(usize, 8), filled.corner_uvs.items.len);
    try std.testing.expect(hasEdge(&filled, 8, 9));
}

test "fill hole rejects open loose chains" {
    var mesh = try mesh_mod.Mesh.init(std.testing.allocator);
    defer mesh.deinit();

    _ = try mesh.appendVertex(.{ .x = 0, .y = 0, .z = 0 });
    _ = try mesh.appendVertex(.{ .x = 1, .y = 0, .z = 0 });
    _ = try mesh.appendVertex(.{ .x = 2, .y = 0, .z = 0 });
    try mesh.appendEdge(0, 1);
    try mesh.appendEdge(1, 2);

    try std.testing.expectError(error.NoFillHoleLoop, fillHole(std.testing.allocator, &mesh, .{}));
}

test "fill hole rejects multiple loose loops in one pass" {
    var mesh = try mesh_mod.Mesh.init(std.testing.allocator);
    defer mesh.deinit();

    _ = try mesh.appendVertex(.{ .x = -3, .y = -1, .z = 0 });
    _ = try mesh.appendVertex(.{ .x = -1, .y = -1, .z = 0 });
    _ = try mesh.appendVertex(.{ .x = -1, .y = 1, .z = 0 });
    _ = try mesh.appendVertex(.{ .x = -3, .y = 1, .z = 0 });
    _ = try mesh.appendVertex(.{ .x = 1, .y = -1, .z = 0 });
    _ = try mesh.appendVertex(.{ .x = 3, .y = -1, .z = 0 });
    _ = try mesh.appendVertex(.{ .x = 3, .y = 1, .z = 0 });
    _ = try mesh.appendVertex(.{ .x = 1, .y = 1, .z = 0 });

    try mesh.appendEdge(0, 1);
    try mesh.appendEdge(1, 2);
    try mesh.appendEdge(2, 3);
    try mesh.appendEdge(3, 0);
    try mesh.appendEdge(4, 5);
    try mesh.appendEdge(5, 6);
    try mesh.appendEdge(6, 7);
    try mesh.appendEdge(7, 4);

    try std.testing.expectError(error.MultipleFillHoleLoops, fillHole(std.testing.allocator, &mesh, .{}));
}

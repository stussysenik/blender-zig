const std = @import("std");
const curves_mod = @import("curves.zig");
const math = @import("../math.zig");
const mesh_mod = @import("../mesh.zig");
const offset_indices = @import("../blenlib/offset_indices.zig");

// Convert explicit mesh edge connectivity into polyline curves. This stays edge-first
// and intentionally ignores richer spline types until the curve model expands.
const EdgeAdjacency = struct {
    allocator: std.mem.Allocator,
    offsets: []u32,
    incident_edges: []u32,

    fn deinit(self: *EdgeAdjacency) void {
        self.allocator.free(self.offsets);
        self.allocator.free(self.incident_edges);
    }

    fn incidentRange(self: *const EdgeAdjacency, vertex_index: usize) offset_indices.Range {
        return .{
            .start = self.offsets[vertex_index],
            .end = self.offsets[vertex_index + 1],
        };
    }
};

pub fn meshEdgesToCurves(
    allocator: std.mem.Allocator,
    mesh: *const mesh_mod.Mesh,
) !curves_mod.CurvesGeometry {
    var curves = try curves_mod.CurvesGeometry.init(allocator);
    errdefer curves.deinit();

    if (mesh.edges.items.len == 0 or mesh.positions.items.len == 0) {
        return curves;
    }

    var adjacency = try buildEdgeAdjacency(allocator, mesh);
    defer adjacency.deinit();

    const used_edges = try allocator.alloc(bool, mesh.edges.items.len);
    defer allocator.free(used_edges);
    @memset(used_edges, false);

    // Start open curves from non-manifold or endpoint vertices, then consume the
    // remaining untouched edge loops as cyclic curves.
    for (0..mesh.positions.items.len) |vertex_index| {
        const incident = adjacency.incidentRange(vertex_index);
        if (incident.len() == 0 or incident.len() == 2) {
            continue;
        }
        for (incident.start..incident.end) |slot| {
            const edge_index = adjacency.incident_edges[slot];
            if (used_edges[edge_index]) continue;
            try appendOpenCurveFromEdge(
                allocator,
                mesh,
                &adjacency,
                used_edges,
                @intCast(vertex_index),
                edge_index,
                &curves,
            );
        }
    }

    for (mesh.edges.items, 0..) |_, edge_index| {
        if (used_edges[edge_index]) continue;
        try appendCyclicCurveFromEdge(
            allocator,
            mesh,
            &adjacency,
            used_edges,
            @intCast(edge_index),
            &curves,
        );
    }

    return curves;
}

fn buildEdgeAdjacency(
    allocator: std.mem.Allocator,
    mesh: *const mesh_mod.Mesh,
) !EdgeAdjacency {
    const vertex_count = mesh.positions.items.len;
    const edge_count = mesh.edges.items.len;

    var offsets = try allocator.alloc(u32, vertex_count + 1);
    errdefer allocator.free(offsets);
    @memset(offsets, 0);

    for (mesh.edges.items) |edge| {
        if (edge.a >= vertex_count or edge.b >= vertex_count) {
            return error.InvalidTopology;
        }
        if (edge.a == edge.b) {
            return error.InvalidTopology;
        }
        offsets[edge.a + 1] += 1;
        offsets[edge.b + 1] += 1;
    }

    for (1..offsets.len) |index| {
        offsets[index] += offsets[index - 1];
    }

    var incident_edges = try allocator.alloc(u32, edge_count * 2);
    errdefer allocator.free(incident_edges);

    var write_cursor = try allocator.alloc(u32, vertex_count);
    defer allocator.free(write_cursor);
    @memcpy(write_cursor, offsets[0..vertex_count]);

    for (mesh.edges.items, 0..) |edge, edge_index| {
        const edge_id: u32 = @intCast(edge_index);
        incident_edges[write_cursor[edge.a]] = edge_id;
        write_cursor[edge.a] += 1;
        incident_edges[write_cursor[edge.b]] = edge_id;
        write_cursor[edge.b] += 1;
    }

    return .{
        .allocator = allocator,
        .offsets = offsets,
        .incident_edges = incident_edges,
    };
}

fn appendOpenCurveFromEdge(
    allocator: std.mem.Allocator,
    mesh: *const mesh_mod.Mesh,
    adjacency: *const EdgeAdjacency,
    used_edges: []bool,
    start_vertex: u32,
    start_edge: u32,
    curves: *curves_mod.CurvesGeometry,
) !void {
    var vertex_indices: std.ArrayList(u32) = .empty;
    defer vertex_indices.deinit(allocator);

    try vertex_indices.append(allocator, start_vertex);

    var current_vertex = start_vertex;
    var current_edge = start_edge;
    while (true) {
        used_edges[current_edge] = true;

        const next_vertex = otherVertex(mesh.edges.items[current_edge], current_vertex);
        try vertex_indices.append(allocator, next_vertex);

        const next_edge = nextUnusedIncidentEdge(adjacency, used_edges, next_vertex, current_edge) orelse break;
        current_vertex = next_vertex;
        current_edge = next_edge;
    }

    try appendCurveFromVertexIndices(allocator, mesh, vertex_indices.items, false, curves);
}

fn appendCyclicCurveFromEdge(
    allocator: std.mem.Allocator,
    mesh: *const mesh_mod.Mesh,
    adjacency: *const EdgeAdjacency,
    used_edges: []bool,
    start_edge: u32,
    curves: *curves_mod.CurvesGeometry,
) !void {
    const start_vertex = mesh.edges.items[start_edge].a;

    var vertex_indices: std.ArrayList(u32) = .empty;
    defer vertex_indices.deinit(allocator);

    try vertex_indices.append(allocator, start_vertex);

    var current_vertex = start_vertex;
    var current_edge = start_edge;
    while (true) {
        used_edges[current_edge] = true;

        const next_vertex = otherVertex(mesh.edges.items[current_edge], current_vertex);
        if (next_vertex == start_vertex) {
            break;
        }

        try vertex_indices.append(allocator, next_vertex);

        const next_edge = nextUnusedIncidentEdge(adjacency, used_edges, next_vertex, current_edge) orelse return error.InvalidTopology;
        current_vertex = next_vertex;
        current_edge = next_edge;
    }

    try appendCurveFromVertexIndices(allocator, mesh, vertex_indices.items, true, curves);
}

fn appendCurveFromVertexIndices(
    allocator: std.mem.Allocator,
    mesh: *const mesh_mod.Mesh,
    vertex_indices: []const u32,
    is_cyclic: bool,
    curves: *curves_mod.CurvesGeometry,
) !void {
    const positions = try allocator.alloc(math.Vec3, vertex_indices.len);
    defer allocator.free(positions);

    const test_indices = try allocator.alloc(i32, vertex_indices.len);
    defer allocator.free(test_indices);

    for (vertex_indices, 0..) |vertex_index, i| {
        positions[i] = mesh.positions.items[vertex_index];
        test_indices[i] = @intCast(vertex_index);
    }

    try curves.appendCurve(positions, is_cyclic, test_indices);
}

fn nextUnusedIncidentEdge(
    adjacency: *const EdgeAdjacency,
    used_edges: []bool,
    vertex_index: u32,
    current_edge: u32,
) ?u32 {
    const incident = adjacency.incidentRange(vertex_index);
    if (incident.len() != 2) return null;

    var next_edge: ?u32 = null;
    for (incident.start..incident.end) |slot| {
        const edge_index = adjacency.incident_edges[slot];
        if (edge_index == current_edge or used_edges[edge_index]) continue;
        if (next_edge != null) return null;
        next_edge = edge_index;
    }
    return next_edge;
}

fn otherVertex(edge: mesh_mod.Edge, vertex_index: u32) u32 {
    std.debug.assert(edge.a == vertex_index or edge.b == vertex_index);
    return if (edge.a == vertex_index) edge.b else edge.a;
}

test "mesh edges to curves converts an open chain" {
    var mesh = try mesh_mod.Mesh.init(std.testing.allocator);
    defer mesh.deinit();

    _ = try mesh.appendVertex(.{ .x = 0, .y = 0, .z = 0 });
    _ = try mesh.appendVertex(.{ .x = 1, .y = 0, .z = 0 });
    _ = try mesh.appendVertex(.{ .x = 2, .y = 0, .z = 0 });
    try mesh.appendEdge(0, 1);
    try mesh.appendEdge(1, 2);

    var curves = try meshEdgesToCurves(std.testing.allocator, &mesh);
    defer curves.deinit();

    try std.testing.expectEqual(@as(usize, 1), curves.curvesNum());
    try std.testing.expectEqual(@as(usize, 3), curves.pointsNum());
    try std.testing.expectEqualSlices(u32, &[_]u32{ 0, 3 }, curves.offsets());
    try std.testing.expectEqualSlices(bool, &[_]bool{false}, curves.cyclicFlags());
    try std.testing.expectEqualSlices(i32, &[_]i32{ 0, 1, 2 }, curves.testIndices());
    try std.testing.expect(math.vec3ApproxEq(curves.positions.items[0], .{ .x = 0, .y = 0, .z = 0 }, 0.0001));
    try std.testing.expect(math.vec3ApproxEq(curves.positions.items[2], .{ .x = 2, .y = 0, .z = 0 }, 0.0001));
}

test "mesh edges to curves keeps disconnected chains separate" {
    var mesh = try mesh_mod.Mesh.init(std.testing.allocator);
    defer mesh.deinit();

    _ = try mesh.appendVertex(.{ .x = 0, .y = 0, .z = 0 });
    _ = try mesh.appendVertex(.{ .x = 1, .y = 0, .z = 0 });
    _ = try mesh.appendVertex(.{ .x = 2, .y = 0, .z = 0 });
    _ = try mesh.appendVertex(.{ .x = 10, .y = 0, .z = 0 });
    _ = try mesh.appendVertex(.{ .x = 11, .y = 0, .z = 0 });
    try mesh.appendEdge(0, 1);
    try mesh.appendEdge(1, 2);
    try mesh.appendEdge(3, 4);

    var curves = try meshEdgesToCurves(std.testing.allocator, &mesh);
    defer curves.deinit();

    try std.testing.expectEqual(@as(usize, 2), curves.curvesNum());
    try std.testing.expectEqual(@as(usize, 5), curves.pointsNum());
    try std.testing.expectEqualSlices(u32, &[_]u32{ 0, 3, 5 }, curves.offsets());
    try std.testing.expectEqualSlices(bool, &[_]bool{ false, false }, curves.cyclicFlags());
}

test "mesh edges to curves closes cyclic loops" {
    var mesh = try mesh_mod.Mesh.init(std.testing.allocator);
    defer mesh.deinit();

    _ = try mesh.appendVertex(.{ .x = 0, .y = 0, .z = 0 });
    _ = try mesh.appendVertex(.{ .x = 1, .y = 0, .z = 0 });
    _ = try mesh.appendVertex(.{ .x = 1, .y = 1, .z = 0 });
    _ = try mesh.appendVertex(.{ .x = 0, .y = 1, .z = 0 });
    try mesh.appendEdge(0, 1);
    try mesh.appendEdge(1, 2);
    try mesh.appendEdge(2, 3);
    try mesh.appendEdge(3, 0);

    var curves = try meshEdgesToCurves(std.testing.allocator, &mesh);
    defer curves.deinit();

    try std.testing.expectEqual(@as(usize, 1), curves.curvesNum());
    try std.testing.expectEqual(@as(usize, 4), curves.pointsNum());
    try std.testing.expectEqualSlices(u32, &[_]u32{ 0, 4 }, curves.offsets());
    try std.testing.expectEqualSlices(bool, &[_]bool{true}, curves.cyclicFlags());
    try std.testing.expectEqualSlices(i32, &[_]i32{ 0, 1, 2, 3 }, curves.testIndices());
}

test "mesh edges to curves returns an empty result for empty edge sets" {
    var mesh = try mesh_mod.Mesh.init(std.testing.allocator);
    defer mesh.deinit();

    _ = try mesh.appendVertex(.{ .x = 3, .y = 4, .z = 5 });

    var curves = try meshEdgesToCurves(std.testing.allocator, &mesh);
    defer curves.deinit();

    try std.testing.expectEqual(@as(usize, 0), curves.curvesNum());
    try std.testing.expectEqual(@as(usize, 0), curves.pointsNum());
    try std.testing.expectEqualSlices(u32, &[_]u32{0}, curves.offsets());
}

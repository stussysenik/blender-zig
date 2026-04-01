const std = @import("std");
const math = @import("../math.zig");
const mesh_mod = @import("../mesh.zig");

pub const BevelEdgeOptions = struct {
    width: f32 = 0.12,
};

const FaceEdgeUse = struct {
    face_index: usize,
    local_index: usize,
};

const EdgeUses = struct {
    count: u8 = 0,
    uses: [3]FaceEdgeUse = undefined,
};

const BevelPair = struct {
    face_a: usize,
    face_b: usize,
    edge_key: u64,
    use_a: FaceEdgeUse,
    use_b: FaceEdgeUse,
};

const FaceCutGeometry = struct {
    face_index: usize,
    local_index: usize,
    start_vertex: u32,
    end_vertex: u32,
    start_position: math.Vec3,
    end_position: math.Vec3,
    start_uv: math.Vec2,
    end_uv: math.Vec2,
};

const FaceCut = struct {
    face_index: usize,
    local_index: usize,
    start_vertex: u32,
    end_vertex: u32,
    start_index: u32,
    end_index: u32,
    start_uv: math.Vec2,
    end_uv: math.Vec2,
};

const VertexCut = struct {
    index: u32,
    uv: math.Vec2,
};

// This is the first explicit bevel-like growth slice for the current mesh model:
// bevel exactly one selected shared manifold edge, rewrite only the two incident face
// loops, and bridge them with one quad strip. It intentionally rejects full bevel
// networks and miter handling until the repo has stronger selection/persistence state.
pub fn bevelEdges(
    allocator: std.mem.Allocator,
    mesh: *const mesh_mod.Mesh,
    edges_to_bevel: []const mesh_mod.Edge,
    options: BevelEdgeOptions,
) !mesh_mod.Mesh {
    if (options.width <= 0.0) return error.InvalidBevelWidth;

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
    for (edges_to_bevel) |edge| {
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

    var pairs_by_primary = std.AutoHashMap(usize, BevelPair).init(allocator);
    defer pairs_by_primary.deinit();

    var processed_keys = std.AutoHashMap(u64, void).init(allocator);
    defer processed_keys.deinit();

    for (edges_to_bevel) |edge| {
        const edge_key = packUndirectedEdge(edge.a, edge.b);
        if (processed_keys.contains(edge_key)) continue;
        try processed_keys.put(edge_key, {});

        const edge_uses = selected_edge_uses.get(edge_key) orelse continue;
        if (edge_uses.count != 2) continue;

        const raw_a = edge_uses.uses[0];
        const raw_b = edge_uses.uses[1];
        if (raw_a.face_index == raw_b.face_index) continue;
        if (face_reserved[raw_a.face_index] or face_reserved[raw_b.face_index]) continue;

        face_reserved[raw_a.face_index] = true;
        face_reserved[raw_b.face_index] = true;

        if (raw_a.face_index < raw_b.face_index) {
            try pairs_by_primary.put(raw_a.face_index, .{
                .face_a = raw_a.face_index,
                .face_b = raw_b.face_index,
                .edge_key = edge_key,
                .use_a = raw_a,
                .use_b = raw_b,
            });
        } else {
            try pairs_by_primary.put(raw_b.face_index, .{
                .face_a = raw_b.face_index,
                .face_b = raw_a.face_index,
                .edge_key = edge_key,
                .use_a = raw_b,
                .use_b = raw_a,
            });
        }
    }

    const face_written = try allocator.alloc(bool, mesh.faceCount());
    defer allocator.free(face_written);
    @memset(face_written, false);

    for (0..mesh.faceCount()) |face_index| {
        if (face_written[face_index]) continue;

        if (pairs_by_primary.get(face_index)) |pair| {
            if (try appendBeveledPair(allocator, mesh, pair, options.width, &result)) {
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

fn appendBeveledPair(
    allocator: std.mem.Allocator,
    mesh: *const mesh_mod.Mesh,
    pair: BevelPair,
    width: f32,
    result: *mesh_mod.Mesh,
) !bool {
    const edge = unpackUndirectedEdge(pair.edge_key);
    const cut_geom_a = try buildFaceCutGeometry(mesh, pair.use_a, width);
    const cut_geom_b = try buildFaceCutGeometry(mesh, pair.use_b, width);

    const cut_a = try appendFaceCut(result, cut_geom_a);
    const cut_b = try appendFaceCut(result, cut_geom_b);

    try appendRewrittenFace(allocator, mesh, cut_a, result);
    try appendRewrittenFace(allocator, mesh, cut_b, result);

    const a0 = cutForVertex(cut_a, edge.a) orelse return false;
    const a1 = cutForVertex(cut_a, edge.b) orelse return false;
    const b0 = cutForVertex(cut_b, edge.a) orelse return false;
    const b1 = cutForVertex(cut_b, edge.b) orelse return false;

    const bevel_face = [_]u32{
        a0.index,
        a1.index,
        b1.index,
        b0.index,
    };

    if (mesh.hasCornerUvs()) {
        const bevel_uvs = [_]math.Vec2{
            a0.uv,
            a1.uv,
            b1.uv,
            b0.uv,
        };
        try result.appendFace(&bevel_face, &bevel_uvs);
    } else {
        try result.appendFace(&bevel_face, null);
    }

    return true;
}

fn buildFaceCutGeometry(
    mesh: *const mesh_mod.Mesh,
    use: FaceEdgeUse,
    width: f32,
) !FaceCutGeometry {
    const range = mesh.faceVertexRange(use.face_index);
    const face_verts = mesh.corner_verts.items[range.start..range.end];
    const face_uvs = if (mesh.hasCornerUvs()) mesh.corner_uvs.items[range.start..range.end] else &[_]math.Vec2{};
    if (face_verts.len < 3) return error.InvalidFace;

    const start_index = use.local_index;
    const end_index = (use.local_index + 1) % face_verts.len;
    const prev_index = (use.local_index + face_verts.len - 1) % face_verts.len;
    const next_index = (use.local_index + 2) % face_verts.len;

    const start_vertex = face_verts[start_index];
    const end_vertex = face_verts[end_index];
    const prev_vertex = face_verts[prev_index];
    const next_vertex = face_verts[next_index];

    const start_position = mesh.positions.items[start_vertex];
    const end_position = mesh.positions.items[end_vertex];
    const prev_position = mesh.positions.items[prev_vertex];
    const next_position = mesh.positions.items[next_vertex];

    const start_factor = clampedCutFactor(start_position, prev_position, width);
    const end_factor = clampedCutFactor(end_position, next_position, width);

    return .{
        .face_index = use.face_index,
        .local_index = use.local_index,
        .start_vertex = start_vertex,
        .end_vertex = end_vertex,
        .start_position = lerpVec3(start_position, prev_position, start_factor),
        .end_position = lerpVec3(end_position, next_position, end_factor),
        .start_uv = if (mesh.hasCornerUvs()) lerpVec2(face_uvs[start_index], face_uvs[prev_index], start_factor) else math.Vec2.init(0, 0),
        .end_uv = if (mesh.hasCornerUvs()) lerpVec2(face_uvs[end_index], face_uvs[next_index], end_factor) else math.Vec2.init(0, 0),
    };
}

fn appendFaceCut(result: *mesh_mod.Mesh, geometry: FaceCutGeometry) !FaceCut {
    return .{
        .face_index = geometry.face_index,
        .local_index = geometry.local_index,
        .start_vertex = geometry.start_vertex,
        .end_vertex = geometry.end_vertex,
        .start_index = try result.appendVertex(geometry.start_position),
        .end_index = try result.appendVertex(geometry.end_position),
        .start_uv = geometry.start_uv,
        .end_uv = geometry.end_uv,
    };
}

fn appendRewrittenFace(
    allocator: std.mem.Allocator,
    mesh: *const mesh_mod.Mesh,
    cut: FaceCut,
    result: *mesh_mod.Mesh,
) !void {
    const range = mesh.faceVertexRange(cut.face_index);
    const face_verts = mesh.corner_verts.items[range.start..range.end];
    const face_uvs = if (mesh.hasCornerUvs()) mesh.corner_uvs.items[range.start..range.end] else &[_]math.Vec2{};

    var rewritten_verts = std.ArrayList(u32).empty;
    defer rewritten_verts.deinit(allocator);
    var rewritten_uvs = std.ArrayList(math.Vec2).empty;
    defer rewritten_uvs.deinit(allocator);

    try rewritten_verts.append(allocator, cut.start_index);
    try rewritten_verts.append(allocator, cut.end_index);
    if (mesh.hasCornerUvs()) {
        try rewritten_uvs.append(allocator, cut.start_uv);
        try rewritten_uvs.append(allocator, cut.end_uv);
    }

    for (2..face_verts.len) |offset| {
        const vertex_index = (cut.local_index + offset) % face_verts.len;
        try rewritten_verts.append(allocator, face_verts[vertex_index]);
        if (mesh.hasCornerUvs()) {
            try rewritten_uvs.append(allocator, face_uvs[vertex_index]);
        }
    }

    const maybe_uvs: ?[]const math.Vec2 = if (mesh.hasCornerUvs()) rewritten_uvs.items else null;
    try result.appendFace(rewritten_verts.items, maybe_uvs);
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

fn cutForVertex(cut: FaceCut, vertex: u32) ?VertexCut {
    if (vertex == cut.start_vertex) {
        return .{ .index = cut.start_index, .uv = cut.start_uv };
    }
    if (vertex == cut.end_vertex) {
        return .{ .index = cut.end_index, .uv = cut.end_uv };
    }
    return null;
}

fn clampedCutFactor(from: math.Vec3, toward: math.Vec3, width: f32) f32 {
    const length = toward.sub(from).length();
    if (length <= 1e-6) return 0.0;
    return @min(width / length, 0.45);
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

fn unpackUndirectedEdge(key: u64) mesh_mod.Edge {
    return .{
        .a = @truncate(key),
        .b = @truncate(key >> 32),
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

fn createHingeMesh(allocator: std.mem.Allocator) !mesh_mod.Mesh {
    var mesh = try mesh_mod.Mesh.init(allocator);
    errdefer mesh.deinit();

    _ = try mesh.appendVertex(.{ .x = 0, .y = 0, .z = 0 });
    _ = try mesh.appendVertex(.{ .x = 1, .y = 0, .z = 0 });
    _ = try mesh.appendVertex(.{ .x = 1, .y = 1, .z = 0 });
    _ = try mesh.appendVertex(.{ .x = 0, .y = 1, .z = 0 });
    _ = try mesh.appendVertex(.{ .x = 1, .y = 1, .z = 1 });
    _ = try mesh.appendVertex(.{ .x = 1, .y = 0, .z = 1 });
    _ = try mesh.appendVertex(.{ .x = 3, .y = 0, .z = 0 });
    _ = try mesh.appendVertex(.{ .x = 4, .y = 0, .z = 0 });

    const face_uvs = [_]math.Vec2{
        .{ .x = 0, .y = 0 },
        .{ .x = 1, .y = 0 },
        .{ .x = 1, .y = 1 },
        .{ .x = 0, .y = 1 },
    };
    try mesh.appendFace(&[_]u32{ 0, 1, 2, 3 }, &face_uvs);
    try mesh.appendFace(&[_]u32{ 2, 1, 5, 4 }, &face_uvs);
    try mesh.rebuildEdgesFromFaces();
    return mesh;
}

fn createHingeMeshWithLooseEdge(allocator: std.mem.Allocator) !mesh_mod.Mesh {
    var mesh = try createHingeMesh(allocator);
    errdefer mesh.deinit();

    _ = try mesh.appendVertex(.{ .x = 3, .y = 0, .z = 0 });
    _ = try mesh.appendVertex(.{ .x = 4, .y = 0, .z = 0 });
    try mesh.appendEdge(6, 7);
    return mesh;
}

test "edge bevel replaces one shared hinge edge with a quad strip" {
    var mesh = try createHingeMesh(std.testing.allocator);
    defer mesh.deinit();

    var beveled = try bevelEdges(std.testing.allocator, &mesh, &[_]mesh_mod.Edge{
        .{ .a = 1, .b = 2 },
    }, .{ .width = 0.18 });
    defer beveled.deinit();

    try std.testing.expectEqual(@as(usize, 12), beveled.vertexCount());
    try std.testing.expectEqual(@as(usize, 3), beveled.faceCount());
    try std.testing.expectEqual(@as(usize, 10), beveled.edges.items.len);
    try std.testing.expect(beveled.hasCornerUvs());
    try std.testing.expectEqual(@as(usize, 12), beveled.corner_uvs.items.len);
    try std.testing.expect(!hasEdge(&beveled, 1, 2));
    try std.testing.expect(hasEdge(&beveled, 8, 9));
    try std.testing.expect(hasEdge(&beveled, 10, 11));
}

test "edge bevel preserves loose edges outside the beveled faces" {
    var mesh = try createHingeMeshWithLooseEdge(std.testing.allocator);
    defer mesh.deinit();

    var beveled = try bevelEdges(std.testing.allocator, &mesh, &[_]mesh_mod.Edge{
        .{ .a = 1, .b = 2 },
    }, .{ .width = 0.18 });
    defer beveled.deinit();

    try std.testing.expect(hasEdge(&beveled, 6, 7));
}

test "edge bevel no-ops when the selected edge is not manifold" {
    var mesh = try createHingeMesh(std.testing.allocator);
    defer mesh.deinit();

    var beveled = try bevelEdges(std.testing.allocator, &mesh, &[_]mesh_mod.Edge{
        .{ .a = 0, .b = 1 },
    }, .{ .width = 0.18 });
    defer beveled.deinit();

    try std.testing.expectEqual(mesh.vertexCount(), beveled.vertexCount());
    try std.testing.expectEqual(mesh.faceCount(), beveled.faceCount());
    try std.testing.expectEqual(mesh.edges.items.len, beveled.edges.items.len);
}

test "edge bevel rejects non-positive widths" {
    var mesh = try createHingeMesh(std.testing.allocator);
    defer mesh.deinit();

    try std.testing.expectError(error.InvalidBevelWidth, bevelEdges(std.testing.allocator, &mesh, &[_]mesh_mod.Edge{
        .{ .a = 1, .b = 2 },
    }, .{ .width = 0.0 }));
}

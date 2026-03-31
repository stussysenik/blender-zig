const std = @import("std");
const math = @import("../../math.zig");
const mesh_mod = @import("../../mesh.zig");

pub fn createCylinderMesh(
    allocator: std.mem.Allocator,
    radius: f32,
    height: f32,
    segments: usize,
    top_cap: bool,
    bottom_cap: bool,
    with_uvs: bool,
) !mesh_mod.Mesh {
    if (radius <= 0.0 or height <= 0.0 or segments < 3) return error.InvalidResolution;

    var mesh = try mesh_mod.Mesh.init(allocator);
    errdefer mesh.deinit();

    const half_height = height * 0.5;
    const bottom_z = -half_height;
    const top_z = half_height;

    const bottom_ring = try createRingVertices(allocator, &mesh, radius, bottom_z, segments);
    defer allocator.free(bottom_ring);
    const top_ring = try createRingVertices(allocator, &mesh, radius, top_z, segments);
    defer allocator.free(top_ring);

    const top_center = if (top_cap) try mesh.appendVertex(.{ .x = 0, .y = 0, .z = top_z }) else null;
    const bottom_center = if (bottom_cap) try mesh.appendVertex(.{ .x = 0, .y = 0, .z = bottom_z }) else null;

    for (0..segments) |segment| {
        const next = (segment + 1) % segments;
        const side_verts = [_]u32{
            bottom_ring[segment],
            bottom_ring[next],
            top_ring[next],
            top_ring[segment],
        };
        if (with_uvs) {
            const uv0 = segmentT(segment, segments);
            const uv1 = segmentT(next, segments);
            const uvs = [_]math.Vec2{
                .{ .x = uv0, .y = 0.0 },
                .{ .x = uv1, .y = 0.0 },
                .{ .x = uv1, .y = 1.0 },
                .{ .x = uv0, .y = 1.0 },
            };
            try mesh.appendFace(&side_verts, &uvs);
        } else {
            try mesh.appendFace(&side_verts, null);
        }
    }

    if (top_cap) {
        try appendCap(mesh, top_center.?, top_ring, segments, true, with_uvs);
    }
    if (bottom_cap) {
        try appendCap(mesh, bottom_center.?, bottom_ring, segments, false, with_uvs);
    }

    try mesh.rebuildEdgesFromFaces();
    return mesh;
}

pub fn createConeMesh(
    allocator: std.mem.Allocator,
    radius: f32,
    height: f32,
    segments: usize,
    base_cap: bool,
    with_uvs: bool,
) !mesh_mod.Mesh {
    if (radius <= 0.0 or height <= 0.0 or segments < 3) return error.InvalidResolution;

    var mesh = try mesh_mod.Mesh.init(allocator);
    errdefer mesh.deinit();

    const half_height = height * 0.5;
    const tip_z = half_height;
    const base_z = -half_height;

    const base_ring = try createRingVertices(allocator, &mesh, radius, base_z, segments);
    defer allocator.free(base_ring);
    const tip_index = try mesh.appendVertex(.{ .x = 0, .y = 0, .z = tip_z });
    const base_center = if (base_cap) try mesh.appendVertex(.{ .x = 0, .y = 0, .z = base_z }) else null;

    for (0..segments) |segment| {
        const next = (segment + 1) % segments;
        const side_verts = [_]u32{
            tip_index,
            base_ring[segment],
            base_ring[next],
        };
        if (with_uvs) {
            const uv0 = segmentT(segment, segments);
            const uv1 = segmentT(next, segments);
            const uvs = [_]math.Vec2{
                .{ .x = 0.5, .y = 1.0 },
                .{ .x = uv0, .y = 0.0 },
                .{ .x = uv1, .y = 0.0 },
            };
            try mesh.appendFace(&side_verts, &uvs);
        } else {
            try mesh.appendFace(&side_verts, null);
        }
    }

    if (base_cap) {
        try appendCap(mesh, base_center.?, base_ring, segments, false, with_uvs);
    }

    try mesh.rebuildEdgesFromFaces();
    return mesh;
}

fn createRingVertices(
    allocator: std.mem.Allocator,
    mesh: *mesh_mod.Mesh,
    radius: f32,
    z: f32,
    segments: usize,
) ![]u32 {
    const indices = try allocator.alloc(u32, segments);
    errdefer allocator.free(indices);

    for (0..segments) |segment| {
        const angle = angleForSegment(segment, segments);
        indices[segment] = try mesh.appendVertex(.{
            .x = @cos(angle) * radius,
            .y = @sin(angle) * radius,
            .z = z,
        });
    }
    return indices;
}

fn appendCap(
    mesh: *mesh_mod.Mesh,
    center: u32,
    ring: []const u32,
    segments: usize,
    is_top: bool,
    with_uvs: bool,
) !void {
    for (0..segments) |segment| {
        const next = (segment + 1) % segments;
        const verts = if (is_top)
            [_]u32{ center, ring[segment], ring[next] }
        else
            [_]u32{ center, ring[next], ring[segment] };
        if (with_uvs) {
            const uvs = if (is_top)
                [_]math.Vec2{
                    .{ .x = 0.5, .y = 0.5 },
                    .{ .x = capU(segment, segments).x, .y = capU(segment, segments).y },
                    .{ .x = capU(next, segments).x, .y = capU(next, segments).y },
                }
            else
                [_]math.Vec2{
                    .{ .x = 0.5, .y = 0.5 },
                    .{ .x = capU(next, segments).x, .y = capU(next, segments).y },
                    .{ .x = capU(segment, segments).x, .y = capU(segment, segments).y },
                };
            try mesh.appendFace(&verts, &uvs);
        } else {
            try mesh.appendFace(&verts, null);
        }
    }
}

fn capU(segment: usize, segments: usize) math.Vec2 {
    const angle = angleForSegment(segment, segments);
    return .{
        .x = 0.5 + 0.5 * @cos(angle),
        .y = 0.5 + 0.5 * @sin(angle),
    };
}

fn angleForSegment(segment: usize, segments: usize) f32 {
    return (2.0 * std.math.pi) * segmentT(segment, segments);
}

fn segmentT(segment: usize, segments: usize) f32 {
    return @as(f32, @floatFromInt(segment)) / @as(f32, @floatFromInt(segments));
}

test "cylinder mesh creates an open tube" {
    var mesh = try createCylinderMesh(std.testing.allocator, 2.0, 4.0, 4, false, false, false);
    defer mesh.deinit();

    try std.testing.expectEqual(@as(usize, 8), mesh.positions.items.len);
    try std.testing.expectEqual(@as(usize, 4), mesh.faceCount());
    try std.testing.expectEqual(@as(usize, 12), mesh.edges.items.len);
    try std.testing.expect(math.vec3ApproxEq(mesh.positions.items[0], math.Vec3.init(2, 0, -2), 0.0001));
    try std.testing.expect(math.vec3ApproxEq(mesh.positions.items[4], math.Vec3.init(2, 0, 2), 0.0001));
}

test "cylinder mesh adds caps and uv corners" {
    var mesh = try createCylinderMesh(std.testing.allocator, 1.5, 3.0, 4, true, true, true);
    defer mesh.deinit();

    try std.testing.expectEqual(@as(usize, 10), mesh.positions.items.len);
    try std.testing.expectEqual(@as(usize, 12), mesh.faceCount());
    try std.testing.expectEqual(@as(usize, 20), mesh.edges.items.len);
    try std.testing.expect(mesh.hasCornerUvs());
    try std.testing.expect(math.vec3ApproxEq(mesh.positions.items[8], math.Vec3.init(0, 0, 1.5), 0.0001));
    try std.testing.expect(math.vec3ApproxEq(mesh.positions.items[9], math.Vec3.init(0, 0, -1.5), 0.0001));
}

test "cone mesh creates a capped base and triangle fan sides" {
    var mesh = try createConeMesh(std.testing.allocator, 2.0, 4.0, 6, true, true);
    defer mesh.deinit();

    try std.testing.expectEqual(@as(usize, 8), mesh.positions.items.len);
    try std.testing.expectEqual(@as(usize, 12), mesh.faceCount());
    try std.testing.expectEqual(@as(usize, 18), mesh.edges.items.len);
    try std.testing.expect(mesh.hasCornerUvs());
    try std.testing.expect(math.vec3ApproxEq(mesh.positions.items[6], math.Vec3.init(0, 0, 2), 0.0001));
    try std.testing.expect(math.vec3ApproxEq(mesh.positions.items[7], math.Vec3.init(0, 0, -2), 0.0001));
}

test "cone mesh can omit the base cap" {
    var mesh = try createConeMesh(std.testing.allocator, 1.0, 2.0, 5, false, false);
    defer mesh.deinit();

    try std.testing.expectEqual(@as(usize, 6), mesh.positions.items.len);
    try std.testing.expectEqual(@as(usize, 5), mesh.faceCount());
    try std.testing.expectEqual(@as(usize, 10), mesh.edges.items.len);
}

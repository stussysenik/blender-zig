const std = @import("std");
const math = @import("../../math.zig");
const mesh_mod = @import("../../mesh.zig");

pub fn createUvSphereMesh(
    allocator: std.mem.Allocator,
    radius: f32,
    segments: usize,
    rings: usize,
    with_uvs: bool,
) !mesh_mod.Mesh {
    if (segments < 3 or rings < 2) return error.InvalidResolution;

    var mesh = try mesh_mod.Mesh.init(allocator);
    errdefer mesh.deinit();

    const pi = std.math.pi;
    const delta_theta = pi / @as(f32, @floatFromInt(rings));
    const delta_phi = (2.0 * pi) / @as(f32, @floatFromInt(segments));

    _ = try mesh.appendVertex(.{ .x = 0, .y = 0, .z = radius });

    for (1..rings) |ring| {
        const theta = @as(f32, @floatFromInt(ring)) * delta_theta;
        const sin_theta = @sin(theta);
        const z = @cos(theta) * radius;
        for (0..segments) |segment| {
            const phi = @as(f32, @floatFromInt(segment)) * delta_phi;
            _ = try mesh.appendVertex(.{
                .x = sin_theta * @cos(phi) * radius,
                .y = sin_theta * @sin(phi) * radius,
                .z = z,
            });
        }
    }

    const bottom_index = try mesh.appendVertex(.{ .x = 0, .y = 0, .z = -radius });
    const first_ring_start: u32 = 1;
    const dy = 1.0 / @as(f32, @floatFromInt(rings));

    for (0..segments) |segment| {
        const current: u32 = @intCast(segment);
        const next: u32 = @intCast((segment + 1) % segments);
        const verts = [_]u32{
            0,
            first_ring_start + current,
            first_ring_start + next,
        };
        if (with_uvs) {
            const uvs = [_]math.Vec2{
                .{ .x = (@as(f32, @floatFromInt(segment)) + 0.5) / @as(f32, @floatFromInt(segments)), .y = 0 },
                .{ .x = @as(f32, @floatFromInt(segment)) / @as(f32, @floatFromInt(segments)), .y = dy },
                .{ .x = @as(f32, @floatFromInt(segment + 1)) / @as(f32, @floatFromInt(segments)), .y = dy },
            };
            try mesh.appendFace(&verts, &uvs);
        } else {
            try mesh.appendFace(&verts, null);
        }
    }

    const inner_ring_count = rings - 1;
    if (inner_ring_count > 1) {
        for (0..inner_ring_count - 1) |ring| {
            const ring_start = first_ring_start + @as(u32, @intCast(ring * segments));
            const next_ring_start = ring_start + @as(u32, @intCast(segments));
            for (0..segments) |segment| {
                const current: u32 = @intCast(segment);
                const next: u32 = @intCast((segment + 1) % segments);
                const verts = [_]u32{
                    ring_start + current,
                    next_ring_start + current,
                    next_ring_start + next,
                    ring_start + next,
                };
                if (with_uvs) {
                    const ring_v = @as(f32, @floatFromInt(ring + 1)) / @as(f32, @floatFromInt(rings));
                    const next_ring_v = @as(f32, @floatFromInt(ring + 2)) / @as(f32, @floatFromInt(rings));
                    const uvs = [_]math.Vec2{
                        .{ .x = @as(f32, @floatFromInt(segment)) / @as(f32, @floatFromInt(segments)), .y = ring_v },
                        .{ .x = @as(f32, @floatFromInt(segment)) / @as(f32, @floatFromInt(segments)), .y = next_ring_v },
                        .{ .x = @as(f32, @floatFromInt(segment + 1)) / @as(f32, @floatFromInt(segments)), .y = next_ring_v },
                        .{ .x = @as(f32, @floatFromInt(segment + 1)) / @as(f32, @floatFromInt(segments)), .y = ring_v },
                    };
                    try mesh.appendFace(&verts, &uvs);
                } else {
                    try mesh.appendFace(&verts, null);
                }
            }
        }
    }

    const last_ring_start = bottom_index - @as(u32, @intCast(segments));
    for (0..segments) |segment| {
        const current: u32 = @intCast(segment);
        const next: u32 = @intCast((segment + 1) % segments);
        const verts = [_]u32{
            bottom_index,
            last_ring_start + next,
            last_ring_start + current,
        };
        if (with_uvs) {
            const uvs = [_]math.Vec2{
                .{ .x = (@as(f32, @floatFromInt(segment)) + 0.5) / @as(f32, @floatFromInt(segments)), .y = 1 },
                .{ .x = @as(f32, @floatFromInt(segment + 1)) / @as(f32, @floatFromInt(segments)), .y = 1 - dy },
                .{ .x = @as(f32, @floatFromInt(segment)) / @as(f32, @floatFromInt(segments)), .y = 1 - dy },
            };
            try mesh.appendFace(&verts, &uvs);
        } else {
            try mesh.appendFace(&verts, null);
        }
    }

    try mesh.rebuildEdgesFromFaces();
    return mesh;
}

test "uv sphere follows Blender-inspired counts" {
    var mesh = try createUvSphereMesh(std.testing.allocator, 2.0, 8, 4, true);
    defer mesh.deinit();

    try std.testing.expectEqual(@as(usize, 26), mesh.positions.items.len);
    try std.testing.expectEqual(@as(usize, 32), mesh.faceCount());
    try std.testing.expectEqual(@as(usize, 56), mesh.edges.items.len);
    try std.testing.expect(mesh.hasCornerUvs());
}

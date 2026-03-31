const std = @import("std");
const math = @import("../../math.zig");
const mesh_mod = @import("../../mesh.zig");

pub fn createGridMesh(
    allocator: std.mem.Allocator,
    verts_x: usize,
    verts_y: usize,
    size_x: f32,
    size_y: f32,
    with_uvs: bool,
) !mesh_mod.Mesh {
    if (verts_x == 0 or verts_y == 0) return error.InvalidResolution;

    var mesh = try mesh_mod.Mesh.init(allocator);
    errdefer mesh.deinit();

    const edges_x = verts_x -| 1;
    const edges_y = verts_y -| 1;
    const dx = if (edges_x == 0) 0.0 else size_x / @as(f32, @floatFromInt(edges_x));
    const dy = if (edges_y == 0) 0.0 else size_y / @as(f32, @floatFromInt(edges_y));
    const x_shift = @as(f32, @floatFromInt(edges_x)) / 2.0;
    const y_shift = @as(f32, @floatFromInt(edges_y)) / 2.0;

    for (0..verts_x) |x| {
        for (0..verts_y) |y| {
            const xf: f32 = @floatFromInt(x);
            const yf: f32 = @floatFromInt(y);
            _ = try mesh.appendVertex(.{
                .x = (xf - x_shift) * dx,
                .y = (yf - y_shift) * dy,
                .z = 0,
            });
        }
    }

    if (edges_x > 0 and edges_y > 0) {
        for (0..edges_x) |x| {
            for (0..edges_y) |y| {
                const base: u32 = @intCast(x * verts_y + y);
                const verts = [_]u32{
                    base,
                    base + @as(u32, @intCast(verts_y)),
                    base + @as(u32, @intCast(verts_y + 1)),
                    base + 1,
                };
                if (with_uvs) {
                    const uv_x0 = @as(f32, @floatFromInt(x)) / @as(f32, @floatFromInt(edges_x));
                    const uv_x1 = @as(f32, @floatFromInt(x + 1)) / @as(f32, @floatFromInt(edges_x));
                    const uv_y0 = @as(f32, @floatFromInt(y)) / @as(f32, @floatFromInt(edges_y));
                    const uv_y1 = @as(f32, @floatFromInt(y + 1)) / @as(f32, @floatFromInt(edges_y));
                    const uvs = [_]math.Vec2{
                        .{ .x = uv_x0, .y = uv_y0 },
                        .{ .x = uv_x1, .y = uv_y0 },
                        .{ .x = uv_x1, .y = uv_y1 },
                        .{ .x = uv_x0, .y = uv_y1 },
                    };
                    try mesh.appendFace(&verts, &uvs);
                } else {
                    try mesh.appendFace(&verts, null);
                }
            }
        }
        try mesh.rebuildEdgesFromFaces();
    } else {
        for (0..verts_x) |x| {
            for (0..edges_y) |y| {
                try mesh.appendEdge(@intCast(x * verts_y + y), @intCast(x * verts_y + y + 1));
            }
        }
        for (0..verts_y) |y| {
            for (0..edges_x) |x| {
                try mesh.appendEdge(@intCast(x * verts_y + y), @intCast((x + 1) * verts_y + y));
            }
        }
    }

    return mesh;
}

test "grid mesh matches expected counts" {
    var mesh = try createGridMesh(std.testing.allocator, 3, 2, 2, 1, true);
    defer mesh.deinit();

    try std.testing.expectEqual(@as(usize, 6), mesh.positions.items.len);
    try std.testing.expectEqual(@as(usize, 2), mesh.faceCount());
    try std.testing.expectEqual(@as(usize, 7), mesh.edges.items.len);
    try std.testing.expectEqual(@as(usize, 8), mesh.corner_uvs.items.len);
}

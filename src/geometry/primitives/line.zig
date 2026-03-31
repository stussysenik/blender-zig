const std = @import("std");
const math = @import("../../math.zig");
const mesh_mod = @import("../../mesh.zig");

pub fn createLineMesh(
    allocator: std.mem.Allocator,
    start: math.Vec3,
    delta: math.Vec3,
    count: usize,
) !mesh_mod.Mesh {
    if (count == 0) return error.InvalidResolution;

    var mesh = try mesh_mod.Mesh.init(allocator);
    errdefer mesh.deinit();

    for (0..count) |index| {
        const step: f32 = @floatFromInt(index);
        _ = try mesh.appendVertex(start.add(delta.scale(step)));
    }

    for (0..count -| 1) |index| {
        try mesh.appendEdge(@intCast(index), @intCast(index + 1));
    }

    return mesh;
}

test "line mesh creates a strip" {
    var mesh = try createLineMesh(std.testing.allocator, math.Vec3.init(0, 0, 0), math.Vec3.init(1, 0, 0), 4);
    defer mesh.deinit();

    try std.testing.expectEqual(@as(usize, 4), mesh.positions.items.len);
    try std.testing.expectEqual(@as(usize, 3), mesh.edges.items.len);
    try std.testing.expect(math.vec3ApproxEq(mesh.positions.items[3], math.Vec3.init(3, 0, 0), 0.0001));
}

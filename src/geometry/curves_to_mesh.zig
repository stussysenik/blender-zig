const std = @import("std");
const curves_mod = @import("curves.zig");
const math = @import("../math.zig");
const mesh_mod = @import("../mesh.zig");

pub const Options = struct {
    close_cyclic_curves: bool = true,
};

pub fn convertCurvesToPolylineMesh(
    allocator: std.mem.Allocator,
    curves: *const curves_mod.CurvesGeometry,
    options: Options,
) !mesh_mod.Mesh {
    var mesh = try mesh_mod.Mesh.init(allocator);
    errdefer mesh.deinit();

    for (0..curves.curvesNum()) |curve_index| {
        const range = curves.pointsByCurve(curve_index);
        if (range.len() == 0) continue;

        var first_vertex: ?u32 = null;
        var previous_vertex: ?u32 = null;

        for (range.start..range.end) |point_index| {
            const current_vertex = try mesh.appendVertex(curves.positions.items[point_index]);
            if (first_vertex == null) {
                first_vertex = current_vertex;
            }
            if (previous_vertex) |previous| {
                try mesh.appendEdge(previous, current_vertex);
            }
            previous_vertex = current_vertex;
        }

        if (options.close_cyclic_curves and curves.cyclicFlags()[curve_index] and first_vertex != null and previous_vertex != null) {
            try mesh.appendEdge(previous_vertex.?, first_vertex.?);
        }
    }

    return mesh;
}

test "convert open curves to a polyline mesh" {
    var curves = try curves_mod.CurvesGeometry.init(std.testing.allocator);
    defer curves.deinit();

    const points = [_]math.Vec3{
        math.Vec3.init(-1, 0, 0),
        math.Vec3.init(2, 1, 0),
        math.Vec3.init(3, 2, 0),
    };
    try curves.appendCurve(&points, false, null);

    var mesh = try convertCurvesToPolylineMesh(std.testing.allocator, &curves, .{});
    defer mesh.deinit();

    try std.testing.expectEqual(@as(usize, 3), mesh.vertexCount());
    try std.testing.expectEqual(@as(usize, 2), mesh.edges.items.len);
    try std.testing.expect(mesh.bounds != null);
    try std.testing.expect(math.vec3ApproxEq(mesh.bounds.?.min, math.Vec3.init(-1, 0, 0), 0.0001));
    try std.testing.expect(math.vec3ApproxEq(mesh.bounds.?.max, math.Vec3.init(3, 2, 0), 0.0001));
    const expected = [_]mesh_mod.Edge{
        .{ .a = 0, .b = 1 },
        .{ .a = 1, .b = 2 },
    };
    try std.testing.expectEqualSlices(mesh_mod.Edge, expected[0..], mesh.edges.items);
}

test "convert cyclic curves can close the loop" {
    var curves = try curves_mod.CurvesGeometry.init(std.testing.allocator);
    defer curves.deinit();

    const points = [_]math.Vec3{
        math.Vec3.init(0, 0, 0),
        math.Vec3.init(1, 0, 0),
        math.Vec3.init(1, 1, 0),
    };
    try curves.appendCurve(&points, true, null);

    var closed_mesh = try convertCurvesToPolylineMesh(std.testing.allocator, &curves, .{ .close_cyclic_curves = true });
    defer closed_mesh.deinit();

    try std.testing.expectEqual(@as(usize, 3), closed_mesh.vertexCount());
    try std.testing.expectEqual(@as(usize, 3), closed_mesh.edges.items.len);
    const expected = [_]mesh_mod.Edge{
        .{ .a = 0, .b = 1 },
        .{ .a = 1, .b = 2 },
        .{ .a = 2, .b = 0 },
    };
    try std.testing.expectEqualSlices(mesh_mod.Edge, expected[0..], closed_mesh.edges.items);
}

test "convert cyclic curves can leave the loop open" {
    var curves = try curves_mod.CurvesGeometry.init(std.testing.allocator);
    defer curves.deinit();

    const points = [_]math.Vec3{
        math.Vec3.init(0, 0, 0),
        math.Vec3.init(1, 0, 0),
        math.Vec3.init(1, 1, 0),
    };
    try curves.appendCurve(&points, true, null);

    var open_mesh = try convertCurvesToPolylineMesh(std.testing.allocator, &curves, .{ .close_cyclic_curves = false });
    defer open_mesh.deinit();

    try std.testing.expectEqual(@as(usize, 3), open_mesh.vertexCount());
    try std.testing.expectEqual(@as(usize, 2), open_mesh.edges.items.len);
    const expected = [_]mesh_mod.Edge{
        .{ .a = 0, .b = 1 },
        .{ .a = 1, .b = 2 },
    };
    try std.testing.expectEqualSlices(mesh_mod.Edge, expected[0..], open_mesh.edges.items);
}

test "convert multiple curves preserves disjoint topology" {
    var curves = try curves_mod.CurvesGeometry.init(std.testing.allocator);
    defer curves.deinit();

    const left_points = [_]math.Vec3{
        math.Vec3.init(-2, 0, 0),
        math.Vec3.init(-1, 0, 0),
    };
    const right_points = [_]math.Vec3{
        math.Vec3.init(2, 0, 0),
        math.Vec3.init(3, 0, 0),
        math.Vec3.init(4, 0, 0),
    };
    try curves.appendCurve(&left_points, false, null);
    try curves.appendCurve(&right_points, false, null);

    var mesh = try convertCurvesToPolylineMesh(std.testing.allocator, &curves, .{});
    defer mesh.deinit();

    try std.testing.expectEqual(@as(usize, 5), mesh.vertexCount());
    try std.testing.expectEqual(@as(usize, 3), mesh.edges.items.len);
    const expected = [_]mesh_mod.Edge{
        .{ .a = 0, .b = 1 },
        .{ .a = 2, .b = 3 },
        .{ .a = 3, .b = 4 },
    };
    try std.testing.expectEqualSlices(mesh_mod.Edge, expected[0..], mesh.edges.items);
}

test "convert empty and singleton curves are safe" {
    var curves = try curves_mod.CurvesGeometry.init(std.testing.allocator);
    defer curves.deinit();

    const singleton = [_]math.Vec3{
        math.Vec3.init(5, 6, 7),
    };
    try curves.appendCurve(&singleton, true, null);

    var mesh = try convertCurvesToPolylineMesh(std.testing.allocator, &curves, .{});
    defer mesh.deinit();

    try std.testing.expectEqual(@as(usize, 1), mesh.vertexCount());
    try std.testing.expectEqual(@as(usize, 0), mesh.edges.items.len);
    try std.testing.expect(mesh.bounds != null);
    try std.testing.expect(math.vec3ApproxEq(mesh.bounds.?.min, math.Vec3.init(5, 6, 7), 0.0001));
    try std.testing.expect(math.vec3ApproxEq(mesh.bounds.?.max, math.Vec3.init(5, 6, 7), 0.0001));
}

const std = @import("std");
const curves_mod = @import("curves.zig");
const math = @import("../math.zig");
const mesh_mod = @import("../mesh.zig");

pub const Options = struct {
    close_cyclic_curves: bool = true,
};

pub const CurveToMeshOptions = struct {
    scale: f32 = 1.0,
    fill_caps: bool = false,
};

const Frame = struct {
    tangent: math.Vec3,
    normal: math.Vec3,
    binormal: math.Vec3,
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

pub fn curveToWireMesh(allocator: std.mem.Allocator, curves: *const curves_mod.CurvesGeometry) !mesh_mod.Mesh {
    return convertCurvesToPolylineMesh(allocator, curves, .{ .close_cyclic_curves = true });
}

// This stays intentionally narrow: polyline curves sweep a polyline profile with a stable frame.
pub fn curveToMeshSweep(
    allocator: std.mem.Allocator,
    main_curves: *const curves_mod.CurvesGeometry,
    profile_curves: *const curves_mod.CurvesGeometry,
    options: CurveToMeshOptions,
) !mesh_mod.Mesh {
    var result = try mesh_mod.Mesh.init(allocator);
    errdefer result.deinit();

    for (0..main_curves.curvesNum()) |main_curve_index| {
        const main_range = main_curves.pointsByCurve(main_curve_index);
        const main_points = main_curves.positions.items[main_range.start..main_range.end];
        if (main_points.len == 0) continue;

        for (0..profile_curves.curvesNum()) |profile_curve_index| {
            const profile_range = profile_curves.pointsByCurve(profile_curve_index);
            const profile_points = profile_curves.positions.items[profile_range.start..profile_range.end];
            if (profile_points.len == 0) continue;

            var pair_mesh = try sweepCurvePair(
                allocator,
                main_points,
                main_curves.cyclicFlags()[main_curve_index],
                profile_points,
                profile_curves.cyclicFlags()[profile_curve_index],
                options,
            );
            defer pair_mesh.deinit();

            try result.appendMesh(&pair_mesh);
        }
    }

    return result;
}

fn sweepCurvePair(
    allocator: std.mem.Allocator,
    main_points: []const math.Vec3,
    main_cyclic: bool,
    profile_points: []const math.Vec3,
    profile_cyclic: bool,
    options: CurveToMeshOptions,
) !mesh_mod.Mesh {
    var mesh = try mesh_mod.Mesh.init(allocator);
    errdefer mesh.deinit();

    const frames = try buildFrames(allocator, main_points, main_cyclic);
    defer allocator.free(frames);

    for (main_points, frames) |origin, frame| {
        for (profile_points) |profile_point| {
            _ = try mesh.appendVertex(transformProfilePoint(origin, frame, profile_point, options.scale));
        }
    }

    const main_segment_count = segmentCount(main_points.len, main_cyclic);
    const profile_segment_count = segmentCount(profile_points.len, profile_cyclic);

    if (main_segment_count == 0 and profile_segment_count > 0) {
        const ring_start = ringVertex(profile_points.len, 0, 0);
        try appendRingEdges(&mesh, ring_start, profile_points.len, profile_cyclic);
        return mesh;
    }
    if (profile_segment_count == 0 and main_segment_count > 0) {
        for (0..main_segment_count) |segment_index| {
            try mesh.appendEdge(
                ringVertex(profile_points.len, segment_index, 0),
                ringVertex(profile_points.len, nextMainIndex(segment_index, main_points.len, main_cyclic), 0),
            );
        }
        return mesh;
    }
    if (main_segment_count == 0 or profile_segment_count == 0) {
        return mesh;
    }

    for (0..main_segment_count) |main_segment_index| {
        const next_main = nextMainIndex(main_segment_index, main_points.len, main_cyclic);
        for (0..profile_segment_count) |profile_segment_index| {
            const next_profile = nextProfileIndex(profile_segment_index, profile_points.len, profile_cyclic);
            const face = [_]u32{
                ringVertex(profile_points.len, main_segment_index, profile_segment_index),
                ringVertex(profile_points.len, main_segment_index, next_profile),
                ringVertex(profile_points.len, next_main, next_profile),
                ringVertex(profile_points.len, next_main, profile_segment_index),
            };
            try mesh.appendFace(&face, null);
        }
    }

    if (options.fill_caps and !main_cyclic and profile_cyclic and profile_points.len >= 3) {
        try appendCapFace(allocator, &mesh, profile_points.len, 0, true);
        try appendCapFace(allocator, &mesh, profile_points.len, main_points.len - 1, false);
    }

    try mesh.rebuildEdgesFromFaces();
    return mesh;
}

fn buildFrames(allocator: std.mem.Allocator, points: []const math.Vec3, cyclic: bool) ![]Frame {
    const frames = try allocator.alloc(Frame, points.len);
    if (points.len == 0) return frames;

    if (points.len == 1) {
        frames[0] = .{
            .tangent = math.Vec3.init(0, 0, 1),
            .normal = math.Vec3.init(1, 0, 0),
            .binormal = math.Vec3.init(0, 1, 0),
        };
        return frames;
    }

    var previous_normal: ?math.Vec3 = null;
    var previous_tangent = math.Vec3.init(0, 0, 1);

    for (points, 0..) |_, point_index| {
        const tangent = computeTangent(points, cyclic, point_index, previous_tangent);
        const frame = makeFrame(tangent, previous_normal);
        frames[point_index] = frame;
        previous_tangent = frame.tangent;
        previous_normal = frame.normal;
    }

    return frames;
}

fn computeTangent(points: []const math.Vec3, cyclic: bool, point_index: usize, fallback: math.Vec3) math.Vec3 {
    if (points.len == 1) return fallback;

    if (!cyclic) {
        if (point_index == 0) {
            return points[1].sub(points[0]).normalizedOr(fallback);
        }
        if (point_index + 1 == points.len) {
            return points[point_index].sub(points[point_index - 1]).normalizedOr(fallback);
        }
        return points[point_index + 1].sub(points[point_index - 1]).normalizedOr(fallback);
    }

    const previous_index = if (point_index == 0) points.len - 1 else point_index - 1;
    const next_index = if (point_index + 1 == points.len) 0 else point_index + 1;
    return points[next_index].sub(points[previous_index]).normalizedOr(fallback);
}

fn makeFrame(tangent: math.Vec3, previous_normal: ?math.Vec3) Frame {
    const unit_tangent = tangent.normalizedOr(math.Vec3.init(0, 0, 1));
    var normal = if (previous_normal) |carry|
        carry.sub(unit_tangent.scale(carry.dot(unit_tangent)))
    else
        preferredAxis(unit_tangent).cross(unit_tangent);

    if (normal.lengthSquared() <= 1e-10) {
        normal = preferredAxis(unit_tangent).cross(unit_tangent);
    }
    normal = normal.normalizedOr(math.Vec3.init(1, 0, 0));

    var binormal = unit_tangent.cross(normal);
    if (binormal.lengthSquared() <= 1e-10) {
        const fallback_normal = fallbackNormal(unit_tangent);
        binormal = unit_tangent.cross(fallback_normal);
        normal = fallback_normal;
    }
    binormal = binormal.normalizedOr(math.Vec3.init(0, 1, 0));
    normal = binormal.cross(unit_tangent).normalizedOr(normal);

    return .{
        .tangent = unit_tangent,
        .normal = normal,
        .binormal = binormal,
    };
}

fn preferredAxis(tangent: math.Vec3) math.Vec3 {
    if (@abs(tangent.dot(math.Vec3.init(0, 0, 1))) < 0.95) {
        return math.Vec3.init(0, 0, 1);
    }
    return math.Vec3.init(0, 1, 0);
}

fn fallbackNormal(tangent: math.Vec3) math.Vec3 {
    return preferredAxis(tangent).cross(tangent).normalizedOr(math.Vec3.init(1, 0, 0));
}

fn transformProfilePoint(origin: math.Vec3, frame: Frame, local_point: math.Vec3, scale: f32) math.Vec3 {
    return origin
        .add(frame.normal.scale(local_point.x * scale))
        .add(frame.binormal.scale(local_point.y * scale))
        .add(frame.tangent.scale(local_point.z * scale));
}

fn segmentCount(point_count: usize, cyclic: bool) usize {
    if (point_count < 2) return 0;
    return if (cyclic) point_count else point_count - 1;
}

fn nextMainIndex(index: usize, point_count: usize, cyclic: bool) usize {
    return if (cyclic and index + 1 == point_count) 0 else index + 1;
}

fn nextProfileIndex(index: usize, point_count: usize, cyclic: bool) usize {
    return if (cyclic and index + 1 == point_count) 0 else index + 1;
}

fn ringVertex(profile_point_count: usize, main_point_index: usize, profile_point_index: usize) u32 {
    return @intCast(main_point_index * profile_point_count + profile_point_index);
}

fn appendRingEdges(mesh: *mesh_mod.Mesh, ring_start: u32, point_count: usize, cyclic: bool) !void {
    if (point_count < 2) return;

    for (0..point_count - 1) |point_index| {
        try mesh.appendEdge(ring_start + @as(u32, @intCast(point_index)), ring_start + @as(u32, @intCast(point_index + 1)));
    }
    if (cyclic and point_count > 2) {
        try mesh.appendEdge(ring_start + @as(u32, @intCast(point_count - 1)), ring_start);
    }
}

fn appendCapFace(
    allocator: std.mem.Allocator,
    mesh: *mesh_mod.Mesh,
    profile_point_count: usize,
    main_point_index: usize,
    reverse_order: bool,
) !void {
    var cap = std.ArrayList(u32).empty;
    defer cap.deinit(allocator);

    try cap.ensureTotalCapacity(allocator, profile_point_count);
    for (0..profile_point_count) |profile_point_index| {
        const index = if (reverse_order) profile_point_count - 1 - profile_point_index else profile_point_index;
        cap.appendAssumeCapacity(ringVertex(profile_point_count, main_point_index, index));
    }
    try mesh.appendFace(cap.items, null);
}

fn createCurve(allocator: std.mem.Allocator, points: []const math.Vec3, cyclic: bool) !curves_mod.CurvesGeometry {
    var curves = try curves_mod.CurvesGeometry.init(allocator);
    errdefer curves.deinit();
    try curves.appendCurve(points, cyclic, null);
    return curves;
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

test "curve to mesh sweep turns a square profile into a tube surface" {
    const main_points = [_]math.Vec3{
        .{ .x = 0, .y = 0, .z = 0 },
        .{ .x = 0, .y = 0, .z = 1 },
        .{ .x = 0, .y = 0, .z = 2 },
    };
    const profile_points = [_]math.Vec3{
        .{ .x = -1, .y = -1, .z = 0 },
        .{ .x = 1, .y = -1, .z = 0 },
        .{ .x = 1, .y = 1, .z = 0 },
        .{ .x = -1, .y = 1, .z = 0 },
    };

    var main_curves = try createCurve(std.testing.allocator, &main_points, false);
    defer main_curves.deinit();
    var profile_curves = try createCurve(std.testing.allocator, &profile_points, true);
    defer profile_curves.deinit();

    var mesh = try curveToMeshSweep(std.testing.allocator, &main_curves, &profile_curves, .{});
    defer mesh.deinit();

    try std.testing.expectEqual(@as(usize, 12), mesh.vertexCount());
    try std.testing.expectEqual(@as(usize, 8), mesh.faceCount());
    try std.testing.expect(math.approxEq(mesh.bounds.?.min.z, 0.0, 0.0001));
    try std.testing.expect(math.approxEq(mesh.bounds.?.max.z, 2.0, 0.0001));
}

test "curve to mesh sweep can fill caps for cyclic profiles" {
    const main_points = [_]math.Vec3{
        .{ .x = 0, .y = 0, .z = 0 },
        .{ .x = 0, .y = 0, .z = 1 },
        .{ .x = 0, .y = 0, .z = 2 },
    };
    const profile_points = [_]math.Vec3{
        .{ .x = -0.5, .y = -0.5, .z = 0 },
        .{ .x = 0.5, .y = -0.5, .z = 0 },
        .{ .x = 0.5, .y = 0.5, .z = 0 },
        .{ .x = -0.5, .y = 0.5, .z = 0 },
    };

    var main_curves = try createCurve(std.testing.allocator, &main_points, false);
    defer main_curves.deinit();
    var profile_curves = try createCurve(std.testing.allocator, &profile_points, true);
    defer profile_curves.deinit();

    var mesh = try curveToMeshSweep(std.testing.allocator, &main_curves, &profile_curves, .{ .fill_caps = true });
    defer mesh.deinit();

    try std.testing.expectEqual(@as(usize, 10), mesh.faceCount());
}

test "curve to mesh sweep falls back to loose edges for a single-point profile" {
    const main_points = [_]math.Vec3{
        .{ .x = 0, .y = 0, .z = 0 },
        .{ .x = 1, .y = 0, .z = 0 },
        .{ .x = 2, .y = 0, .z = 0 },
    };
    const profile_points = [_]math.Vec3{
        .{ .x = 0, .y = 0, .z = 0 },
    };

    var main_curves = try createCurve(std.testing.allocator, &main_points, false);
    defer main_curves.deinit();
    var profile_curves = try createCurve(std.testing.allocator, &profile_points, false);
    defer profile_curves.deinit();

    var mesh = try curveToMeshSweep(std.testing.allocator, &main_curves, &profile_curves, .{});
    defer mesh.deinit();

    try std.testing.expectEqual(@as(usize, 3), mesh.vertexCount());
    try std.testing.expectEqual(@as(usize, 2), mesh.edges.items.len);
    try std.testing.expectEqual(@as(usize, 0), mesh.faceCount());
}

const std = @import("std");
const blendzig = @import("blendzig");

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    const args = try std.process.argsAlloc(allocator);
    defer std.process.argsFree(allocator, args);

    if (args.len < 2) {
        try printUsage();
        return;
    }

    var stdout_buffer: [4096]u8 = undefined;
    var stdout_writer = std.fs.File.stdout().writer(&stdout_buffer);
    const stdout = &stdout_writer.interface;

    const command = args[1];
    if (std.mem.eql(u8, command, "curve-wire") or std.mem.eql(u8, command, "curve-tube")) {
        var mesh = try buildCurveCommand(allocator, command);
        defer mesh.deinit();

        try printMeshSummary(stdout, command, &mesh);
        if (args.len >= 3) {
            try blendzig.io.obj.writeFile(&mesh, args[2]);
            try stdout.print("wrote {s}\n", .{args[2]});
        }
        try stdout.flush();
        return;
    }
    if (std.mem.eql(u8, command, "mesh-edges") or std.mem.eql(u8, command, "graph-demo")) {
        var geometry = if (std.mem.eql(u8, command, "mesh-edges"))
            try buildGeometryCommand(allocator, command)
        else
            try buildGraphDemo(allocator);
        defer geometry.deinit();

        try printGeometrySummary(stdout, command, &geometry);
        if (args.len >= 3) {
            try blendzig.io.obj.writeGeometryFile(&geometry, args[2]);
            try stdout.print("wrote {s}\n", .{args[2]});
        }
        try stdout.flush();
        return;
    }

    var mesh = try buildPrimitive(allocator, command);
    defer mesh.deinit();

    try printMeshSummary(stdout, command, &mesh);
    if (args.len >= 3) {
        try blendzig.io.obj.writeFile(&mesh, args[2]);
        try stdout.print("wrote {s}\n", .{args[2]});
    }
    try stdout.flush();
}

fn printUsage() !void {
    var stderr_buffer: [2048]u8 = undefined;
    var stderr_writer = std.fs.File.stderr().writer(&stderr_buffer);
    const stderr = &stderr_writer.interface;
    try stderr.writeAll(
        \\usage: blender-zig <line|grid|cuboid|cylinder|cone|sphere|curve-wire|curve-tube|mesh-edges|graph-demo> [output.obj]
        \\examples:
        \\  zig build run -- sphere
        \\  zig build run -- cylinder zig-out/cylinder.obj
        \\  zig build run -- cone zig-out/cone.obj
        \\  zig build run -- curve-wire zig-out/curve-wire.obj
        \\  zig build run -- curve-tube zig-out/curve-tube.obj
        \\  zig build run -- mesh-edges zig-out/mesh-edges.obj
        \\  zig build run -- cuboid zig-out/cuboid.obj
        \\  zig build run -- graph-demo zig-out/graph-demo.obj
        \\
    );
    try stderr.flush();
}

fn buildPrimitive(allocator: std.mem.Allocator, primitive: []const u8) !blendzig.mesh.Mesh {
    if (std.mem.eql(u8, primitive, "line")) {
        return blendzig.geometry.createLineMesh(
            allocator,
            blendzig.math.Vec3.init(-2, 0, 0),
            blendzig.math.Vec3.init(0.6, 0.1, 0.0),
            8,
        );
    }
    if (std.mem.eql(u8, primitive, "grid")) {
        return blendzig.geometry.createGridMesh(allocator, 8, 5, 4.0, 2.0, true);
    }
    if (std.mem.eql(u8, primitive, "cuboid")) {
        return blendzig.geometry.createCuboidMesh(
            allocator,
            blendzig.math.Vec3.init(3.0, 2.0, 1.5),
            4,
            3,
            2,
            true,
        );
    }
    if (std.mem.eql(u8, primitive, "cylinder")) {
        return blendzig.geometry.createCylinderMesh(allocator, 1.25, 3.0, 24, true, true, true);
    }
    if (std.mem.eql(u8, primitive, "cone")) {
        return blendzig.geometry.createConeMesh(allocator, 1.25, 3.0, 24, true, true);
    }
    if (std.mem.eql(u8, primitive, "sphere")) {
        return blendzig.geometry.createUvSphereMesh(allocator, 1.5, 16, 8, true);
    }
    return error.UnknownPrimitive;
}

test "build primitive rejects unknown names" {
    try std.testing.expectError(error.UnknownPrimitive, buildPrimitive(std.testing.allocator, "teapot"));
}

fn printMeshSummary(writer: anytype, label: []const u8, mesh: *const blendzig.mesh.Mesh) !void {
    try writer.print(
        "command={s} vertices={d} edges={d} faces={d}\n",
        .{ label, mesh.vertexCount(), mesh.edges.items.len, mesh.faceCount() },
    );
    if (mesh.bounds) |bounds| {
        try writer.print(
            "bounds min=({}, {}, {}) max=({}, {}, {})\n",
            .{ bounds.min.x, bounds.min.y, bounds.min.z, bounds.max.x, bounds.max.y, bounds.max.z },
        );
    }
}

fn printGeometrySummary(writer: anytype, label: []const u8, geometry: *const blendzig.geometry.GeometrySet) !void {
    const mesh_vertices = if (geometry.mesh) |*mesh| mesh.vertexCount() else 0;
    const mesh_edges = if (geometry.mesh) |*mesh| mesh.edges.items.len else 0;
    const mesh_faces = if (geometry.mesh) |*mesh| mesh.faceCount() else 0;
    const curve_points = if (geometry.curves) |*curves| curves.pointsNum() else 0;
    const curve_splines = if (geometry.curves) |*curves| curves.curvesNum() else 0;
    const instances = if (geometry.instances) |*inst| inst.items.items.len else 0;

    try writer.print(
        "command={s} mesh_vertices={d} mesh_edges={d} mesh_faces={d} curve_points={d} curve_splines={d} instances={d}\n",
        .{ label, mesh_vertices, mesh_edges, mesh_faces, curve_points, curve_splines, instances },
    );
    if (geometry.mesh) |*mesh| {
        if (mesh.bounds) |bounds| {
            try writer.print(
                "mesh_bounds min=({}, {}, {}) max=({}, {}, {})\n",
                .{ bounds.min.x, bounds.min.y, bounds.min.z, bounds.max.x, bounds.max.y, bounds.max.z },
            );
        }
    }
}

fn buildCurveCommand(allocator: std.mem.Allocator, command: []const u8) !blendzig.mesh.Mesh {
    if (std.mem.eql(u8, command, "curve-wire")) {
        var path = try createHelixCurve(allocator, 3, 18, 1.2, 0.1);
        defer path.deinit();
        return blendzig.geometry.convertCurvesToPolylineMesh(allocator, &path, .{});
    }
    if (std.mem.eql(u8, command, "curve-tube")) {
        var path = try createHelixCurve(allocator, 4, 18, 1.4, 0.1);
        defer path.deinit();
        var profile = try createCircleProfile(allocator, 0.18, 10);
        defer profile.deinit();
        return blendzig.geometry.curveToMeshSweep(allocator, &path, &profile, .{ .fill_caps = true });
    }
    return error.UnknownPrimitive;
}

fn buildGeometryCommand(allocator: std.mem.Allocator, command: []const u8) !blendzig.geometry.GeometrySet {
    if (std.mem.eql(u8, command, "mesh-edges")) {
        var source_mesh = try blendzig.geometry.createCylinderMesh(allocator, 1.2, 2.8, 12, true, true, false);
        defer source_mesh.deinit();

        var geometry = try blendzig.geometry.GeometrySet.fromMeshClone(allocator, &source_mesh);
        errdefer geometry.deinit();
        geometry.curves = try blendzig.geometry.meshEdgesToCurves(allocator, &source_mesh);
        return geometry;
    }
    return error.UnknownPrimitive;
}

fn buildGraphDemo(allocator: std.mem.Allocator) !blendzig.geometry.GeometrySet {
    var graph = blendzig.nodes.Graph.init(allocator);
    defer graph.deinit();

    const grid = try graph.addNode(blendzig.nodes.Node.init("grid", .{
        .grid = .{
            .verts_x = 5,
            .verts_y = 5,
            .size_x = 6.0,
            .size_y = 6.0,
            .with_uvs = true,
        },
    }));
    const curve = try graph.addNode(blendzig.nodes.Node.init("curve-line", .{
        .curve_line = .{
            .start = blendzig.math.Vec3.init(-2.0, -1.5, 0.25),
            .delta = blendzig.math.Vec3.init(1.0, 0.0, 0.0),
            .count = 5,
        },
    }));
    const seed = try graph.addNode(blendzig.nodes.Node.init("seed", .{ .join_geometry = {} }));
    const array = try graph.addNode(blendzig.nodes.Node.init("curve-array", .{
        .curve_instance_array = .{
            .count = 4,
            .step = blendzig.math.Vec3.init(0.0, 1.5, 0.0),
        },
    }));
    const realize = try graph.addNode(blendzig.nodes.Node.init("realize", .{
        .realize_instances = .{},
    }));
    const sphere = try graph.addNode(blendzig.nodes.Node.init("sphere", .{
        .uv_sphere = .{
            .radius = 0.8,
            .segments = 12,
            .rings = 6,
            .with_uvs = true,
        },
    }));
    const lift = try graph.addNode(blendzig.nodes.Node.init("lift", .{
        .vector_constant = blendzig.math.Vec3.init(0.0, 0.0, 1.4),
    }));
    const sphere_translate = try graph.addNode(blendzig.nodes.Node.init("sphere-translate", .{
        .translate = .{},
    }));
    const out = try graph.addNode(blendzig.nodes.Node.init("out", .{ .join_geometry = {} }));

    try graph.addEdge(grid, seed);
    try graph.addEdge(curve, seed);
    try graph.addEdge(seed, array);
    try graph.addEdge(array, realize);
    try graph.addEdge(sphere, sphere_translate);
    try graph.addTypedEdge(lift, sphere_translate, .vector3);
    try graph.addEdge(realize, out);
    try graph.addEdge(sphere_translate, out);

    // Keep the CLI demo fixed for now so it exercises the graph runtime without needing a parser layer yet.
    var evaluation = try graph.evaluate(allocator);
    defer evaluation.deinit();

    return try evaluation.geometry(out).?.clone(allocator);
}

test "graph demo builds realized geometry" {
    var geometry = try buildGraphDemo(std.testing.allocator);
    defer geometry.deinit();

    try std.testing.expect(geometry.mesh != null);
    try std.testing.expect(geometry.curves != null);
    try std.testing.expect(geometry.instances == null);
    try std.testing.expectEqual(@as(usize, 20), geometry.curves.?.pointsNum());
    try std.testing.expectEqual(@as(usize, 4), geometry.curves.?.curvesNum());
}

fn createHelixCurve(
    allocator: std.mem.Allocator,
    turns: usize,
    points_per_turn: usize,
    radius: f32,
    rise_per_point: f32,
) !blendzig.geometry.CurvesGeometry {
    const point_count = turns * points_per_turn + 1;
    const positions = try allocator.alloc(blendzig.math.Vec3, point_count);
    defer allocator.free(positions);

    for (0..point_count) |point_index| {
        const turn = @as(f32, @floatFromInt(point_index)) / @as(f32, @floatFromInt(points_per_turn));
        const angle = 2.0 * std.math.pi * turn;
        positions[point_index] = blendzig.math.Vec3.init(
            @cos(angle) * radius,
            @sin(angle) * radius,
            @as(f32, @floatFromInt(point_index)) * rise_per_point,
        );
    }

    var curves = try blendzig.geometry.CurvesGeometry.init(allocator);
    errdefer curves.deinit();
    try curves.appendCurve(positions, false, null);
    return curves;
}

fn createCircleProfile(
    allocator: std.mem.Allocator,
    radius: f32,
    point_count: usize,
) !blendzig.geometry.CurvesGeometry {
    const positions = try allocator.alloc(blendzig.math.Vec3, point_count);
    defer allocator.free(positions);

    for (0..point_count) |point_index| {
        const angle = 2.0 * std.math.pi * @as(f32, @floatFromInt(point_index)) / @as(f32, @floatFromInt(point_count));
        positions[point_index] = blendzig.math.Vec3.init(@cos(angle) * radius, @sin(angle) * radius, 0.0);
    }

    var curves = try blendzig.geometry.CurvesGeometry.init(allocator);
    errdefer curves.deinit();
    try curves.appendCurve(positions, true, null);
    return curves;
}

test "curve tube command builds faces" {
    var mesh = try buildCurveCommand(std.testing.allocator, "curve-tube");
    defer mesh.deinit();

    try std.testing.expect(mesh.faceCount() > 0);
    try std.testing.expect(mesh.vertexCount() > 0);
}

test "mesh edges command builds a mixed geometry view" {
    var geometry = try buildGeometryCommand(std.testing.allocator, "mesh-edges");
    defer geometry.deinit();

    try std.testing.expect(geometry.mesh != null);
    try std.testing.expect(geometry.curves != null);
    try std.testing.expect(geometry.curves.?.curvesNum() > 0);
    try std.testing.expect(geometry.curves.?.pointsNum() > 0);
}

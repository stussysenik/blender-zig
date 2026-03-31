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
    if (std.mem.eql(u8, command, "graph-demo")) {
        var geometry = try buildGraphDemo(allocator);
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

    try stdout.print(
        "primitive={s} vertices={d} edges={d} faces={d}\n",
        .{ command, mesh.vertexCount(), mesh.edges.items.len, mesh.faceCount() },
    );
    if (mesh.bounds) |bounds| {
        try stdout.print(
            "bounds min=({}, {}, {}) max=({}, {}, {})\n",
            .{ bounds.min.x, bounds.min.y, bounds.min.z, bounds.max.x, bounds.max.y, bounds.max.z },
        );
    }

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
        \\usage: blender-zig <line|grid|cuboid|sphere|graph-demo> [output.obj]
        \\examples:
        \\  zig build run -- sphere
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
    if (std.mem.eql(u8, primitive, "sphere")) {
        return blendzig.geometry.createUvSphereMesh(allocator, 1.5, 16, 8, true);
    }
    return error.UnknownPrimitive;
}

test "build primitive rejects unknown names" {
    try std.testing.expectError(error.UnknownPrimitive, buildPrimitive(std.testing.allocator, "teapot"));
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

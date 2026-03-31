const std = @import("std");
const blendzig = @import("blendzig");

// The CLI is intentionally small and explicit. Each command is both a runnable demo
// and a stable regression surface for one bounded rewrite slice.
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
    var stderr_buffer: [2048]u8 = undefined;
    var stderr_writer = std.fs.File.stderr().writer(&stderr_buffer);
    const stderr = &stderr_writer.interface;

    const command = args[1];
    if (std.mem.eql(u8, command, "mesh-scene")) {
        var parsed = try blendzig.scene.parseArgs(allocator, args[2..]);
        defer parsed.deinit(allocator);

        var mesh = try blendzig.scene.runMeshScene(allocator, parsed);
        defer mesh.deinit();

        try printMeshSummary(stdout, command, &mesh);
        if (parsed.output_path) |output_path| {
            try writeMeshOutput(&mesh, output_path);
            try stdout.print("wrote {s}\n", .{output_path});
        }
        try stdout.flush();
        return;
    }
    if (std.mem.eql(u8, command, "geometry-import")) {
        if (args.len < 3 or args.len > 4) {
            try printUsage();
            return;
        }

        const input_path = args[2];
        const output_path = if (args.len == 4) args[3] else null;
        if (output_path) |path| {
            if (try pathsResolveEqual(allocator, input_path, path)) {
                return error.ImportOutputMatchesInput;
            }
        }

        var imported = try readImportedGeometry(allocator, input_path);
        defer imported.deinit();
        switch (imported) {
            .geometry => |*geometry| {
                try printGeometrySummary(stdout, command, geometry);
                if (output_path) |path| {
                    try writeGeometryOutput(geometry, path);
                    try stdout.print("wrote {s}\n", .{path});
                }
                try stdout.flush();
                return;
            },
            .parse_failure => |failure| {
                try printObjParseFailure(stderr, input_path, failure);
                try stderr.flush();
                return error.InvalidImportedGeometry;
            },
        }
    }
    if (std.mem.eql(u8, command, "mesh-import")) {
        if (args.len < 3 or args.len > 4) {
            try printUsage();
            return;
        }

        const input_path = args[2];
        const output_path = if (args.len == 4) args[3] else null;
        if (output_path) |path| {
            if (try pathsResolveEqual(allocator, input_path, path)) {
                return error.ImportOutputMatchesInput;
            }
        }

        var imported = try readImportedMesh(allocator, input_path);
        defer imported.deinit();
        switch (imported) {
            .mesh => |*mesh| {
                try printMeshSummary(stdout, command, mesh);
                if (output_path) |path| {
                    try writeMeshOutput(mesh, path);
                    try stdout.print("wrote {s}\n", .{path});
                }
                try stdout.flush();
                return;
            },
            .parse_failure => |failure| {
                try printObjParseFailure(stderr, input_path, failure);
                try stderr.flush();
                return error.InvalidImportedMesh;
            },
        }
    }
    if (std.mem.eql(u8, command, "mesh-pipeline")) {
        // `mesh-pipeline` is the current authoring shell: either feed inline step specs
        // or load the exact same step grammar from a checked-in recipe file.
        var parsed = try blendzig.pipeline.parseArgs(allocator, args[2..]);
        defer parsed.deinit(allocator);

        var mesh = try blendzig.pipeline.runMeshPipeline(allocator, parsed.seed, parsed.steps.items);
        defer mesh.deinit();

        try printMeshSummary(stdout, command, &mesh);
        if (parsed.output_path) |output_path| {
            try writeMeshOutput(&mesh, output_path);
            try stdout.print("wrote {s}\n", .{output_path});
        }
        try stdout.flush();
        return;
    }
    // Keep the direct CLI explicit. It doubles as a runnable demo surface and a stable
    // regression path for contributors who want to validate one feature in isolation.
    if (std.mem.eql(u8, command, "curve-wire") or std.mem.eql(u8, command, "curve-tube") or std.mem.eql(u8, command, "mesh-roundtrip") or std.mem.eql(u8, command, "mesh-triangulate") or std.mem.eql(u8, command, "mesh-delete-loose") or std.mem.eql(u8, command, "mesh-merge-by-distance") or std.mem.eql(u8, command, "mesh-inset") or std.mem.eql(u8, command, "mesh-dissolve") or std.mem.eql(u8, command, "mesh-extrude") or std.mem.eql(u8, command, "mesh-planar-dissolve") or std.mem.eql(u8, command, "mesh-subdivide")) {
        var mesh = try buildDerivedMeshCommand(allocator, command);
        defer mesh.deinit();

        try printMeshSummary(stdout, command, &mesh);
        if (args.len >= 3) {
            try writeMeshOutput(&mesh, args[2]);
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
            try writeGeometryOutput(&geometry, args[2]);
            try stdout.print("wrote {s}\n", .{args[2]});
        }
        try stdout.flush();
        return;
    }

    var mesh = try buildPrimitive(allocator, command);
    defer mesh.deinit();

    try printMeshSummary(stdout, command, &mesh);
    if (args.len >= 3) {
        try writeMeshOutput(&mesh, args[2]);
        try stdout.print("wrote {s}\n", .{args[2]});
    }
    try stdout.flush();
}

fn printUsage() !void {
    var stderr_buffer: [3072]u8 = undefined;
    var stderr_writer = std.fs.File.stderr().writer(&stderr_buffer);
    const stderr = &stderr_writer.interface;
    try stderr.writeAll(
        \\usage: blender-zig <line|grid|cuboid|cylinder|cone|sphere|curve-wire|curve-tube|mesh-roundtrip|mesh-triangulate|mesh-delete-loose|mesh-merge-by-distance|mesh-inset|mesh-dissolve|mesh-extrude|mesh-planar-dissolve|mesh-subdivide|mesh-pipeline|mesh-scene|mesh-import|geometry-import|mesh-edges|graph-demo> [output-path]
        \\examples:
        \\  zig build run -- sphere
        \\  zig build run -- cylinder zig-out/cylinder.obj
        \\  zig build run -- mesh-import zig-out/sphere.obj zig-out/sphere-roundtrip.obj
        \\  zig build run -- geometry-import zig-out/graph-demo.obj zig-out/graph-demo-roundtrip.obj
        \\  zig build run -- cone zig-out/cone.obj
        \\  zig build run -- curve-wire zig-out/curve-wire.obj
        \\  zig build run -- curve-tube zig-out/curve-tube.obj
        \\  zig build run -- mesh-roundtrip zig-out/mesh-roundtrip.obj
        \\  zig build run -- mesh-triangulate zig-out/mesh-triangulate.obj
        \\  zig build run -- mesh-delete-loose zig-out/mesh-delete-loose.obj
        \\  zig build run -- mesh-merge-by-distance zig-out/mesh-merge-by-distance.obj
        \\  zig build run -- mesh-inset zig-out/mesh-inset.obj
        \\  zig build run -- mesh-dissolve zig-out/mesh-dissolve.obj
        \\  zig build run -- mesh-extrude zig-out/mesh-extrude.obj
        \\  zig build run -- mesh-planar-dissolve zig-out/mesh-planar-dissolve.obj
        \\  zig build run -- mesh-subdivide zig-out/mesh-subdivide.obj
        \\  zig build run -- mesh-pipeline grid:verts-x=8,verts-y=5,size-x=4.0,size-y=2.0 subdivide:repeat=2 extrude:distance=0.75 inset:factor=0.1 --write zig-out/pipeline.obj
        \\  zig build run -- mesh-pipeline grid:verts-x=5,verts-y=4,size-x=4.0,size-y=2.5 scale:x=0.45,y=0.45,z=1.0 array:count-x=4,count-y=3,offset-x=1.35,offset-y=0.95 rotate-z:degrees=12 translate:x=-2.0,y=-1.3,z=0.0 --write zig-out/plaza.obj
        \\  zig build run -- mesh-pipeline --recipe recipes/grid-study.bzrecipe
        \\  zig build run -- mesh-pipeline --recipe recipes/courtyard-plaza-study.bzrecipe
        \\  zig build run -- mesh-scene --recipe recipes/courtyard-tower-scene.bzscene
        \\  zig build run -- mesh-pipeline --recipe recipes/cuboid-facet-study.bzrecipe
        \\  zig build run -- cylinder zig-out/cylinder.ply
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

fn writeMeshOutput(mesh: *const blendzig.mesh.Mesh, path: []const u8) !void {
    if (std.mem.endsWith(u8, path, ".ply")) {
        return blendzig.io.ply.writeFile(mesh, path);
    }
    return blendzig.io.obj.writeFile(mesh, path);
}

fn writeGeometryOutput(geometry: *const blendzig.geometry.GeometrySet, path: []const u8) !void {
    if (std.mem.endsWith(u8, path, ".ply")) {
        if (geometry.instances != null) return error.UnsupportedPlyGeometry;
        if (geometry.curves != null) return error.UnsupportedPlyGeometry;
        if (geometry.mesh) |*mesh| {
            return blendzig.io.ply.writeFile(mesh, path);
        }
        return error.UnsupportedPlyGeometry;
    }
    return blendzig.io.obj.writeGeometryFile(geometry, path);
}

fn readImportedMesh(allocator: std.mem.Allocator, path: []const u8) !blendzig.io.obj.ReadResult {
    if (std.mem.endsWith(u8, path, ".obj")) {
        return blendzig.io.obj.readFile(allocator, path);
    }
    return error.UnsupportedImportFormat;
}

fn readImportedGeometry(allocator: std.mem.Allocator, path: []const u8) !blendzig.io.obj.GeometryReadResult {
    if (std.mem.endsWith(u8, path, ".obj")) {
        return blendzig.io.obj.readGeometryFile(allocator, path);
    }
    return error.UnsupportedImportFormat;
}

fn printObjParseFailure(writer: anytype, path: []const u8, failure: blendzig.io.obj.ParseFailure) !void {
    try writer.print(
        "failed to import {s}: line={d} record={s} cause={s}\n",
        .{ path, failure.line_number, failure.record_kind.label(), @errorName(failure.cause) },
    );
}

fn pathsResolveEqual(allocator: std.mem.Allocator, left: []const u8, right: []const u8) !bool {
    const cwd_real = try std.fs.cwd().realpathAlloc(allocator, ".");
    defer allocator.free(cwd_real);

    const left_path = try std.fs.path.resolve(allocator, &.{ cwd_real, left });
    defer allocator.free(left_path);
    const right_path = try std.fs.path.resolve(allocator, &.{ cwd_real, right });
    defer allocator.free(right_path);
    return std.mem.eql(u8, left_path, right_path);
}

fn buildDerivedMeshCommand(allocator: std.mem.Allocator, command: []const u8) !blendzig.mesh.Mesh {
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
    if (std.mem.eql(u8, command, "mesh-roundtrip")) {
        var source_mesh = try blendzig.geometry.createCylinderMesh(allocator, 1.2, 2.8, 12, false, false, false);
        defer source_mesh.deinit();
        var curves = try blendzig.geometry.meshEdgesToCurves(allocator, &source_mesh);
        defer curves.deinit();
        return blendzig.geometry.convertCurvesToPolylineMesh(allocator, &curves, .{});
    }
    if (std.mem.eql(u8, command, "mesh-triangulate")) {
        var source_mesh = try blendzig.geometry.createGridMesh(allocator, 6, 5, 6.0, 4.0, true);
        defer source_mesh.deinit();
        return blendzig.geometry.triangulateMesh(allocator, &source_mesh);
    }
    if (std.mem.eql(u8, command, "mesh-delete-loose")) {
        var source_mesh = try createLooseCleanupMesh(allocator);
        defer source_mesh.deinit();
        return blendzig.geometry.deleteLoose(allocator, &source_mesh);
    }
    if (std.mem.eql(u8, command, "mesh-merge-by-distance")) {
        var source_mesh = try createDuplicatedSeamMesh(allocator);
        defer source_mesh.deinit();
        return blendzig.geometry.mergeByDistance(allocator, &source_mesh, .{ .distance = 0.01 });
    }
    if (std.mem.eql(u8, command, "mesh-inset")) {
        var source_mesh = try blendzig.geometry.createGridMesh(allocator, 4, 3, 6.0, 4.0, true);
        defer source_mesh.deinit();
        return blendzig.geometry.insetIndividual(allocator, &source_mesh, .{ .factor = 0.2 });
    }
    if (std.mem.eql(u8, command, "mesh-dissolve")) {
        var source_mesh = try blendzig.geometry.createGridMesh(allocator, 3, 2, 2.0, 1.0, true);
        defer source_mesh.deinit();
        return blendzig.geometry.dissolveEdges(allocator, &source_mesh, &[_]blendzig.mesh.Edge{
            .{ .a = 2, .b = 3 },
        });
    }
    if (std.mem.eql(u8, command, "mesh-extrude")) {
        var source_mesh = try blendzig.geometry.createGridMesh(allocator, 2, 2, 2.0, 2.0, true);
        defer source_mesh.deinit();
        return blendzig.geometry.extrudeIndividual(allocator, &source_mesh, .{ .distance = 1.25 });
    }
    if (std.mem.eql(u8, command, "mesh-planar-dissolve")) {
        var source_mesh = try blendzig.geometry.createGridMesh(allocator, 2, 2, 2.0, 2.0, true);
        defer source_mesh.deinit();
        var triangulated = try blendzig.geometry.triangulateMesh(allocator, &source_mesh);
        defer triangulated.deinit();
        return blendzig.geometry.dissolvePlanar(allocator, &triangulated, .{});
    }
    if (std.mem.eql(u8, command, "mesh-subdivide")) {
        var source_mesh = try blendzig.geometry.createGridMesh(allocator, 3, 2, 2.0, 1.0, true);
        defer source_mesh.deinit();
        return blendzig.geometry.subdivideFaces(allocator, &source_mesh, .{});
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

    // Keep the CLI demo fixed for now so it exercises the graph runtime without needing
    // a scene parser layer. Direct geometry commands are still the main contributor path.
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

fn createDuplicatedSeamMesh(allocator: std.mem.Allocator) !blendzig.mesh.Mesh {
    var mesh = try blendzig.mesh.Mesh.init(allocator);
    errdefer mesh.deinit();

    // Build two quads with duplicated seam vertices so merge-by-distance has a
    // deterministic weld case that changes topology without needing imported assets.
    _ = try mesh.appendVertex(.{ .x = -1, .y = -1, .z = 0 });
    _ = try mesh.appendVertex(.{ .x = 0, .y = -1, .z = 0 });
    _ = try mesh.appendVertex(.{ .x = 0, .y = 1, .z = 0 });
    _ = try mesh.appendVertex(.{ .x = -1, .y = 1, .z = 0 });
    _ = try mesh.appendVertex(.{ .x = 0, .y = -1, .z = 0 });
    _ = try mesh.appendVertex(.{ .x = 1, .y = -1, .z = 0 });
    _ = try mesh.appendVertex(.{ .x = 1, .y = 1, .z = 0 });
    _ = try mesh.appendVertex(.{ .x = 0, .y = 1, .z = 0 });

    const face_uvs = [_]blendzig.math.Vec2{
        .{ .x = 0, .y = 0 },
        .{ .x = 1, .y = 0 },
        .{ .x = 1, .y = 1 },
        .{ .x = 0, .y = 1 },
    };
    try mesh.appendFace(&[_]u32{ 0, 1, 2, 3 }, &face_uvs);
    try mesh.appendFace(&[_]u32{ 4, 5, 6, 7 }, &face_uvs);
    try mesh.rebuildEdgesFromFaces();
    return mesh;
}

fn createLooseCleanupMesh(allocator: std.mem.Allocator) !blendzig.mesh.Mesh {
    var mesh = try blendzig.mesh.Mesh.init(allocator);
    errdefer mesh.deinit();

    _ = try mesh.appendVertex(.{ .x = -1, .y = -1, .z = 0 });
    _ = try mesh.appendVertex(.{ .x = 1, .y = -1, .z = 0 });
    _ = try mesh.appendVertex(.{ .x = 1, .y = 1, .z = 0 });
    _ = try mesh.appendVertex(.{ .x = -1, .y = 1, .z = 0 });
    _ = try mesh.appendVertex(.{ .x = 4, .y = 0, .z = 0 });
    _ = try mesh.appendVertex(.{ .x = 5, .y = 0, .z = 0 });
    _ = try mesh.appendVertex(.{ .x = 8, .y = 3, .z = 0 });

    const face_uvs = [_]blendzig.math.Vec2{
        .{ .x = 0, .y = 0 },
        .{ .x = 1, .y = 0 },
        .{ .x = 1, .y = 1 },
        .{ .x = 0, .y = 1 },
    };
    try mesh.appendFace(&[_]u32{ 0, 1, 2, 3 }, &face_uvs);
    try mesh.rebuildEdgesFromFaces();
    try mesh.appendEdge(4, 5);
    return mesh;
}

test "curve tube command builds faces" {
    var mesh = try buildDerivedMeshCommand(std.testing.allocator, "curve-tube");
    defer mesh.deinit();

    try std.testing.expect(mesh.faceCount() > 0);
    try std.testing.expect(mesh.vertexCount() > 0);
}

test "mesh roundtrip command builds a loose-edge mesh" {
    var mesh = try buildDerivedMeshCommand(std.testing.allocator, "mesh-roundtrip");
    defer mesh.deinit();

    try std.testing.expect(mesh.faceCount() == 0);
    try std.testing.expect(mesh.edges.items.len > 0);
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

test "mesh triangulate command triangulates grid faces" {
    var mesh = try buildDerivedMeshCommand(std.testing.allocator, "mesh-triangulate");
    defer mesh.deinit();

    try std.testing.expectEqual(@as(usize, 30), mesh.vertexCount());
    try std.testing.expectEqual(@as(usize, 40), mesh.faceCount());
    try std.testing.expect(mesh.hasCornerUvs());
    for (0..mesh.faceCount()) |face_index| {
        const range = mesh.faceVertexRange(face_index);
        try std.testing.expectEqual(@as(usize, 3), range.end - range.start);
    }
}

test "mesh delete loose command removes non-face topology" {
    var mesh = try buildDerivedMeshCommand(std.testing.allocator, "mesh-delete-loose");
    defer mesh.deinit();

    try std.testing.expectEqual(@as(usize, 4), mesh.vertexCount());
    try std.testing.expectEqual(@as(usize, 1), mesh.faceCount());
    try std.testing.expectEqual(@as(usize, 4), mesh.edges.items.len);
    try std.testing.expect(mesh.hasCornerUvs());
}

test "mesh merge by distance command welds duplicated seam vertices" {
    var mesh = try buildDerivedMeshCommand(std.testing.allocator, "mesh-merge-by-distance");
    defer mesh.deinit();

    try std.testing.expectEqual(@as(usize, 6), mesh.vertexCount());
    try std.testing.expectEqual(@as(usize, 2), mesh.faceCount());
    try std.testing.expectEqual(@as(usize, 7), mesh.edges.items.len);
    try std.testing.expect(mesh.hasCornerUvs());
}

test "mesh inset command builds inset faces with preserved uvs" {
    var mesh = try buildDerivedMeshCommand(std.testing.allocator, "mesh-inset");
    defer mesh.deinit();

    try std.testing.expectEqual(@as(usize, 30), mesh.faceCount());
    try std.testing.expect(mesh.hasCornerUvs());
    try std.testing.expect(mesh.vertexCount() > 0);
}

test "mesh dissolve command merges two quads into one ngon" {
    var mesh = try buildDerivedMeshCommand(std.testing.allocator, "mesh-dissolve");
    defer mesh.deinit();

    try std.testing.expectEqual(@as(usize, 1), mesh.faceCount());
    try std.testing.expectEqual(@as(usize, 6), mesh.vertexCount());
    try std.testing.expectEqual(@as(usize, 6), mesh.edges.items.len);
    try std.testing.expect(mesh.hasCornerUvs());
    try std.testing.expectEqual(@as(usize, 6), mesh.corner_uvs.items.len);
}

test "mesh extrude command builds a capped shell with side walls" {
    var mesh = try buildDerivedMeshCommand(std.testing.allocator, "mesh-extrude");
    defer mesh.deinit();

    try std.testing.expectEqual(@as(usize, 8), mesh.vertexCount());
    try std.testing.expectEqual(@as(usize, 6), mesh.faceCount());
    try std.testing.expectEqual(@as(usize, 12), mesh.edges.items.len);
    try std.testing.expect(mesh.hasCornerUvs());
}

test "mesh planar dissolve command restores a planar quad from two triangles" {
    var mesh = try buildDerivedMeshCommand(std.testing.allocator, "mesh-planar-dissolve");
    defer mesh.deinit();

    try std.testing.expectEqual(@as(usize, 4), mesh.vertexCount());
    try std.testing.expectEqual(@as(usize, 1), mesh.faceCount());
    try std.testing.expectEqual(@as(usize, 4), mesh.edges.items.len);
    try std.testing.expect(mesh.hasCornerUvs());
}

test "mesh subdivide command builds smaller connected quads" {
    var mesh = try buildDerivedMeshCommand(std.testing.allocator, "mesh-subdivide");
    defer mesh.deinit();

    try std.testing.expectEqual(@as(usize, 15), mesh.vertexCount());
    try std.testing.expectEqual(@as(usize, 8), mesh.faceCount());
    try std.testing.expectEqual(@as(usize, 22), mesh.edges.items.len);
    try std.testing.expect(mesh.hasCornerUvs());
}

test "mesh pipeline command can build a chained modeling stack" {
    const steps = [_]blendzig.pipeline.StepSpec{
        .{ .step = .subdivide, .repeat = 2 },
        .{ .step = .extrude, .extrude_distance = 0.75 },
    };
    var mesh = try blendzig.pipeline.runMeshPipeline(std.testing.allocator, .{
        .seed = .grid,
        .verts_x = 8,
        .verts_y = 5,
        .size_x = 4.0,
        .size_y = 2.0,
        .with_uvs = true,
    }, &steps);
    defer mesh.deinit();

    try std.testing.expect(mesh.vertexCount() > 20);
    try std.testing.expect(mesh.faceCount() > 20);
    try std.testing.expect(mesh.hasCornerUvs());
}

test "mesh scene command can build a composed recipe" {
    var temp = std.testing.tmpDir(.{});
    defer temp.cleanup();

    try temp.dir.writeFile(.{
        .sub_path = "floor.bzrecipe",
        .data =
        \\seed=grid:verts-x=3,verts-y=2,size-x=2.0,size-y=1.0,uvs=true
        \\step=triangulate
        ,
    });
    try temp.dir.writeFile(.{
        .sub_path = "block.bzrecipe",
        .data =
        \\seed=cuboid:size-x=1.0,size-y=1.0,size-z=1.0,verts-x=2,verts-y=2,verts-z=2,uvs=true
        \\step=translate:x=3.0,y=0.0,z=0.0
        ,
    });
    try temp.dir.writeFile(.{
        .sub_path = "scene.bzscene",
        .data =
        \\part=floor.bzrecipe
        \\part=block.bzrecipe
        ,
    });

    const scene_path = try temp.dir.realpathAlloc(std.testing.allocator, "scene.bzscene");
    defer std.testing.allocator.free(scene_path);

    var parsed = try blendzig.scene.parseArgs(std.testing.allocator, &[_][]const u8{ "--recipe", scene_path });
    defer parsed.deinit(std.testing.allocator);

    var mesh = try blendzig.scene.runMeshScene(std.testing.allocator, parsed);
    defer mesh.deinit();

    try std.testing.expectEqual(@as(usize, 14), mesh.vertexCount());
    try std.testing.expectEqual(@as(usize, 10), mesh.faceCount());
    try std.testing.expect(mesh.hasCornerUvs());
}

test "mesh output dispatch can write ply files" {
    var temp = std.testing.tmpDir(.{});
    defer temp.cleanup();

    var mesh = try buildPrimitive(std.testing.allocator, "grid");
    defer mesh.deinit();

    const temp_root = try temp.dir.realpathAlloc(std.testing.allocator, ".");
    defer std.testing.allocator.free(temp_root);
    const output_path = try std.fs.path.join(std.testing.allocator, &.{ temp_root, "grid-test.ply" });
    defer std.testing.allocator.free(output_path);

    try writeMeshOutput(&mesh, output_path);

    const bytes = try temp.dir.readFileAlloc(std.testing.allocator, "grid-test.ply", 1024 * 1024);
    defer std.testing.allocator.free(bytes);

    try std.testing.expect(std.mem.startsWith(u8, bytes, "ply\nformat ascii 1.0\n"));
}

test "geometry output dispatch rejects ply for mixed geometry" {
    var geometry = try buildGeometryCommand(std.testing.allocator, "mesh-edges");
    defer geometry.deinit();

    try std.testing.expectError(error.UnsupportedPlyGeometry, writeGeometryOutput(&geometry, "mixed.ply"));
}

test "mesh import reads exported obj and preserves topology counts" {
    var temp = std.testing.tmpDir(.{});
    defer temp.cleanup();

    var mesh = try buildPrimitive(std.testing.allocator, "sphere");
    defer mesh.deinit();

    const temp_root = try temp.dir.realpathAlloc(std.testing.allocator, ".");
    defer std.testing.allocator.free(temp_root);
    const input_path = try std.fs.path.join(std.testing.allocator, &.{ temp_root, "sphere.obj" });
    defer std.testing.allocator.free(input_path);
    try writeMeshOutput(&mesh, input_path);

    var imported = try readImportedMesh(std.testing.allocator, input_path);
    defer imported.deinit();
    switch (imported) {
        .mesh => |*loaded| {
            try std.testing.expectEqual(mesh.vertexCount(), loaded.vertexCount());
            try std.testing.expectEqual(mesh.faceCount(), loaded.faceCount());
            try std.testing.expectEqual(mesh.hasCornerUvs(), loaded.hasCornerUvs());
        },
        .parse_failure => |_| return error.TestUnexpectedResult,
    }
}

test "geometry import reads exported mixed obj and preserves component counts" {
    var temp = std.testing.tmpDir(.{});
    defer temp.cleanup();

    var geometry = try buildGeometryCommand(std.testing.allocator, "mesh-edges");
    defer geometry.deinit();

    const temp_root = try temp.dir.realpathAlloc(std.testing.allocator, ".");
    defer std.testing.allocator.free(temp_root);
    const input_path = try std.fs.path.join(std.testing.allocator, &.{ temp_root, "mixed.obj" });
    defer std.testing.allocator.free(input_path);
    try writeGeometryOutput(&geometry, input_path);

    var imported = try readImportedGeometry(std.testing.allocator, input_path);
    defer imported.deinit();
    switch (imported) {
        .geometry => |*loaded| {
            try std.testing.expect(loaded.mesh != null);
            try std.testing.expect(loaded.curves != null);
            try std.testing.expectEqual(geometry.mesh.?.faceCount(), loaded.mesh.?.faceCount());
            try std.testing.expectEqual(geometry.curves.?.curvesNum(), loaded.curves.?.curvesNum());
            try std.testing.expectEqual(geometry.curves.?.pointsNum(), loaded.curves.?.pointsNum());
        },
        .parse_failure => |_| return error.TestUnexpectedResult,
    }
}

test "mesh import rejects identical input and output paths" {
    try std.testing.expect(try pathsResolveEqual(std.testing.allocator, "zig-out/file.obj", "zig-out/file.obj"));
}

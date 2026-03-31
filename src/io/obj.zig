const std = @import("std");
const curves_mod = @import("../geometry/curves.zig");
const geometry_mod = @import("../geometry/realize_instances.zig");
const math = @import("../math.zig");
const mesh_mod = @import("../mesh.zig");

pub fn write(mesh: *const mesh_mod.Mesh, writer: anytype) !void {
    try writeMeshVertices(mesh, writer);
    try writeMeshUvs(mesh, writer);
    try writeMeshTopology(mesh, writer);
}

pub fn writeGeometry(geometry: *const geometry_mod.GeometrySet, writer: anytype) !void {
    if (geometry.instances != null) return error.UnsupportedInstancesComponent;

    var curve_vertex_offset: u32 = 1;

    if (geometry.mesh) |*mesh| {
        try writeMeshVertices(mesh, writer);
        curve_vertex_offset += @as(u32, @intCast(mesh.vertexCount()));
    }
    if (geometry.curves) |*curves| {
        try writeCurveVertices(curves, writer);
    }
    if (geometry.mesh) |*mesh| {
        try writeMeshUvs(mesh, writer);
        try writeMeshTopology(mesh, writer);
    }
    if (geometry.curves) |*curves| {
        try writeCurveTopology(curves, writer, curve_vertex_offset);
    }
}

fn writeMeshVertices(mesh: *const mesh_mod.Mesh, writer: anytype) !void {
    for (mesh.positions.items) |position| {
        try writer.print("v {} {} {}\n", .{ position.x, position.y, position.z });
    }
}

fn writeMeshUvs(mesh: *const mesh_mod.Mesh, writer: anytype) !void {
    if (mesh.hasCornerUvs()) {
        for (mesh.corner_uvs.items) |uv| {
            try writer.print("vt {} {}\n", .{ uv.x, uv.y });
        }
    }
}

fn writeMeshTopology(mesh: *const mesh_mod.Mesh, writer: anytype) !void {
    for (0..mesh.faceCount()) |face_index| {
        const range = mesh.faceVertexRange(face_index);
        try writer.writeAll("f");
        for (range.start..range.end) |corner_index| {
            const vertex_index = mesh.corner_verts.items[corner_index] + 1;
            if (mesh.hasCornerUvs()) {
                try writer.print(" {d}/{d}", .{ vertex_index, corner_index + 1 });
            } else {
                try writer.print(" {d}", .{vertex_index});
            }
        }
        try writer.writeByte('\n');
    }

    if (mesh.faceCount() == 0) {
        for (mesh.edges.items) |edge| {
            try writer.print("l {d} {d}\n", .{ edge.a + 1, edge.b + 1 });
        }
    }
}

fn writeCurveVertices(curves: *const curves_mod.CurvesGeometry, writer: anytype) !void {
    for (curves.positions.items) |position| {
        try writer.print("v {} {} {}\n", .{ position.x, position.y, position.z });
    }
}

fn writeCurveTopology(curves: *const curves_mod.CurvesGeometry, writer: anytype, vertex_offset: u32) !void {
    for (0..curves.curvesNum()) |curve_index| {
        const range = curves.pointsByCurve(curve_index);
        if (range.len() == 0) continue;

        try writer.writeAll("l");
        for (range.start..range.end) |point_index| {
            try writer.print(" {d}", .{vertex_offset + @as(u32, @intCast(point_index))});
        }
        if (curves.cyclicFlags()[curve_index]) {
            try writer.print(" {d}", .{vertex_offset + range.start});
        }
        try writer.writeByte('\n');
    }
}

pub fn writeFile(mesh: *const mesh_mod.Mesh, path: []const u8) !void {
    const file = try std.fs.cwd().createFile(path, .{ .truncate = true });
    defer file.close();

    var file_buffer: [4096]u8 = undefined;
    var file_writer = file.writer(&file_buffer);
    const writer = &file_writer.interface;
    try write(mesh, writer);
    try writer.flush();
}

pub fn writeGeometryFile(geometry: *const geometry_mod.GeometrySet, path: []const u8) !void {
    const file = try std.fs.cwd().createFile(path, .{ .truncate = true });
    defer file.close();

    var file_buffer: [4096]u8 = undefined;
    var file_writer = file.writer(&file_buffer);
    const writer = &file_writer.interface;
    try writeGeometry(geometry, writer);
    try writer.flush();
}

test "obj writer emits vertices and faces" {
    var mesh = try mesh_mod.Mesh.init(std.testing.allocator);
    defer mesh.deinit();

    _ = try mesh.appendVertex(.{ .x = 0, .y = 0, .z = 0 });
    _ = try mesh.appendVertex(.{ .x = 1, .y = 0, .z = 0 });
    _ = try mesh.appendVertex(.{ .x = 0, .y = 1, .z = 0 });
    try mesh.appendFace(&[_]u32{ 0, 1, 2 }, null);
    try mesh.rebuildEdgesFromFaces();

    var bytes = std.ArrayList(u8).empty;
    defer bytes.deinit(std.testing.allocator);

    try write(&mesh, bytes.writer(std.testing.allocator));
    try std.testing.expect(std.mem.indexOf(u8, bytes.items, "\nf 1 2 3\n") != null);
}

test "obj writer emits geometry sets with mesh and curve components" {
    var mesh = try mesh_mod.Mesh.init(std.testing.allocator);
    _ = try mesh.appendVertex(.{ .x = 0, .y = 0, .z = 0 });
    _ = try mesh.appendVertex(.{ .x = 1, .y = 0, .z = 0 });
    try mesh.appendEdge(0, 1);

    var curves = try curves_mod.CurvesGeometry.init(std.testing.allocator);
    const curve_points = [_]math.Vec3{
        .{ .x = 2, .y = 0, .z = 0 },
        .{ .x = 3, .y = 0, .z = 0 },
        .{ .x = 3, .y = 1, .z = 0 },
    };
    try curves.appendCurve(&curve_points, false, null);

    var geometry = geometry_mod.GeometrySet.fromMeshOwned(std.testing.allocator, mesh);
    geometry.curves = curves;
    defer geometry.deinit();

    var bytes = std.ArrayList(u8).empty;
    defer bytes.deinit(std.testing.allocator);

    try writeGeometry(&geometry, bytes.writer(std.testing.allocator));
    try std.testing.expect(std.mem.indexOf(u8, bytes.items, "\nl 1 2\n") != null);
    try std.testing.expect(std.mem.indexOf(u8, bytes.items, "\nl 3 4 5\n") != null);
}

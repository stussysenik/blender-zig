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

    const primitive = args[1];
    var mesh = try buildPrimitive(allocator, primitive);
    defer mesh.deinit();

    var stdout_buffer: [4096]u8 = undefined;
    var stdout_writer = std.fs.File.stdout().writer(&stdout_buffer);
    const stdout = &stdout_writer.interface;
    try stdout.print(
        "primitive={s} vertices={d} edges={d} faces={d}\n",
        .{ primitive, mesh.vertexCount(), mesh.edges.items.len, mesh.faceCount() },
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
        \\usage: blender-zig <line|grid|cuboid|sphere> [output.obj]
        \\examples:
        \\  zig build run -- sphere
        \\  zig build run -- cuboid zig-out/cuboid.obj
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

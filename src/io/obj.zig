const std = @import("std");
const mesh_mod = @import("../mesh.zig");

pub fn write(mesh: *const mesh_mod.Mesh, writer: anytype) !void {
    for (mesh.positions.items) |position| {
        try writer.print("v {} {} {}\n", .{ position.x, position.y, position.z });
    }

    if (mesh.hasCornerUvs()) {
        for (mesh.corner_uvs.items) |uv| {
            try writer.print("vt {} {}\n", .{ uv.x, uv.y });
        }
    }

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

pub fn writeFile(mesh: *const mesh_mod.Mesh, path: []const u8) !void {
    const file = try std.fs.cwd().createFile(path, .{ .truncate = true });
    defer file.close();

    var file_buffer: [4096]u8 = undefined;
    var file_writer = file.writer(&file_buffer);
    const writer = &file_writer.interface;
    try write(mesh, writer);
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

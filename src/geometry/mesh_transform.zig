const std = @import("std");
const math = @import("../math.zig");
const mesh_mod = @import("../mesh.zig");

// Mesh-space authoring transforms stay separate from the topology operators so the
// rewrite can compose local placement, rotation, and duplication without mixing them
// into higher-level pipeline code yet.
pub const ArrayDuplicateOptions = struct {
    count: usize = 2,
    offset: math.Vec3 = .{ .x = 1.0, .y = 0.0, .z = 0.0 },
};

// Translate is implemented as a copy-on-write helper so the caller gets a fresh mesh
// while the original source remains a stable reference for later pipeline stages.
pub fn translateMesh(
    allocator: std.mem.Allocator,
    mesh: *const mesh_mod.Mesh,
    delta: math.Vec3,
) !mesh_mod.Mesh {
    var result = try mesh.clone(allocator);
    result.translate(delta);
    return result;
}

// Scale works in mesh space around the origin. That keeps the function predictable for
// authoring and avoids hidden pivot logic until the rewrite has a real transform stack.
pub fn scaleMesh(
    allocator: std.mem.Allocator,
    mesh: *const mesh_mod.Mesh,
    scale: math.Vec3,
) !mesh_mod.Mesh {
    var result = try mesh.clone(allocator);
    for (result.positions.items) |*position| {
        position.* = .{
            .x = position.x * scale.x,
            .y = position.y * scale.y,
            .z = position.z * scale.z,
        };
    }
    result.bounds = recomputeBounds(result.positions.items);
    return result;
}

// Z rotation is the first useful rotation slice for the current rewrite because most
// of the generated geometry is still planar and the pipeline currently authors around
// the XY plane.
pub fn rotateMeshZ(
    allocator: std.mem.Allocator,
    mesh: *const mesh_mod.Mesh,
    angle_radians: f32,
) !mesh_mod.Mesh {
    var result = try mesh.clone(allocator);
    const cos_angle = @cos(angle_radians);
    const sin_angle = @sin(angle_radians);

    for (result.positions.items) |*position| {
        const x = position.x * cos_angle - position.y * sin_angle;
        const y = position.x * sin_angle + position.y * cos_angle;
        position.* = .{
            .x = x,
            .y = y,
            .z = position.z,
        };
    }

    result.bounds = recomputeBounds(result.positions.items);
    return result;
}

// Array duplication is the smallest Blender-style repetition helper that still keeps
// the source mesh as the model for every copy. Each instance is cloned, shifted, and
// appended so topology, edges, faces, and corner UVs remain aligned.
pub fn duplicateMeshArray(
    allocator: std.mem.Allocator,
    mesh: *const mesh_mod.Mesh,
    options: ArrayDuplicateOptions,
) !mesh_mod.Mesh {
    if (options.count == 0) return error.InvalidArrayCount;

    var result = try mesh_mod.Mesh.init(allocator);
    errdefer result.deinit();

    for (0..options.count) |copy_index| {
        var copy = try mesh.clone(allocator);
        defer copy.deinit();

        const factor: f32 = @floatFromInt(copy_index);
        copy.translate(options.offset.scale(factor));
        try result.appendMesh(&copy);
    }

    return result;
}

fn recomputeBounds(positions: []const math.Vec3) ?math.Aabb {
    if (positions.len == 0) return null;

    var bounds = math.Aabb.fromPoint(positions[0]);
    for (positions[1..]) |position| {
        bounds.include(position);
    }
    return bounds;
}

test "translateMesh returns a moved copy without touching source topology" {
    var mesh = try mesh_mod.Mesh.init(std.testing.allocator);
    defer mesh.deinit();

    _ = try mesh.appendVertex(.{ .x = 0, .y = 0, .z = 0 });
    _ = try mesh.appendVertex(.{ .x = 1, .y = 0, .z = 0 });
    _ = try mesh.appendVertex(.{ .x = 1, .y = 1, .z = 0 });
    _ = try mesh.appendVertex(.{ .x = 0, .y = 1, .z = 0 });
    try mesh.appendFace(&[_]u32{ 0, 1, 2, 3 }, null);
    try mesh.rebuildEdgesFromFaces();

    var translated = try translateMesh(std.testing.allocator, &mesh, .{ .x = 2, .y = -1, .z = 3 });
    defer translated.deinit();

    try std.testing.expectEqual(mesh.vertexCount(), translated.vertexCount());
    try std.testing.expectEqual(mesh.faceCount(), translated.faceCount());
    try std.testing.expectEqual(mesh.edges.items.len, translated.edges.items.len);
    try std.testing.expect(math.vec3ApproxEq(translated.positions.items[0], .{ .x = 2, .y = -1, .z = 3 }, 0.0001));
    try std.testing.expect(math.vec3ApproxEq(translated.bounds.?.min, .{ .x = 2, .y = -1, .z = 3 }, 0.0001));
    try std.testing.expect(math.vec3ApproxEq(translated.bounds.?.max, .{ .x = 3, .y = 0, .z = 3 }, 0.0001));
    try std.testing.expect(math.vec3ApproxEq(mesh.positions.items[0], .{ .x = 0, .y = 0, .z = 0 }, 0.0001));
}

test "scaleMesh scales positions and bounds in origin space" {
    var mesh = try mesh_mod.Mesh.init(std.testing.allocator);
    defer mesh.deinit();

    _ = try mesh.appendVertex(.{ .x = -1, .y = 2, .z = -3 });
    _ = try mesh.appendVertex(.{ .x = 2, .y = 3, .z = 1 });
    _ = try mesh.appendVertex(.{ .x = 0, .y = 1, .z = 4 });
    try mesh.appendFace(&[_]u32{ 0, 1, 2 }, null);
    try mesh.rebuildEdgesFromFaces();

    var scaled = try scaleMesh(std.testing.allocator, &mesh, .{ .x = 2, .y = -1, .z = 0.5 });
    defer scaled.deinit();

    try std.testing.expectEqual(mesh.faceCount(), scaled.faceCount());
    try std.testing.expect(math.vec3ApproxEq(scaled.positions.items[0], .{ .x = -2, .y = -2, .z = -1.5 }, 0.0001));
    try std.testing.expect(math.vec3ApproxEq(scaled.positions.items[1], .{ .x = 4, .y = -3, .z = 0.5 }, 0.0001));
    try std.testing.expect(math.vec3ApproxEq(scaled.bounds.?.min, .{ .x = -2, .y = -3, .z = -1.5 }, 0.0001));
    try std.testing.expect(math.vec3ApproxEq(scaled.bounds.?.max, .{ .x = 4, .y = -1, .z = 2 }, 0.0001));
}

test "rotateMeshZ rotates the mesh around the origin" {
    var mesh = try mesh_mod.Mesh.init(std.testing.allocator);
    defer mesh.deinit();

    _ = try mesh.appendVertex(.{ .x = 1, .y = 0, .z = 0 });
    _ = try mesh.appendVertex(.{ .x = 0, .y = 1, .z = 0 });
    _ = try mesh.appendVertex(.{ .x = -1, .y = 0, .z = 0 });
    try mesh.appendFace(&[_]u32{ 0, 1, 2 }, null);
    try mesh.rebuildEdgesFromFaces();

    var rotated = try rotateMeshZ(std.testing.allocator, &mesh, std.math.pi / 2.0);
    defer rotated.deinit();

    try std.testing.expect(math.vec3ApproxEq(rotated.positions.items[0], .{ .x = 0, .y = 1, .z = 0 }, 0.0001));
    try std.testing.expect(math.vec3ApproxEq(rotated.positions.items[1], .{ .x = -1, .y = 0, .z = 0 }, 0.0001));
    try std.testing.expect(math.vec3ApproxEq(rotated.positions.items[2], .{ .x = 0, .y = -1, .z = 0 }, 0.0001));
    try std.testing.expect(math.vec3ApproxEq(rotated.bounds.?.min, .{ .x = -1, .y = -1, .z = 0 }, 0.0001));
    try std.testing.expect(math.vec3ApproxEq(rotated.bounds.?.max, .{ .x = 0, .y = 1, .z = 0 }, 0.0001));
}

test "duplicateMeshArray appends repeated copies with offset spacing" {
    var mesh = try mesh_mod.Mesh.init(std.testing.allocator);
    defer mesh.deinit();

    _ = try mesh.appendVertex(.{ .x = 0, .y = 0, .z = 0 });
    _ = try mesh.appendVertex(.{ .x = 1, .y = 0, .z = 0 });
    _ = try mesh.appendVertex(.{ .x = 1, .y = 1, .z = 0 });
    _ = try mesh.appendVertex(.{ .x = 0, .y = 1, .z = 0 });

    const uvs = [_]math.Vec2{
        .{ .x = 0, .y = 0 },
        .{ .x = 1, .y = 0 },
        .{ .x = 1, .y = 1 },
        .{ .x = 0, .y = 1 },
    };
    try mesh.appendFace(&[_]u32{ 0, 1, 2, 3 }, &uvs);
    try mesh.rebuildEdgesFromFaces();

    var duplicated = try duplicateMeshArray(std.testing.allocator, &mesh, .{
        .count = 3,
        .offset = .{ .x = 2, .y = 0, .z = 0 },
    });
    defer duplicated.deinit();

    try std.testing.expectEqual(@as(usize, 12), duplicated.vertexCount());
    try std.testing.expectEqual(@as(usize, 3), duplicated.faceCount());
    try std.testing.expectEqual(@as(usize, 12), duplicated.edges.items.len);
    try std.testing.expect(duplicated.hasCornerUvs());
    try std.testing.expectEqual(@as(usize, 12), duplicated.corner_uvs.items.len);
    try std.testing.expect(math.vec3ApproxEq(duplicated.positions.items[0], .{ .x = 0, .y = 0, .z = 0 }, 0.0001));
    try std.testing.expect(math.vec3ApproxEq(duplicated.positions.items[4], .{ .x = 2, .y = 0, .z = 0 }, 0.0001));
    try std.testing.expect(math.vec3ApproxEq(duplicated.positions.items[8], .{ .x = 4, .y = 0, .z = 0 }, 0.0001));
}

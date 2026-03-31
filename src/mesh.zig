const std = @import("std");
const math = @import("math.zig");

// This is the core polygon container for the rewrite: explicit vertices and edges,
// plus flat face-corner arrays that mirror Blender's topology model closely enough
// for narrow algorithm ports.
pub const Vec2 = math.Vec2;
pub const Vec3 = math.Vec3;
pub const Aabb = math.Aabb;

pub const Edge = struct {
    a: u32,
    b: u32,
};

pub const Mesh = struct {
    allocator: std.mem.Allocator,
    positions: std.ArrayList(Vec3) = .empty,
    edges: std.ArrayList(Edge) = .empty,
    // Faces are stored as slices into the flat corner arrays so face data, edge data,
    // and per-corner attributes stay aligned during ports and remaps.
    face_offsets: std.ArrayList(u32) = .empty,
    corner_verts: std.ArrayList(u32) = .empty,
    corner_edges: std.ArrayList(u32) = .empty,
    corner_uvs: std.ArrayList(Vec2) = .empty,
    bounds: ?Aabb = null,

    pub fn init(allocator: std.mem.Allocator) !Mesh {
        var mesh = Mesh{
            .allocator = allocator,
        };
        try mesh.face_offsets.append(allocator, 0);
        return mesh;
    }

    pub fn deinit(self: *Mesh) void {
        self.positions.deinit(self.allocator);
        self.edges.deinit(self.allocator);
        self.face_offsets.deinit(self.allocator);
        self.corner_verts.deinit(self.allocator);
        self.corner_edges.deinit(self.allocator);
        self.corner_uvs.deinit(self.allocator);
    }

    pub fn clone(self: *const Mesh, allocator: std.mem.Allocator) !Mesh {
        var clone_mesh = try Mesh.init(allocator);
        errdefer clone_mesh.deinit();

        try clone_mesh.positions.appendSlice(allocator, self.positions.items);
        try clone_mesh.edges.appendSlice(allocator, self.edges.items);
        clone_mesh.face_offsets.clearRetainingCapacity();
        try clone_mesh.face_offsets.appendSlice(allocator, self.face_offsets.items);
        try clone_mesh.corner_verts.appendSlice(allocator, self.corner_verts.items);
        try clone_mesh.corner_edges.appendSlice(allocator, self.corner_edges.items);
        try clone_mesh.corner_uvs.appendSlice(allocator, self.corner_uvs.items);
        clone_mesh.bounds = self.bounds;
        return clone_mesh;
    }

    pub fn translate(self: *Mesh, offset: Vec3) void {
        for (self.positions.items) |*position| {
            position.* = position.add(offset);
        }
        if (self.bounds) |*bounds| {
            bounds.min = bounds.min.add(offset);
            bounds.max = bounds.max.add(offset);
        }
    }

    pub fn appendMesh(self: *Mesh, other: *const Mesh) !void {
        const vertex_offset: u32 = @intCast(self.positions.items.len);
        const edge_offset: u32 = @intCast(self.edges.items.len);
        const corner_offset: u32 = @intCast(self.corner_verts.items.len);

        // Append in topology order so the face/corner arrays remain index-compatible
        // after the source mesh is rebased into the destination mesh.
        try self.positions.ensureUnusedCapacity(self.allocator, other.positions.items.len);
        for (other.positions.items) |position| {
            self.positions.appendAssumeCapacity(position);
        }

        try self.edges.ensureUnusedCapacity(self.allocator, other.edges.items.len);
        for (other.edges.items) |edge| {
            self.edges.appendAssumeCapacity(.{
                .a = edge.a + vertex_offset,
                .b = edge.b + vertex_offset,
            });
        }

        try self.corner_verts.ensureUnusedCapacity(self.allocator, other.corner_verts.items.len);
        for (other.corner_verts.items) |vertex| {
            self.corner_verts.appendAssumeCapacity(vertex + vertex_offset);
        }

        try self.corner_edges.ensureUnusedCapacity(self.allocator, other.corner_edges.items.len);
        for (other.corner_edges.items) |edge| {
            self.corner_edges.appendAssumeCapacity(edge + edge_offset);
        }

        if (self.corner_uvs.items.len > 0 or other.corner_uvs.items.len > 0) {
            std.debug.assert(self.corner_uvs.items.len == corner_offset);
            std.debug.assert(other.corner_uvs.items.len == other.corner_verts.items.len);
            try self.corner_uvs.appendSlice(self.allocator, other.corner_uvs.items);
        }

        try self.face_offsets.ensureUnusedCapacity(self.allocator, other.faceCount());
        for (other.face_offsets.items[1..]) |face_offset| {
            self.face_offsets.appendAssumeCapacity(corner_offset + face_offset);
        }

        if (other.bounds) |other_bounds| {
            if (self.bounds) |*bounds| {
                bounds.include(other_bounds.min);
                bounds.include(other_bounds.max);
            } else {
                self.bounds = other_bounds;
            }
        }
    }

    pub fn vertexCount(self: *const Mesh) usize {
        return self.positions.items.len;
    }

    pub fn faceCount(self: *const Mesh) usize {
        return if (self.face_offsets.items.len == 0) 0 else self.face_offsets.items.len - 1;
    }

    pub fn hasCornerUvs(self: *const Mesh) bool {
        return self.corner_uvs.items.len == self.corner_verts.items.len and self.corner_uvs.items.len > 0;
    }

    pub fn appendVertex(self: *Mesh, position: Vec3) !u32 {
        try self.positions.append(self.allocator, position);
        if (self.bounds) |*bounds| {
            bounds.include(position);
        } else {
            self.bounds = Aabb.fromPoint(position);
        }
        return @intCast(self.positions.items.len - 1);
    }

    pub fn appendEdge(self: *Mesh, a: u32, b: u32) !void {
        if (a == b) return;
        try self.edges.append(self.allocator, .{ .a = a, .b = b });
    }

    pub fn appendFace(self: *Mesh, verts: []const u32, maybe_uvs: ?[]const Vec2) !void {
        std.debug.assert(verts.len >= 3);
        if (maybe_uvs) |uvs| {
            std.debug.assert(uvs.len == verts.len);
            try self.corner_uvs.appendSlice(self.allocator, uvs);
        } else {
            std.debug.assert(self.corner_uvs.items.len == 0);
        }

        try self.corner_verts.appendSlice(self.allocator, verts);
        try self.face_offsets.append(self.allocator, @intCast(self.corner_verts.items.len));
    }

    pub fn faceVertexRange(self: *const Mesh, face_index: usize) struct { start: usize, end: usize } {
        std.debug.assert(face_index < self.faceCount());
        return .{
            .start = self.face_offsets.items[face_index],
            .end = self.face_offsets.items[face_index + 1],
        };
    }

    pub fn rebuildEdgesFromFaces(self: *Mesh) !void {
        self.edges.clearRetainingCapacity();
        self.corner_edges.clearRetainingCapacity();

        var lookup = std.AutoHashMap(u64, u32).init(self.allocator);
        defer lookup.deinit();

        // Rebuild a unique undirected edge table from the face corners so ports can
        // author faces first and derive edge connectivity afterwards.
        for (0..self.faceCount()) |face_index| {
            const range = self.faceVertexRange(face_index);
            const face_corners = self.corner_verts.items[range.start..range.end];
            for (face_corners, 0..) |vert, local_index| {
                const next = face_corners[(local_index + 1) % face_corners.len];
                const key = packUndirectedEdge(vert, next);
                const edge_index = if (lookup.get(key)) |existing| blk: {
                    break :blk existing;
                } else blk: {
                    const fresh_index: u32 = @intCast(self.edges.items.len);
                    try self.edges.append(self.allocator, .{ .a = @min(vert, next), .b = @max(vert, next) });
                    try lookup.put(key, fresh_index);
                    break :blk fresh_index;
                };
                try self.corner_edges.append(self.allocator, edge_index);
            }
        }
    }
};

fn packUndirectedEdge(a: u32, b: u32) u64 {
    const lo = @min(a, b);
    const hi = @max(a, b);
    return (@as(u64, hi) << 32) | @as(u64, lo);
}

test "mesh rebuilds unique edges" {
    var mesh = try Mesh.init(std.testing.allocator);
    defer mesh.deinit();

    _ = try mesh.appendVertex(Vec3.init(-1, -1, 0));
    _ = try mesh.appendVertex(Vec3.init(1, -1, 0));
    _ = try mesh.appendVertex(Vec3.init(1, 1, 0));
    _ = try mesh.appendVertex(Vec3.init(-1, 1, 0));

    try mesh.appendFace(&[_]u32{ 0, 1, 2, 3 }, null);
    try mesh.rebuildEdgesFromFaces();

    try std.testing.expectEqual(@as(usize, 4), mesh.edges.items.len);
    try std.testing.expectEqual(@as(usize, 4), mesh.corner_edges.items.len);
}

test "mesh clone and translate preserve topology while moving bounds" {
    var mesh = try Mesh.init(std.testing.allocator);
    defer mesh.deinit();

    _ = try mesh.appendVertex(Vec3.init(0, 0, 0));
    _ = try mesh.appendVertex(Vec3.init(1, 0, 0));
    _ = try mesh.appendVertex(Vec3.init(1, 1, 0));
    try mesh.appendFace(&[_]u32{ 0, 1, 2 }, null);
    try mesh.rebuildEdgesFromFaces();

    var clone_mesh = try mesh.clone(std.testing.allocator);
    defer clone_mesh.deinit();

    clone_mesh.translate(Vec3.init(2, -1, 3));

    try std.testing.expectEqual(mesh.vertexCount(), clone_mesh.vertexCount());
    try std.testing.expectEqual(mesh.faceCount(), clone_mesh.faceCount());
    try std.testing.expect(math.vec3ApproxEq(clone_mesh.positions.items[0], Vec3.init(2, -1, 3), 0.0001));
    try std.testing.expect(math.vec3ApproxEq(clone_mesh.bounds.?.min, Vec3.init(2, -1, 3), 0.0001));
    try std.testing.expect(math.vec3ApproxEq(clone_mesh.bounds.?.max, Vec3.init(3, 0, 3), 0.0001));
}

test "mesh append combines topology with index remapping" {
    var left = try Mesh.init(std.testing.allocator);
    defer left.deinit();
    _ = try left.appendVertex(Vec3.init(0, 0, 0));
    _ = try left.appendVertex(Vec3.init(1, 0, 0));
    try left.appendEdge(0, 1);

    var right = try Mesh.init(std.testing.allocator);
    defer right.deinit();
    _ = try right.appendVertex(Vec3.init(5, 0, 0));
    _ = try right.appendVertex(Vec3.init(6, 0, 0));
    _ = try right.appendVertex(Vec3.init(6, 1, 0));
    try right.appendFace(&[_]u32{ 0, 1, 2 }, null);
    try right.rebuildEdgesFromFaces();

    try left.appendMesh(&right);

    try std.testing.expectEqual(@as(usize, 5), left.vertexCount());
    try std.testing.expectEqual(@as(usize, 1), left.faceCount());
    try std.testing.expectEqual(@as(usize, 4), left.edges.items.len);
    try std.testing.expectEqual(@as(u32, 2), left.corner_verts.items[0]);
    try std.testing.expect(math.vec3ApproxEq(left.bounds.?.max, Vec3.init(6, 1, 0), 0.0001));
}

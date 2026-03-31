const std = @import("std");
const curves_mod = @import("../geometry/curves.zig");
const geometry_mod = @import("../geometry/realize_instances.zig");
const math = @import("../math.zig");
const mesh_mod = @import("../mesh.zig");

pub const RecordKind = enum {
    vertex,
    texcoord,
    face,
    line,
    metadata,
    unknown,

    pub fn label(self: RecordKind) []const u8 {
        return switch (self) {
            .vertex => "v",
            .texcoord => "vt",
            .face => "f",
            .line => "l",
            .metadata => "metadata",
            .unknown => "unknown",
        };
    }
};

pub const ParseFailure = struct {
    line_number: usize,
    record_kind: RecordKind,
    cause: anyerror,
};

pub const ReadResult = union(enum) {
    mesh: mesh_mod.Mesh,
    parse_failure: ParseFailure,

    pub fn deinit(self: *ReadResult) void {
        switch (self.*) {
            .mesh => |*mesh| mesh.deinit(),
            .parse_failure => {},
        }
    }
};

pub const GeometryReadResult = union(enum) {
    geometry: geometry_mod.GeometrySet,
    parse_failure: ParseFailure,

    pub fn deinit(self: *GeometryReadResult) void {
        switch (self.*) {
            .geometry => |*geometry| geometry.deinit(),
            .parse_failure => {},
        }
    }
};

const ParsedGeometryTopology = struct {
    allocator: std.mem.Allocator,
    positions: std.ArrayList(math.Vec3) = .empty,
    texcoords: std.ArrayList(math.Vec2) = .empty,
    face_offsets: std.ArrayList(u32) = .empty,
    face_vertices: std.ArrayList(u32) = .empty,
    face_uvs: std.ArrayList(math.Vec2) = .empty,
    line_offsets: std.ArrayList(u32) = .empty,
    line_vertices: std.ArrayList(u32) = .empty,
    mesh_uses_uvs: ?bool = null,

    fn init(allocator: std.mem.Allocator) !ParsedGeometryTopology {
        var topology = ParsedGeometryTopology{
            .allocator = allocator,
        };
        try topology.face_offsets.append(allocator, 0);
        try topology.line_offsets.append(allocator, 0);
        return topology;
    }

    fn deinit(self: *ParsedGeometryTopology) void {
        self.positions.deinit(self.allocator);
        self.texcoords.deinit(self.allocator);
        self.face_offsets.deinit(self.allocator);
        self.face_vertices.deinit(self.allocator);
        self.face_uvs.deinit(self.allocator);
        self.line_offsets.deinit(self.allocator);
        self.line_vertices.deinit(self.allocator);
    }

    fn faceCount(self: *const ParsedGeometryTopology) usize {
        return if (self.face_offsets.items.len == 0) 0 else self.face_offsets.items.len - 1;
    }

    fn lineCount(self: *const ParsedGeometryTopology) usize {
        return if (self.line_offsets.items.len == 0) 0 else self.line_offsets.items.len - 1;
    }
};

// OBJ is the current inspection format for the rewrite: simple, ubiquitous, and a
// good fit for the mesh-plus-curves model without claiming Blender file parity.
pub fn write(mesh: *const mesh_mod.Mesh, writer: anytype) !void {
    try writeMeshVertices(mesh, writer);
    try writeMeshUvs(mesh, writer);
    try writeMeshTopology(mesh, writer);
}

pub fn writeGeometry(geometry: *const geometry_mod.GeometrySet, writer: anytype) !void {
    if (geometry.instances != null) return error.UnsupportedInstancesComponent;

    var curve_vertex_offset: u32 = 1;

    // Write mesh vertices first so curve line indices can be offset into the combined
    // vertex stream when both components exist in one GeometrySet.
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

// The importer stays intentionally narrow: ASCII OBJ mesh records only. It accepts
// `v`, `vt`, `f`, and `l`, ignores common metadata records, and rejects features that
// would widen the rewrite toward a full scene/object parser.
pub fn readBytes(allocator: std.mem.Allocator, bytes: []const u8) !ReadResult {
    var mesh = try mesh_mod.Mesh.init(allocator);
    errdefer mesh.deinit();

    var texcoords = std.ArrayList(math.Vec2).empty;
    defer texcoords.deinit(allocator);

    var saw_faces = false;
    var saw_lines = false;
    var mesh_uses_uvs: ?bool = null;

    var lines = std.mem.splitScalar(u8, bytes, '\n');
    var line_number: usize = 0;
    while (lines.next()) |raw_line| {
        line_number += 1;
        const content = stripInlineComment(raw_line);
        const line = std.mem.trim(u8, content, " \t\r");
        if (line.len == 0) continue;
        for (line) |byte| {
            if (!std.ascii.isAscii(byte)) {
                return parseFailure(&mesh, line_number, .unknown, error.NonAsciiObjRecord);
            }
        }

        var fields = std.mem.tokenizeAny(u8, line, " \t");
        const record = fields.next() orelse continue;
        const rest = std.mem.trimLeft(u8, line[record.len..], " \t");
        const kind = classifyRecord(record);

        switch (kind) {
            .vertex => parseVertexRecord(&mesh, rest) catch |err| {
                return parseFailure(&mesh, line_number, .vertex, err);
            },
            .texcoord => parseTexcoordRecord(&texcoords, allocator, rest) catch |err| {
                return parseFailure(&mesh, line_number, .texcoord, err);
            },
            .face => {
                if (saw_lines) {
                    return parseFailure(&mesh, line_number, .face, error.MixedObjTopologyRecords);
                }
                parseFaceRecord(&mesh, &texcoords, rest, &mesh_uses_uvs) catch |err| {
                    return parseFailure(&mesh, line_number, .face, err);
                };
                saw_faces = true;
            },
            .line => {
                if (saw_faces) {
                    return parseFailure(&mesh, line_number, .line, error.MixedObjTopologyRecords);
                }
                parseLineRecord(&mesh, rest) catch |err| {
                    return parseFailure(&mesh, line_number, .line, err);
                };
                saw_lines = true;
            },
            .metadata => continue,
            .unknown => return parseFailure(&mesh, line_number, .unknown, error.UnsupportedObjRecord),
        }
    }

    if (saw_faces) {
        try mesh.rebuildEdgesFromFaces();
    }

    return .{ .mesh = mesh };
}

pub fn readFile(allocator: std.mem.Allocator, path: []const u8) !ReadResult {
    const bytes = try std.fs.cwd().readFileAlloc(allocator, path, 64 * 1024 * 1024);
    defer allocator.free(bytes);
    return readBytes(allocator, bytes);
}

// Mixed OBJ import is intentionally narrower than Blender's scene importer. It keeps
// only the geometry signals this rewrite can roundtrip today: faces become mesh data
// and line records become curve splines inside one GeometrySet.
pub fn readGeometryBytes(allocator: std.mem.Allocator, bytes: []const u8) !GeometryReadResult {
    var topology = try ParsedGeometryTopology.init(allocator);
    errdefer topology.deinit();

    var lines = std.mem.splitScalar(u8, bytes, '\n');
    var line_number: usize = 0;
    while (lines.next()) |raw_line| {
        line_number += 1;
        const content = stripInlineComment(raw_line);
        const line = std.mem.trim(u8, content, " \t\r");
        if (line.len == 0) continue;
        for (line) |byte| {
            if (!std.ascii.isAscii(byte)) {
                return geometryParseFailure(&topology, line_number, .unknown, error.NonAsciiObjRecord);
            }
        }

        var fields = std.mem.tokenizeAny(u8, line, " \t");
        const record = fields.next() orelse continue;
        const rest = std.mem.trimLeft(u8, line[record.len..], " \t");
        const kind = classifyRecord(record);

        switch (kind) {
            .vertex => parseGeometryVertexRecord(&topology, rest) catch |err| {
                return geometryParseFailure(&topology, line_number, .vertex, err);
            },
            .texcoord => parseGeometryTexcoordRecord(&topology, rest) catch |err| {
                return geometryParseFailure(&topology, line_number, .texcoord, err);
            },
            .face => parseGeometryFaceRecord(&topology, rest) catch |err| {
                return geometryParseFailure(&topology, line_number, .face, err);
            },
            .line => parseGeometryLineRecord(&topology, rest) catch |err| {
                return geometryParseFailure(&topology, line_number, .line, err);
            },
            .metadata => continue,
            .unknown => return geometryParseFailure(&topology, line_number, .unknown, error.UnsupportedObjRecord),
        }
    }

    const geometry = try buildGeometryFromTopology(allocator, &topology);
    topology.deinit();
    return .{ .geometry = geometry };
}

pub fn readGeometryFile(allocator: std.mem.Allocator, path: []const u8) !GeometryReadResult {
    const bytes = try std.fs.cwd().readFileAlloc(allocator, path, 64 * 1024 * 1024);
    defer allocator.free(bytes);
    return readGeometryBytes(allocator, bytes);
}

fn parseFailure(mesh: *mesh_mod.Mesh, line_number: usize, record_kind: RecordKind, cause: anyerror) ReadResult {
    mesh.deinit();
    return .{
        .parse_failure = .{
            .line_number = line_number,
            .record_kind = record_kind,
            .cause = cause,
        },
    };
}

fn geometryParseFailure(
    topology: *ParsedGeometryTopology,
    line_number: usize,
    record_kind: RecordKind,
    cause: anyerror,
) GeometryReadResult {
    topology.deinit();
    return .{
        .parse_failure = .{
            .line_number = line_number,
            .record_kind = record_kind,
            .cause = cause,
        },
    };
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

fn stripInlineComment(line: []const u8) []const u8 {
    const comment_index = std.mem.indexOfScalar(u8, line, '#') orelse return line;
    return line[0..comment_index];
}

fn classifyRecord(record: []const u8) RecordKind {
    if (std.mem.eql(u8, record, "v")) return .vertex;
    if (std.mem.eql(u8, record, "vt")) return .texcoord;
    if (std.mem.eql(u8, record, "f")) return .face;
    if (std.mem.eql(u8, record, "l")) return .line;
    if (std.mem.eql(u8, record, "o") or std.mem.eql(u8, record, "g") or std.mem.eql(u8, record, "s") or std.mem.eql(u8, record, "usemtl") or std.mem.eql(u8, record, "mtllib") or std.mem.eql(u8, record, "vn")) {
        return .metadata;
    }
    return .unknown;
}

fn parseVertexRecord(mesh: *mesh_mod.Mesh, fields: []const u8) !void {
    var tokens = std.mem.tokenizeAny(u8, fields, " \t");
    const x = try parseRequiredFloat(&tokens);
    const y = try parseRequiredFloat(&tokens);
    const z = try parseRequiredFloat(&tokens);
    _ = tokens.next();
    _ = try mesh.appendVertex(.{ .x = x, .y = y, .z = z });
}

fn parseTexcoordRecord(texcoords: *std.ArrayList(math.Vec2), allocator: std.mem.Allocator, fields: []const u8) !void {
    var tokens = std.mem.tokenizeAny(u8, fields, " \t");
    const u = try parseRequiredFloat(&tokens);
    const v = try parseRequiredFloat(&tokens);
    _ = tokens.next();
    try texcoords.append(allocator, .{ .x = u, .y = v });
}

fn parseFaceRecord(
    mesh: *mesh_mod.Mesh,
    texcoords: *const std.ArrayList(math.Vec2),
    fields: []const u8,
    mesh_uses_uvs: *?bool,
) !void {
    var verts = std.ArrayList(u32).empty;
    defer verts.deinit(mesh.allocator);

    var face_uvs = std.ArrayList(math.Vec2).empty;
    defer face_uvs.deinit(mesh.allocator);

    var tokens = std.mem.tokenizeAny(u8, fields, " \t");
    var saw_corner = false;
    var face_has_uvs = false;
    while (tokens.next()) |corner_text| {
        const corner = try parseFaceCorner(corner_text, mesh.vertexCount(), texcoords.items.len);
        try verts.append(mesh.allocator, corner.vertex);
        if (corner.uv) |uv_index| {
            if (!saw_corner) {
                face_has_uvs = true;
            } else if (!face_has_uvs) {
                return error.MixedObjFaceUvCoverage;
            }
            try face_uvs.append(mesh.allocator, texcoords.items[uv_index]);
        } else if (saw_corner and face_has_uvs) {
            return error.MixedObjFaceUvCoverage;
        }
        saw_corner = true;
    }

    if (verts.items.len < 3) return error.InvalidObjFaceArity;

    if (mesh_uses_uvs.*) |uses_uvs| {
        if (uses_uvs != face_has_uvs) return error.MixedObjMeshUvCoverage;
    } else {
        mesh_uses_uvs.* = face_has_uvs;
    }

    const maybe_uvs: ?[]const math.Vec2 = if (face_has_uvs) face_uvs.items else null;
    try mesh.appendFace(verts.items, maybe_uvs);
}

fn parseLineRecord(mesh: *mesh_mod.Mesh, fields: []const u8) !void {
    var tokens = std.mem.tokenizeAny(u8, fields, " \t");
    var previous: ?u32 = null;
    var count: usize = 0;

    while (tokens.next()) |token| {
        const vertex = try parseLineVertex(token, mesh.vertexCount());
        if (previous) |prior| {
            try mesh.appendEdge(prior, vertex);
        }
        previous = vertex;
        count += 1;
    }

    if (count < 2) return error.InvalidObjLineArity;
}

fn parseGeometryVertexRecord(topology: *ParsedGeometryTopology, fields: []const u8) !void {
    var tokens = std.mem.tokenizeAny(u8, fields, " \t");
    const x = try parseRequiredFloat(&tokens);
    const y = try parseRequiredFloat(&tokens);
    const z = try parseRequiredFloat(&tokens);
    _ = tokens.next();
    try topology.positions.append(topology.allocator, .{ .x = x, .y = y, .z = z });
}

fn parseGeometryTexcoordRecord(topology: *ParsedGeometryTopology, fields: []const u8) !void {
    var tokens = std.mem.tokenizeAny(u8, fields, " \t");
    const u = try parseRequiredFloat(&tokens);
    const v = try parseRequiredFloat(&tokens);
    _ = tokens.next();
    try topology.texcoords.append(topology.allocator, .{ .x = u, .y = v });
}

fn parseGeometryFaceRecord(topology: *ParsedGeometryTopology, fields: []const u8) !void {
    var verts = std.ArrayList(u32).empty;
    defer verts.deinit(topology.allocator);

    var face_uvs = std.ArrayList(math.Vec2).empty;
    defer face_uvs.deinit(topology.allocator);

    var tokens = std.mem.tokenizeAny(u8, fields, " \t");
    var saw_corner = false;
    var face_has_uvs = false;
    while (tokens.next()) |corner_text| {
        const corner = try parseFaceCorner(corner_text, topology.positions.items.len, topology.texcoords.items.len);
        try verts.append(topology.allocator, corner.vertex);
        if (corner.uv) |uv_index| {
            if (!saw_corner) {
                face_has_uvs = true;
            } else if (!face_has_uvs) {
                return error.MixedObjFaceUvCoverage;
            }
            try face_uvs.append(topology.allocator, topology.texcoords.items[uv_index]);
        } else if (saw_corner and face_has_uvs) {
            return error.MixedObjFaceUvCoverage;
        }
        saw_corner = true;
    }

    if (verts.items.len < 3) return error.InvalidObjFaceArity;

    if (topology.mesh_uses_uvs) |uses_uvs| {
        if (uses_uvs != face_has_uvs) return error.MixedObjMeshUvCoverage;
    } else {
        topology.mesh_uses_uvs = face_has_uvs;
    }

    try topology.face_vertices.appendSlice(topology.allocator, verts.items);
    if (face_has_uvs) {
        try topology.face_uvs.appendSlice(topology.allocator, face_uvs.items);
    }
    try topology.face_offsets.append(topology.allocator, @intCast(topology.face_vertices.items.len));
}

fn parseGeometryLineRecord(topology: *ParsedGeometryTopology, fields: []const u8) !void {
    var tokens = std.mem.tokenizeAny(u8, fields, " \t");
    var count: usize = 0;

    while (tokens.next()) |token| {
        const vertex = try parseLineVertex(token, topology.positions.items.len);
        try topology.line_vertices.append(topology.allocator, vertex);
        count += 1;
    }

    if (count < 2) return error.InvalidObjLineArity;
    try topology.line_offsets.append(topology.allocator, @intCast(topology.line_vertices.items.len));
}

const FaceCorner = struct {
    vertex: u32,
    uv: ?u32,
};

fn parseFaceCorner(token: []const u8, max_vertices: usize, max_texcoords: usize) !FaceCorner {
    var parts = std.mem.splitScalar(u8, token, '/');
    const vertex_text = parts.first();
    const uv_text = parts.next();
    _ = parts.next();
    if (parts.next() != null) return error.InvalidObjFaceCorner;

    return .{
        .vertex = try parsePositiveObjIndex(vertex_text, max_vertices),
        .uv = if (uv_text) |text|
            if (text.len == 0) null else try parsePositiveObjIndex(text, max_texcoords)
        else
            null,
    };
}

fn parseLineVertex(token: []const u8, max_vertices: usize) !u32 {
    const slash_index = std.mem.indexOfScalar(u8, token, '/') orelse return parsePositiveObjIndex(token, max_vertices);
    return parsePositiveObjIndex(token[0..slash_index], max_vertices);
}

fn parsePositiveObjIndex(text: []const u8, max_index: usize) !u32 {
    if (text.len == 0) return error.InvalidObjIndex;
    const raw_value = try std.fmt.parseInt(i64, text, 10);
    if (raw_value < 0) return error.UnsupportedObjRelativeIndex;
    if (raw_value == 0) return error.InvalidObjIndex;
    if (raw_value > max_index) return error.ObjIndexOutOfRange;
    return @intCast(raw_value - 1);
}

fn parseRequiredFloat(tokens: anytype) !f32 {
    const text = tokens.next() orelse return error.InvalidObjFloatArity;
    return std.fmt.parseFloat(f32, text);
}

fn buildGeometryFromTopology(
    allocator: std.mem.Allocator,
    topology: *const ParsedGeometryTopology,
) !geometry_mod.GeometrySet {
    var geometry = geometry_mod.GeometrySet.init(allocator);
    errdefer geometry.deinit();

    geometry.mesh = try buildMeshFromTopology(allocator, topology);
    geometry.curves = try buildCurvesFromTopology(allocator, topology);
    return geometry;
}

fn buildMeshFromTopology(
    allocator: std.mem.Allocator,
    topology: *const ParsedGeometryTopology,
) !?mesh_mod.Mesh {
    if (topology.faceCount() == 0) return null;

    var mesh = try mesh_mod.Mesh.init(allocator);
    errdefer mesh.deinit();

    const global_to_local = try allocator.alloc(i32, topology.positions.items.len);
    defer allocator.free(global_to_local);
    for (global_to_local) |*slot| {
        slot.* = -1;
    }

    var remapped_verts = std.ArrayList(u32).empty;
    defer remapped_verts.deinit(allocator);

    const mesh_has_uvs = topology.mesh_uses_uvs orelse false;
    if (mesh_has_uvs) {
        std.debug.assert(topology.face_vertices.items.len == topology.face_uvs.items.len);
    }

    for (0..topology.faceCount()) |face_index| {
        const start = topology.face_offsets.items[face_index];
        const end = topology.face_offsets.items[face_index + 1];
        remapped_verts.clearRetainingCapacity();

        for (topology.face_vertices.items[start..end]) |global_vertex| {
            var local_vertex = global_to_local[global_vertex];
            if (local_vertex < 0) {
                const appended = try mesh.appendVertex(topology.positions.items[global_vertex]);
                local_vertex = @intCast(appended);
                global_to_local[global_vertex] = local_vertex;
            }
            try remapped_verts.append(allocator, @intCast(local_vertex));
        }

        const maybe_uvs: ?[]const math.Vec2 = if (mesh_has_uvs)
            topology.face_uvs.items[start..end]
        else
            null;
        try mesh.appendFace(remapped_verts.items, maybe_uvs);
    }

    try mesh.rebuildEdgesFromFaces();
    return mesh;
}

fn buildCurvesFromTopology(
    allocator: std.mem.Allocator,
    topology: *const ParsedGeometryTopology,
) !?curves_mod.CurvesGeometry {
    if (topology.lineCount() == 0) return null;

    var curves = try curves_mod.CurvesGeometry.init(allocator);
    errdefer curves.deinit();

    var points = std.ArrayList(math.Vec3).empty;
    defer points.deinit(allocator);

    for (0..topology.lineCount()) |line_index| {
        const start = topology.line_offsets.items[line_index];
        const end = topology.line_offsets.items[line_index + 1];
        const line_vertices = topology.line_vertices.items[start..end];

        var point_limit = line_vertices.len;
        const is_cyclic = line_vertices.len >= 3 and line_vertices[0] == line_vertices[line_vertices.len - 1];
        if (is_cyclic) {
            point_limit -= 1;
        }
        if (point_limit < 2) return error.InvalidObjLineArity;

        points.clearRetainingCapacity();
        for (line_vertices[0..point_limit]) |global_vertex| {
            try points.append(allocator, topology.positions.items[global_vertex]);
        }
        try curves.appendCurve(points.items, is_cyclic, null);
    }

    return curves;
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

test "obj reader imports ngons with uv corners" {
    const source =
        \\o quad
        \\v 0 0 0
        \\v 1 0 0
        \\v 1 1 0
        \\v 0 1 0
        \\vt 0 0
        \\vt 1 0
        \\vt 1 1
        \\vt 0 1
        \\f 1/1 2/2 3/3 4/4
        \\
    ;

    var result = try readBytes(std.testing.allocator, source);
    defer result.deinit();

    switch (result) {
        .mesh => |*mesh| {
            try std.testing.expectEqual(@as(usize, 4), mesh.vertexCount());
            try std.testing.expectEqual(@as(usize, 1), mesh.faceCount());
            try std.testing.expectEqual(@as(usize, 4), mesh.edges.items.len);
            try std.testing.expect(mesh.hasCornerUvs());
        },
        .parse_failure => |_| return error.TestUnexpectedResult,
    }
}

test "obj reader imports line-only meshes" {
    const source =
        \\v 0 0 0
        \\v 1 0 0
        \\v 1 1 0
        \\l 1 2 3
        \\
    ;

    var result = try readBytes(std.testing.allocator, source);
    defer result.deinit();

    switch (result) {
        .mesh => |*mesh| {
            try std.testing.expectEqual(@as(usize, 3), mesh.vertexCount());
            try std.testing.expectEqual(@as(usize, 0), mesh.faceCount());
            try std.testing.expectEqual(@as(usize, 2), mesh.edges.items.len);
        },
        .parse_failure => |_| return error.TestUnexpectedResult,
    }
}

test "obj geometry reader imports mixed mesh and curve components" {
    const source =
        \\o mixed
        \\v 0 0 0
        \\v 1 0 0
        \\v 1 1 0
        \\v 0 1 0
        \\v 2 0 0
        \\v 3 0 0
        \\v 3 1 0
        \\f 1 2 3 4
        \\l 5 6 7
        \\
    ;

    var result = try readGeometryBytes(std.testing.allocator, source);
    defer result.deinit();

    switch (result) {
        .geometry => |*geometry| {
            try std.testing.expect(geometry.mesh != null);
            try std.testing.expect(geometry.curves != null);
            try std.testing.expectEqual(@as(usize, 4), geometry.mesh.?.vertexCount());
            try std.testing.expectEqual(@as(usize, 1), geometry.mesh.?.faceCount());
            try std.testing.expectEqual(@as(usize, 3), geometry.curves.?.pointsNum());
            try std.testing.expectEqual(@as(usize, 1), geometry.curves.?.curvesNum());
        },
        .parse_failure => |_| return error.TestUnexpectedResult,
    }
}

test "obj geometry reader imports cyclic lines as cyclic curves" {
    const source =
        \\v 0 0 0
        \\v 1 0 0
        \\v 1 1 0
        \\l 1 2 3 1
        \\
    ;

    var result = try readGeometryBytes(std.testing.allocator, source);
    defer result.deinit();

    switch (result) {
        .geometry => |*geometry| {
            try std.testing.expect(geometry.mesh == null);
            try std.testing.expect(geometry.curves != null);
            try std.testing.expectEqual(@as(usize, 3), geometry.curves.?.pointsNum());
            try std.testing.expectEqual(@as(usize, 1), geometry.curves.?.curvesNum());
            try std.testing.expectEqual(true, geometry.curves.?.cyclicFlags()[0]);
        },
        .parse_failure => |_| return error.TestUnexpectedResult,
    }
}

test "obj reader rejects mixed face uv coverage" {
    const source =
        \\v 0 0 0
        \\v 1 0 0
        \\v 1 1 0
        \\vt 0 0
        \\vt 1 0
        \\vt 1 1
        \\f 1/1 2 3/3
        \\
    ;

    var result = try readBytes(std.testing.allocator, source);
    switch (result) {
        .mesh => |*mesh| {
            mesh.deinit();
            return error.TestUnexpectedResult;
        },
        .parse_failure => |failure| {
            try std.testing.expectEqual(@as(usize, 7), failure.line_number);
            try std.testing.expectEqual(RecordKind.face, failure.record_kind);
            try std.testing.expectEqual(error.MixedObjFaceUvCoverage, failure.cause);
        },
    }
}

test "obj reader rejects mixed topology records" {
    const source =
        \\v 0 0 0
        \\v 1 0 0
        \\v 1 1 0
        \\f 1 2 3
        \\l 1 2
        \\
    ;

    var result = try readBytes(std.testing.allocator, source);
    switch (result) {
        .mesh => |*mesh| {
            mesh.deinit();
            return error.TestUnexpectedResult;
        },
        .parse_failure => |failure| {
            try std.testing.expectEqual(@as(usize, 5), failure.line_number);
            try std.testing.expectEqual(RecordKind.line, failure.record_kind);
            try std.testing.expectEqual(error.MixedObjTopologyRecords, failure.cause);
        },
    }
}

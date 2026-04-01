const std = @import("std");
const curves_mod = @import("geometry/curves.zig");
const geometry_mod = @import("geometry/realize_instances.zig");
const math = @import("math.zig");
const mesh_mod = @import("mesh.zig");
const obj = @import("io/obj.zig");
const replay_metadata = @import("replay_metadata.zig");

pub const manifest_filename = "manifest.bzmanifest";
pub const geometry_filename = "geometry.obj";

pub const GeometryComponents = struct {
    mesh: bool = false,
    curves: bool = false,

    pub fn fromGeometry(geometry: *const geometry_mod.GeometrySet) !GeometryComponents {
        if (geometry.instances != null) return error.UnsupportedBundleInstances;

        const components = GeometryComponents{
            .mesh = geometry.mesh != null,
            .curves = geometry.curves != null,
        };
        if (!components.mesh and !components.curves) return error.EmptyBundleGeometry;
        return components;
    }

    pub fn eql(self: GeometryComponents, other: GeometryComponents) bool {
        return self.mesh == other.mesh and self.curves == other.curves;
    }

    pub fn label(self: GeometryComponents) []const u8 {
        if (self.mesh and self.curves) return "mesh,curves";
        if (self.mesh) return "mesh";
        if (self.curves) return "curves";
        return "empty";
    }

    pub fn parse(text: []const u8) !GeometryComponents {
        var components = GeometryComponents{};
        var tokens = std.mem.splitScalar(u8, text, ',');
        while (tokens.next()) |raw_token| {
            const token = std.mem.trim(u8, raw_token, " \t");
            if (token.len == 0) return error.InvalidBundleComponents;

            if (std.mem.eql(u8, token, "mesh")) {
                if (components.mesh) return error.InvalidBundleComponents;
                components.mesh = true;
                continue;
            }
            if (std.mem.eql(u8, token, "curves")) {
                if (components.curves) return error.InvalidBundleComponents;
                components.curves = true;
                continue;
            }
            return error.InvalidBundleComponents;
        }

        if (!components.mesh and !components.curves) return error.InvalidBundleComponents;
        return components;
    }
};

pub const ParsedBundle = struct {
    metadata: replay_metadata.ReplayMetadata = .{},
    components: GeometryComponents,
    geometry: geometry_mod.GeometrySet,
    owned_manifest_text: []u8,

    pub fn deinit(self: *ParsedBundle, allocator: std.mem.Allocator) void {
        self.geometry.deinit();
        allocator.free(self.owned_manifest_text);
    }
};

pub fn writeBundle(
    allocator: std.mem.Allocator,
    bundle_path: []const u8,
    geometry: *const geometry_mod.GeometrySet,
    metadata: replay_metadata.ReplayMetadata,
) !void {
    if (metadata.format_version != 1) return error.UnsupportedReplayFormatVersion;

    const components = try GeometryComponents.fromGeometry(geometry);

    try std.fs.cwd().makePath(bundle_path);

    const manifest_path = try std.fs.path.join(allocator, &.{ bundle_path, manifest_filename });
    defer allocator.free(manifest_path);
    const geometry_path = try std.fs.path.join(allocator, &.{ bundle_path, geometry_filename });
    defer allocator.free(geometry_path);

    try obj.writeGeometryFile(geometry, geometry_path);

    const file = try std.fs.cwd().createFile(manifest_path, .{ .truncate = true });
    defer file.close();

    var file_buffer: [4096]u8 = undefined;
    var file_writer = file.writer(&file_buffer);
    const writer = &file_writer.interface;

    try writer.writeAll("# blender-zig bundle v1\n");
    try writer.print("format-version={d}\n", .{metadata.format_version});
    if (metadata.id) |id| {
        try writer.print("id={s}\n", .{id});
    }
    if (metadata.title) |title| {
        try writer.print("title={s}\n", .{title});
    }
    try writer.writeAll("kind=geometry-bundle\n");
    try writer.writeAll("geometry-format=obj\n");
    try writer.print("geometry-path={s}\n", .{geometry_filename});
    try writer.print("components={s}\n", .{components.label()});
    try writer.flush();
}

pub fn readBundle(allocator: std.mem.Allocator, bundle_path: []const u8) !ParsedBundle {
    const manifest_path = try std.fs.path.join(allocator, &.{ bundle_path, manifest_filename });
    defer allocator.free(manifest_path);

    const manifest_text = try std.fs.cwd().readFileAlloc(allocator, manifest_path, std.math.maxInt(usize));
    errdefer allocator.free(manifest_text);

    var metadata = replay_metadata.ReplayMetadata{};
    var seen_metadata = replay_metadata.SeenFields{};
    var saw_kind = false;
    var saw_geometry_format = false;
    var geometry_rel_path: ?[]const u8 = null;
    var components: ?GeometryComponents = null;

    var lines = std.mem.splitScalar(u8, manifest_text, '\n');
    while (lines.next()) |line| {
        const trimmed = std.mem.trim(u8, line, " \t\r");
        if (trimmed.len == 0 or trimmed[0] == '#') continue;

        const separator_index = std.mem.indexOfScalar(u8, trimmed, '=') orelse return error.InvalidBundleManifestLine;
        const key = std.mem.trim(u8, trimmed[0..separator_index], " \t");
        const value = std.mem.trim(u8, trimmed[separator_index + 1 ..], " \t");
        if (value.len == 0) return error.InvalidBundleManifestLine;

        if (try replay_metadata.parseMetadataLine(&metadata, &seen_metadata, key, value)) {
            continue;
        }

        if (std.mem.eql(u8, key, "kind")) {
            if (saw_kind) return error.DuplicateBundleManifestKey;
            saw_kind = true;
            if (!std.mem.eql(u8, value, "geometry-bundle")) return error.UnsupportedBundleKind;
            continue;
        }
        if (std.mem.eql(u8, key, "geometry-format")) {
            if (saw_geometry_format) return error.DuplicateBundleManifestKey;
            saw_geometry_format = true;
            if (!std.mem.eql(u8, value, "obj")) return error.UnsupportedBundleGeometryFormat;
            continue;
        }
        if (std.mem.eql(u8, key, "geometry-path")) {
            if (geometry_rel_path != null) return error.DuplicateBundleManifestKey;
            if (std.fs.path.isAbsolute(value)) return error.BundlePathMustBeRelative;
            geometry_rel_path = value;
            continue;
        }
        if (std.mem.eql(u8, key, "components")) {
            if (components != null) return error.DuplicateBundleManifestKey;
            components = try GeometryComponents.parse(value);
            continue;
        }

        return error.UnknownBundleManifestKey;
    }

    if (!saw_kind) return error.MissingBundleKind;
    if (!saw_geometry_format) return error.MissingBundleGeometryFormat;
    const geometry_path = geometry_rel_path orelse return error.MissingBundleGeometryPath;
    const manifest_components = components orelse return error.MissingBundleComponents;

    const payload_path = try std.fs.path.join(allocator, &.{ bundle_path, geometry_path });
    defer allocator.free(payload_path);

    const imported = try obj.readGeometryFile(allocator, payload_path);
    switch (imported) {
        .geometry => |geometry| {
            var opened_geometry = geometry;
            const actual_components = try GeometryComponents.fromGeometry(&opened_geometry);
            if (!manifest_components.eql(actual_components)) {
                opened_geometry.deinit();
                return error.BundleComponentMismatch;
            }

            return .{
                .metadata = metadata,
                .components = manifest_components,
                .geometry = opened_geometry,
                .owned_manifest_text = manifest_text,
            };
        },
        .parse_failure => {
            return error.InvalidBundleGeometryImport;
        },
    }
}

fn createMeshOnlyGeometry(allocator: std.mem.Allocator) !geometry_mod.GeometrySet {
    var mesh = try mesh_mod.Mesh.init(allocator);
    errdefer mesh.deinit();

    _ = try mesh.appendVertex(.{ .x = 0, .y = 0, .z = 0 });
    _ = try mesh.appendVertex(.{ .x = 1, .y = 0, .z = 0 });
    _ = try mesh.appendVertex(.{ .x = 1, .y = 1, .z = 0 });
    _ = try mesh.appendVertex(.{ .x = 0, .y = 1, .z = 0 });
    try mesh.appendFace(&[_]u32{ 0, 1, 2, 3 }, null);
    try mesh.rebuildEdgesFromFaces();

    return geometry_mod.GeometrySet.fromMeshOwned(allocator, mesh);
}

fn createCurveOnlyGeometry(allocator: std.mem.Allocator) !geometry_mod.GeometrySet {
    var curves = try curves_mod.CurvesGeometry.init(allocator);
    errdefer curves.deinit();

    const curve_points = [_]math.Vec3{
        .{ .x = 0, .y = 0, .z = 0 },
        .{ .x = 1, .y = 0, .z = 0 },
        .{ .x = 1, .y = 1, .z = 0 },
    };
    try curves.appendCurve(&curve_points, false, null);
    return geometry_mod.GeometrySet.fromCurvesOwned(allocator, curves);
}

fn createMixedGeometry(allocator: std.mem.Allocator) !geometry_mod.GeometrySet {
    var geometry = try createMeshOnlyGeometry(allocator);
    errdefer geometry.deinit();

    var curves_geometry = try createCurveOnlyGeometry(allocator);
    defer curves_geometry.deinit();

    try geometry.appendGeometry(&curves_geometry);
    return geometry;
}

test "bundle roundtrips mesh-only geometry" {
    var temp = std.testing.tmpDir(.{});
    defer temp.cleanup();

    var geometry = try createMeshOnlyGeometry(std.testing.allocator);
    defer geometry.deinit();

    const temp_root = try temp.dir.realpathAlloc(std.testing.allocator, ".");
    defer std.testing.allocator.free(temp_root);
    const bundle_path = try std.fs.path.join(std.testing.allocator, &.{ temp_root, "mesh-only.bzbundle" });
    defer std.testing.allocator.free(bundle_path);

    try writeBundle(std.testing.allocator, bundle_path, &geometry, .{ .title = "Mesh Only" });
    var bundle = try readBundle(std.testing.allocator, bundle_path);
    defer bundle.deinit(std.testing.allocator);

    try std.testing.expect(bundle.geometry.mesh != null);
    try std.testing.expect(bundle.geometry.curves == null);
    try std.testing.expectEqualStrings("Mesh Only", bundle.metadata.title.?);
    try std.testing.expectEqual(@as(usize, 1), bundle.geometry.mesh.?.faceCount());
}

test "bundle roundtrips curve-only geometry" {
    var temp = std.testing.tmpDir(.{});
    defer temp.cleanup();

    var geometry = try createCurveOnlyGeometry(std.testing.allocator);
    defer geometry.deinit();

    const temp_root = try temp.dir.realpathAlloc(std.testing.allocator, ".");
    defer std.testing.allocator.free(temp_root);
    const bundle_path = try std.fs.path.join(std.testing.allocator, &.{ temp_root, "curves-only.bzbundle" });
    defer std.testing.allocator.free(bundle_path);

    try writeBundle(std.testing.allocator, bundle_path, &geometry, .{ .title = "Curves Only" });
    var bundle = try readBundle(std.testing.allocator, bundle_path);
    defer bundle.deinit(std.testing.allocator);

    try std.testing.expect(bundle.geometry.mesh == null);
    try std.testing.expect(bundle.geometry.curves != null);
    try std.testing.expectEqual(@as(usize, 1), bundle.geometry.curves.?.curvesNum());
    try std.testing.expectEqual(@as(usize, 3), bundle.geometry.curves.?.pointsNum());
}

test "bundle roundtrips mixed geometry" {
    var temp = std.testing.tmpDir(.{});
    defer temp.cleanup();

    var geometry = try createMixedGeometry(std.testing.allocator);
    defer geometry.deinit();

    const temp_root = try temp.dir.realpathAlloc(std.testing.allocator, ".");
    defer std.testing.allocator.free(temp_root);
    const bundle_path = try std.fs.path.join(std.testing.allocator, &.{ temp_root, "mixed.bzbundle" });
    defer std.testing.allocator.free(bundle_path);

    try writeBundle(std.testing.allocator, bundle_path, &geometry, .{ .title = "Mixed Geometry" });
    var bundle = try readBundle(std.testing.allocator, bundle_path);
    defer bundle.deinit(std.testing.allocator);

    try std.testing.expect(bundle.geometry.mesh != null);
    try std.testing.expect(bundle.geometry.curves != null);
    try std.testing.expectEqual(@as(usize, 1), bundle.geometry.mesh.?.faceCount());
    try std.testing.expectEqual(@as(usize, 1), bundle.geometry.curves.?.curvesNum());
}

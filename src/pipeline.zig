const std = @import("std");
const mesh_mod = @import("mesh.zig");
const cuboid = @import("geometry/primitives/cuboid.zig");
const cylinder_cone = @import("geometry/primitives/cylinder_cone.zig");
const grid = @import("geometry/primitives/grid.zig");
const uv_sphere = @import("geometry/primitives/uv_sphere.zig");
const mesh_dissolve = @import("geometry/mesh_dissolve.zig");
const mesh_extrude = @import("geometry/mesh_extrude.zig");
const mesh_inset = @import("geometry/mesh_inset.zig");
const mesh_merge = @import("geometry/mesh_merge_by_distance.zig");
const mesh_subdivide = @import("geometry/mesh_subdivide.zig");
const mesh_triangulate = @import("geometry/mesh_triangulate.zig");

pub const Seed = enum {
    grid,
    cuboid,
    cylinder,
    sphere,

    pub fn parse(name: []const u8) !Seed {
        if (std.mem.eql(u8, name, "grid")) return .grid;
        if (std.mem.eql(u8, name, "cuboid")) return .cuboid;
        if (std.mem.eql(u8, name, "cylinder")) return .cylinder;
        if (std.mem.eql(u8, name, "sphere")) return .sphere;
        return error.UnknownPipelineSeed;
    }
};

pub const Step = enum {
    subdivide,
    extrude,
    inset,
    triangulate,
    dissolve,
    planar_dissolve,
    merge_by_distance,

    pub fn parse(name: []const u8) !Step {
        if (std.mem.eql(u8, name, "subdivide")) return .subdivide;
        if (std.mem.eql(u8, name, "extrude")) return .extrude;
        if (std.mem.eql(u8, name, "inset")) return .inset;
        if (std.mem.eql(u8, name, "triangulate")) return .triangulate;
        if (std.mem.eql(u8, name, "dissolve")) return .dissolve;
        if (std.mem.eql(u8, name, "planar-dissolve")) return .planar_dissolve;
        if (std.mem.eql(u8, name, "merge-by-distance")) return .merge_by_distance;
        return error.UnknownPipelineStep;
    }
};

pub const ParsedArgs = struct {
    seed: Seed,
    steps: std.ArrayList(Step),
    output_path: ?[]const u8,

    pub fn deinit(self: *ParsedArgs, allocator: std.mem.Allocator) void {
        self.steps.deinit(allocator);
        allocator.destroy(self);
    }
};

pub fn parseArgs(allocator: std.mem.Allocator, args: []const []const u8) !*ParsedArgs {
    if (args.len == 0) return error.MissingPipelineSeed;

    var parsed = try allocator.create(ParsedArgs);
    errdefer allocator.destroy(parsed);
    parsed.* = .{
        .seed = try Seed.parse(args[0]),
        .steps = .empty,
        .output_path = null,
    };
    errdefer parsed.steps.deinit(allocator);

    var index: usize = 1;
    while (index < args.len) : (index += 1) {
        const token = args[index];
        if (std.mem.eql(u8, token, "--write")) {
            if (index + 1 >= args.len) return error.MissingPipelineOutputPath;
            parsed.output_path = args[index + 1];
            index += 1;
            continue;
        }
        try parsed.steps.append(allocator, try Step.parse(token));
    }

    return parsed;
}

pub fn runMeshPipeline(
    allocator: std.mem.Allocator,
    seed: Seed,
    steps: []const Step,
) !mesh_mod.Mesh {
    var mesh = try buildSeedMesh(allocator, seed);
    errdefer mesh.deinit();

    for (steps) |step| {
        const next_mesh = try applyStep(allocator, &mesh, step);
        mesh.deinit();
        mesh = next_mesh;
    }

    return mesh;
}

fn buildSeedMesh(allocator: std.mem.Allocator, seed: Seed) !mesh_mod.Mesh {
    return switch (seed) {
        .grid => grid.createGridMesh(allocator, 3, 2, 2.0, 1.0, true),
        .cuboid => cuboid.createCuboidMesh(allocator, .{ .x = 2.0, .y = 2.0, .z = 2.0 }, 2, 2, 2, true),
        .cylinder => cylinder_cone.createCylinderMesh(allocator, 1.0, 2.0, 16, true, true, true),
        .sphere => uv_sphere.createUvSphereMesh(allocator, 1.25, 12, 6, true),
    };
}

fn applyStep(
    allocator: std.mem.Allocator,
    mesh: *const mesh_mod.Mesh,
    step: Step,
) !mesh_mod.Mesh {
    return switch (step) {
        .subdivide => mesh_subdivide.subdivideFaces(allocator, mesh, .{}),
        .extrude => mesh_extrude.extrudeIndividual(allocator, mesh, .{ .distance = 0.5 }),
        .inset => mesh_inset.insetIndividual(allocator, mesh, .{ .factor = 0.2 }),
        .triangulate => mesh_triangulate.triangulateMesh(allocator, mesh),
        .dissolve => mesh_dissolve.dissolveEdges(allocator, mesh, pickFirstSharedEdge(mesh)),
        .planar_dissolve => mesh_dissolve.dissolvePlanar(allocator, mesh, .{}),
        .merge_by_distance => mesh_merge.mergeByDistance(allocator, mesh, .{ .distance = 0.01 }),
    };
}

fn pickFirstSharedEdge(mesh: *const mesh_mod.Mesh) []const mesh_mod.Edge {
    const Static = struct {
        var edge: [1]mesh_mod.Edge = .{.{ .a = 0, .b = 0 }};
    };

    var uses = std.AutoHashMap(u64, u8).init(std.heap.page_allocator);
    defer uses.deinit();

    for (0..mesh.faceCount()) |face_index| {
        const range = mesh.faceVertexRange(face_index);
        const face_verts = mesh.corner_verts.items[range.start..range.end];
        for (face_verts, 0..) |vertex, local_index| {
            const next_vertex = face_verts[(local_index + 1) % face_verts.len];
            const key = packUndirectedEdge(vertex, next_vertex);
            const entry = uses.getOrPut(key) catch continue;
            if (!entry.found_existing) {
                entry.value_ptr.* = 0;
            }
            entry.value_ptr.* += 1;
            if (entry.value_ptr.* == 2) {
                Static.edge[0] = unpackUndirectedEdge(key);
                return &Static.edge;
            }
        }
    }

    return &[_]mesh_mod.Edge{};
}

fn packUndirectedEdge(a: u32, b: u32) u64 {
    const lo = @min(a, b);
    const hi = @max(a, b);
    return (@as(u64, hi) << 32) | @as(u64, lo);
}

fn unpackUndirectedEdge(key: u64) mesh_mod.Edge {
    return .{
        .a = @intCast(key & 0xffffffff),
        .b = @intCast(key >> 32),
    };
}

test "pipeline can parse seed, steps, and output path" {
    var parsed = try parseArgs(std.testing.allocator, &[_][]const u8{
        "grid",
        "subdivide",
        "extrude",
        "--write",
        "zig-out/pipeline.obj",
    });
    defer parsed.deinit(std.testing.allocator);

    try std.testing.expectEqual(Seed.grid, parsed.seed);
    try std.testing.expectEqual(@as(usize, 2), parsed.steps.items.len);
    try std.testing.expectEqual(Step.subdivide, parsed.steps.items[0]);
    try std.testing.expectEqual(Step.extrude, parsed.steps.items[1]);
    try std.testing.expectEqualStrings("zig-out/pipeline.obj", parsed.output_path.?);
}

test "pipeline can build a subdivided and extruded mesh" {
    const steps = [_]Step{ .subdivide, .extrude };
    var mesh = try runMeshPipeline(std.testing.allocator, .grid, &steps);
    defer mesh.deinit();

    try std.testing.expect(mesh.vertexCount() > 6);
    try std.testing.expect(mesh.faceCount() > 2);
    try std.testing.expect(mesh.hasCornerUvs());
}

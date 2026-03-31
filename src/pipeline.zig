const std = @import("std");
const mesh_mod = @import("mesh.zig");
const cuboid = @import("geometry/primitives/cuboid.zig");
const cylinder_cone = @import("geometry/primitives/cylinder_cone.zig");
const grid = @import("geometry/primitives/grid.zig");
const uv_sphere = @import("geometry/primitives/uv_sphere.zig");
const mesh_delete_loose = @import("geometry/mesh_delete_loose.zig");
const mesh_dissolve = @import("geometry/mesh_dissolve.zig");
const mesh_extrude = @import("geometry/mesh_extrude.zig");
const mesh_extrude_region = @import("geometry/mesh_extrude_region.zig");
const mesh_inset = @import("geometry/mesh_inset.zig");
const mesh_inset_region = @import("geometry/mesh_inset_region.zig");
const mesh_merge = @import("geometry/mesh_merge_by_distance.zig");
const mesh_subdivide = @import("geometry/mesh_subdivide.zig");
const mesh_transform = @import("geometry/mesh_transform.zig");
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

pub const SeedSpec = struct {
    seed: Seed,
    verts_x: ?usize = null,
    verts_y: ?usize = null,
    verts_z: ?usize = null,
    size_x: ?f32 = null,
    size_y: ?f32 = null,
    size_z: ?f32 = null,
    radius: ?f32 = null,
    height: ?f32 = null,
    segments: ?usize = null,
    rings: ?usize = null,
    top_cap: ?bool = null,
    bottom_cap: ?bool = null,
    with_uvs: ?bool = null,
};

pub const Step = enum {
    subdivide,
    extrude,
    extrude_region,
    inset,
    inset_region,
    triangulate,
    delete_loose,
    dissolve,
    planar_dissolve,
    merge_by_distance,
    translate,
    scale,
    rotate_z,
    array,

    pub fn parse(name: []const u8) !Step {
        if (std.mem.eql(u8, name, "subdivide")) return .subdivide;
        if (std.mem.eql(u8, name, "extrude")) return .extrude;
        if (std.mem.eql(u8, name, "extrude-region")) return .extrude_region;
        if (std.mem.eql(u8, name, "inset")) return .inset;
        if (std.mem.eql(u8, name, "inset-region")) return .inset_region;
        if (std.mem.eql(u8, name, "triangulate")) return .triangulate;
        if (std.mem.eql(u8, name, "delete-loose")) return .delete_loose;
        if (std.mem.eql(u8, name, "dissolve")) return .dissolve;
        if (std.mem.eql(u8, name, "planar-dissolve")) return .planar_dissolve;
        if (std.mem.eql(u8, name, "merge-by-distance")) return .merge_by_distance;
        if (std.mem.eql(u8, name, "translate")) return .translate;
        if (std.mem.eql(u8, name, "scale")) return .scale;
        if (std.mem.eql(u8, name, "rotate-z")) return .rotate_z;
        if (std.mem.eql(u8, name, "array")) return .array;
        return error.UnknownPipelineStep;
    }
};

pub const StepSpec = struct {
    step: Step,
    repeat: usize = 1,
    extrude_distance: ?f32 = null,
    inset_factor: ?f32 = null,
    inset_region_width: ?f32 = null,
    merge_distance: ?f32 = null,
    planar_normal_epsilon: ?f32 = null,
    planar_plane_epsilon: ?f32 = null,
    translate_x: ?f32 = null,
    translate_y: ?f32 = null,
    translate_z: ?f32 = null,
    scale_x: ?f32 = null,
    scale_y: ?f32 = null,
    scale_z: ?f32 = null,
    rotate_degrees: ?f32 = null,
    array_count: ?usize = null,
    array_count_x: ?usize = null,
    array_count_y: ?usize = null,
    array_count_z: ?usize = null,
    array_offset_x: ?f32 = null,
    array_offset_y: ?f32 = null,
    array_offset_z: ?f32 = null,
};

pub const ParsedArgs = struct {
    seed: SeedSpec,
    steps: std.ArrayList(StepSpec),
    output_path: ?[]const u8,
    owned_recipe_text: ?[]u8 = null,
    owned_output_path: ?[]u8 = null,

    pub fn deinit(self: *ParsedArgs, allocator: std.mem.Allocator) void {
        if (self.owned_recipe_text) |buffer| allocator.free(buffer);
        if (self.owned_output_path) |buffer| allocator.free(buffer);
        self.steps.deinit(allocator);
        allocator.destroy(self);
    }
};

pub fn parseArgs(allocator: std.mem.Allocator, args: []const []const u8) !*ParsedArgs {
    var inline_tokens = std.ArrayList([]const u8).empty;
    defer inline_tokens.deinit(allocator);

    var recipe_path: ?[]const u8 = null;
    var output_path: ?[]const u8 = null;

    var index: usize = 0;
    while (index < args.len) : (index += 1) {
        const token = args[index];
        if (std.mem.eql(u8, token, "--write")) {
            if (index + 1 >= args.len) return error.MissingPipelineOutputPath;
            if (output_path != null) return error.DuplicatePipelineOutputPath;
            output_path = args[index + 1];
            index += 1;
            continue;
        }
        if (std.mem.eql(u8, token, "--recipe")) {
            if (index + 1 >= args.len) return error.MissingPipelineRecipePath;
            if (recipe_path != null) return error.DuplicatePipelineRecipePath;
            recipe_path = args[index + 1];
            index += 1;
            continue;
        }
        try inline_tokens.append(allocator, token);
    }

    if (recipe_path) |path| {
        if (inline_tokens.items.len != 0) return error.MixedPipelineSources;

        var parsed = try parseRecipeFile(allocator, path);
        if (output_path) |write_path| {
            parsed.output_path = write_path;
        }
        return parsed;
    }

    if (inline_tokens.items.len == 0) return error.MissingPipelineSeed;
    return parseInlineTokens(allocator, inline_tokens.items, output_path);
}

pub fn runMeshPipeline(
    allocator: std.mem.Allocator,
    seed: SeedSpec,
    steps: []const StepSpec,
) !mesh_mod.Mesh {
    var mesh = try buildSeedMesh(allocator, seed);
    errdefer mesh.deinit();

    for (steps) |step| {
        for (0..step.repeat) |_| {
            const next_mesh = try applyStep(allocator, &mesh, step);
            mesh.deinit();
            mesh = next_mesh;
        }
    }

    return mesh;
}

fn buildSeedMesh(allocator: std.mem.Allocator, seed_spec: SeedSpec) !mesh_mod.Mesh {
    return switch (seed_spec.seed) {
        .grid => grid.createGridMesh(
            allocator,
            seed_spec.verts_x orelse 3,
            seed_spec.verts_y orelse 2,
            seed_spec.size_x orelse 2.0,
            seed_spec.size_y orelse 1.0,
            seed_spec.with_uvs orelse true,
        ),
        .cuboid => cuboid.createCuboidMesh(
            allocator,
            .{
                .x = seed_spec.size_x orelse 2.0,
                .y = seed_spec.size_y orelse 2.0,
                .z = seed_spec.size_z orelse 2.0,
            },
            seed_spec.verts_x orelse 2,
            seed_spec.verts_y orelse 2,
            seed_spec.verts_z orelse 2,
            seed_spec.with_uvs orelse true,
        ),
        .cylinder => cylinder_cone.createCylinderMesh(
            allocator,
            seed_spec.radius orelse 1.0,
            seed_spec.height orelse 2.0,
            seed_spec.segments orelse 16,
            seed_spec.top_cap orelse true,
            seed_spec.bottom_cap orelse true,
            seed_spec.with_uvs orelse true,
        ),
        .sphere => uv_sphere.createUvSphereMesh(
            allocator,
            seed_spec.radius orelse 1.25,
            seed_spec.segments orelse 12,
            seed_spec.rings orelse 6,
            seed_spec.with_uvs orelse true,
        ),
    };
}

fn applyStep(
    allocator: std.mem.Allocator,
    mesh: *const mesh_mod.Mesh,
    step_spec: StepSpec,
) !mesh_mod.Mesh {
    return switch (step_spec.step) {
        .subdivide => mesh_subdivide.subdivideFaces(allocator, mesh, .{}),
        .extrude => mesh_extrude.extrudeIndividual(allocator, mesh, .{
            .distance = step_spec.extrude_distance orelse 0.5,
        }),
        .extrude_region => mesh_extrude_region.extrudeRegion(allocator, mesh, .{
            .distance = step_spec.extrude_distance orelse 0.5,
        }),
        .inset => mesh_inset.insetIndividual(allocator, mesh, .{
            .factor = step_spec.inset_factor orelse 0.2,
        }),
        .inset_region => mesh_inset_region.insetRegion(allocator, mesh, .{
            .width = step_spec.inset_region_width orelse 0.2,
        }),
        .triangulate => mesh_triangulate.triangulateMesh(allocator, mesh),
        .delete_loose => mesh_delete_loose.deleteLoose(allocator, mesh),
        .dissolve => {
            if (pickFirstSharedEdge(mesh)) |edge| {
                const edges = [_]mesh_mod.Edge{edge};
                return mesh_dissolve.dissolveEdges(allocator, mesh, &edges);
            }
            return try mesh.clone(allocator);
        },
        .planar_dissolve => mesh_dissolve.dissolvePlanar(allocator, mesh, .{
            .normal_epsilon = step_spec.planar_normal_epsilon orelse 1e-4,
            .plane_epsilon = step_spec.planar_plane_epsilon orelse 1e-4,
        }),
        .merge_by_distance => mesh_merge.mergeByDistance(allocator, mesh, .{
            .distance = step_spec.merge_distance orelse 0.01,
        }),
        .translate => mesh_transform.translateMesh(allocator, mesh, .{
            .x = step_spec.translate_x orelse 0.0,
            .y = step_spec.translate_y orelse 0.0,
            .z = step_spec.translate_z orelse 0.0,
        }),
        .scale => mesh_transform.scaleMesh(allocator, mesh, .{
            .x = step_spec.scale_x orelse 1.0,
            .y = step_spec.scale_y orelse 1.0,
            .z = step_spec.scale_z orelse 1.0,
        }),
        .rotate_z => mesh_transform.rotateMeshZ(
            allocator,
            mesh,
            std.math.degreesToRadians(step_spec.rotate_degrees orelse 0.0),
        ),
        .array => applyArrayStep(allocator, mesh, step_spec),
    };
}

fn parseInlineTokens(
    allocator: std.mem.Allocator,
    inline_tokens: []const []const u8,
    output_path: ?[]const u8,
) !*ParsedArgs {
    var parsed = try allocator.create(ParsedArgs);
    errdefer allocator.destroy(parsed);
    parsed.* = .{
        .seed = try parseSeedSpec(inline_tokens[0]),
        .steps = .empty,
        .output_path = output_path,
    };
    errdefer parsed.steps.deinit(allocator);

    for (inline_tokens[1..]) |token| {
        try parsed.steps.append(allocator, try parseStepSpec(token));
    }

    return parsed;
}

// Recipes deliberately reuse the existing step token grammar so contributors only
// have one modeling vocabulary to learn: the CLI form and the saved-file form match.
fn parseRecipeFile(allocator: std.mem.Allocator, recipe_path: []const u8) !*ParsedArgs {
    const recipe_text = try std.fs.cwd().readFileAlloc(allocator, recipe_path, std.math.maxInt(usize));
    return parseRecipeText(allocator, recipe_text, recipe_path);
}

fn parseRecipeText(
    allocator: std.mem.Allocator,
    owned_recipe_text: []u8,
    recipe_path: []const u8,
) !*ParsedArgs {
    errdefer allocator.free(owned_recipe_text);
    var parsed = try allocator.create(ParsedArgs);
    errdefer allocator.destroy(parsed);
    parsed.* = .{
        .seed = .{ .seed = .grid },
        .steps = .empty,
        .output_path = null,
        .owned_recipe_text = owned_recipe_text,
        .owned_output_path = null,
    };
    errdefer parsed.steps.deinit(allocator);
    errdefer if (parsed.owned_output_path) |buffer| allocator.free(buffer);

    var seed: ?SeedSpec = null;
    var lines = std.mem.splitScalar(u8, owned_recipe_text, '\n');
    while (lines.next()) |line| {
        const trimmed = std.mem.trim(u8, line, " \t\r");
        if (trimmed.len == 0 or trimmed[0] == '#') continue;

        const separator_index = std.mem.indexOfScalar(u8, trimmed, '=') orelse return error.InvalidRecipeLineSyntax;
        const raw_key = trimmed[0..separator_index];
        const raw_value = trimmed[separator_index + 1 ..];

        const key = std.mem.trim(u8, raw_key, " \t");
        const value = std.mem.trim(u8, raw_value, " \t");
        if (value.len == 0) return error.InvalidRecipeLineSyntax;

        if (std.mem.eql(u8, key, "seed")) {
            if (seed != null) return error.DuplicateRecipeSeed;
            seed = try parseSeedSpec(value);
            continue;
        }
        if (std.mem.eql(u8, key, "write")) {
            if (parsed.output_path != null) return error.DuplicateRecipeWritePath;
            const resolved = try resolveRecipeOutputPath(allocator, recipe_path, value);
            parsed.owned_output_path = resolved;
            parsed.output_path = resolved;
            continue;
        }
        if (std.mem.eql(u8, key, "step")) {
            try parsed.steps.append(allocator, try parseStepSpec(value));
            continue;
        }
        return error.UnknownRecipeKey;
    }

    parsed.seed = seed orelse return error.MissingRecipeSeed;
    return parsed;
}

fn resolveRecipeOutputPath(
    allocator: std.mem.Allocator,
    recipe_path: []const u8,
    output_path: []const u8,
) ![]u8 {
    if (std.fs.path.isAbsolute(output_path)) {
        return allocator.dupe(u8, output_path);
    }
    const recipe_dir = std.fs.path.dirname(recipe_path) orelse {
        return allocator.dupe(u8, output_path);
    };
    return std.fs.path.resolve(allocator, &.{ recipe_dir, output_path });
}

fn pickFirstSharedEdge(mesh: *const mesh_mod.Mesh) ?mesh_mod.Edge {
    var uses = std.AutoHashMap(u64, u8).init(mesh.allocator);
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
                return unpackUndirectedEdge(key);
            }
        }
    }

    return null;
}

pub fn parseStepSpec(token: []const u8) !StepSpec {
    var iterator = std.mem.splitScalar(u8, token, ':');
    const step_name = iterator.first();
    const params_text = iterator.next();
    if (iterator.next() != null) return error.InvalidPipelineStepSyntax;

    var spec = StepSpec{
        .step = try Step.parse(step_name),
    };

    if (params_text) |raw_params| {
        var params = std.mem.splitScalar(u8, raw_params, ',');
        while (params.next()) |assignment| {
            if (assignment.len == 0) continue;

            var pair = std.mem.splitScalar(u8, assignment, '=');
            const key = pair.first();
            const value_text = pair.next() orelse return error.InvalidPipelineStepSyntax;
            if (pair.next() != null) return error.InvalidPipelineStepSyntax;

            if (std.mem.eql(u8, key, "repeat")) {
                spec.repeat = try parsePositiveInt(value_text);
                continue;
            }

            switch (spec.step) {
                .extrude, .extrude_region => {
                    if (std.mem.eql(u8, key, "distance")) {
                        spec.extrude_distance = try parseFloat(value_text);
                    } else {
                        return error.UnsupportedPipelineParameter;
                    }
                },
                .inset => {
                    if (std.mem.eql(u8, key, "factor")) {
                        spec.inset_factor = try parseFloat(value_text);
                    } else {
                        return error.UnsupportedPipelineParameter;
                    }
                },
                .inset_region => {
                    if (std.mem.eql(u8, key, "width")) {
                        spec.inset_region_width = try parseFloat(value_text);
                    } else {
                        return error.UnsupportedPipelineParameter;
                    }
                },
                .merge_by_distance => {
                    if (std.mem.eql(u8, key, "distance")) {
                        spec.merge_distance = try parseFloat(value_text);
                    } else {
                        return error.UnsupportedPipelineParameter;
                    }
                },
                .planar_dissolve => {
                    if (std.mem.eql(u8, key, "normal-epsilon")) {
                        spec.planar_normal_epsilon = try parseFloat(value_text);
                    } else if (std.mem.eql(u8, key, "plane-epsilon")) {
                        spec.planar_plane_epsilon = try parseFloat(value_text);
                    } else {
                        return error.UnsupportedPipelineParameter;
                    }
                },
                .translate => {
                    if (std.mem.eql(u8, key, "x")) {
                        spec.translate_x = try parseFloat(value_text);
                    } else if (std.mem.eql(u8, key, "y")) {
                        spec.translate_y = try parseFloat(value_text);
                    } else if (std.mem.eql(u8, key, "z")) {
                        spec.translate_z = try parseFloat(value_text);
                    } else {
                        return error.UnsupportedPipelineParameter;
                    }
                },
                .scale => {
                    if (std.mem.eql(u8, key, "x")) {
                        spec.scale_x = try parseFloat(value_text);
                    } else if (std.mem.eql(u8, key, "y")) {
                        spec.scale_y = try parseFloat(value_text);
                    } else if (std.mem.eql(u8, key, "z")) {
                        spec.scale_z = try parseFloat(value_text);
                    } else {
                        return error.UnsupportedPipelineParameter;
                    }
                },
                .rotate_z => {
                    if (std.mem.eql(u8, key, "degrees")) {
                        spec.rotate_degrees = try parseFloat(value_text);
                    } else {
                        return error.UnsupportedPipelineParameter;
                    }
                },
                .array => {
                    if (std.mem.eql(u8, key, "count")) {
                        spec.array_count = try parsePositiveInt(value_text);
                    } else if (std.mem.eql(u8, key, "count-x")) {
                        spec.array_count_x = try parsePositiveInt(value_text);
                    } else if (std.mem.eql(u8, key, "count-y")) {
                        spec.array_count_y = try parsePositiveInt(value_text);
                    } else if (std.mem.eql(u8, key, "count-z")) {
                        spec.array_count_z = try parsePositiveInt(value_text);
                    } else if (std.mem.eql(u8, key, "offset-x")) {
                        spec.array_offset_x = try parseFloat(value_text);
                    } else if (std.mem.eql(u8, key, "offset-y")) {
                        spec.array_offset_y = try parseFloat(value_text);
                    } else if (std.mem.eql(u8, key, "offset-z")) {
                        spec.array_offset_z = try parseFloat(value_text);
                    } else {
                        return error.UnsupportedPipelineParameter;
                    }
                },
                else => return error.UnsupportedPipelineParameter,
            }
        }
    }

    if (spec.step == .array) {
        const has_axis_counts = spec.array_count_x != null or spec.array_count_y != null or spec.array_count_z != null;
        if (spec.array_count == null and !has_axis_counts) return error.MissingPipelineArrayCount;
        if (spec.array_count != null and has_axis_counts) return error.InvalidPipelineArrayMode;
    }

    return spec;
}

fn applyArrayStep(
    allocator: std.mem.Allocator,
    mesh: *const mesh_mod.Mesh,
    step_spec: StepSpec,
) !mesh_mod.Mesh {
    if (step_spec.array_count) |count| {
        return mesh_transform.duplicateMeshArray(allocator, mesh, .{
            .count = count,
            .offset = .{
                .x = step_spec.array_offset_x orelse 1.0,
                .y = step_spec.array_offset_y orelse 0.0,
                .z = step_spec.array_offset_z orelse 0.0,
            },
        });
    }

    var result = try mesh.clone(allocator);
    errdefer result.deinit();

    try applyAxisArray(
        allocator,
        &result,
        step_spec.array_count_x orelse 1,
        .{
            .x = step_spec.array_offset_x orelse 1.0,
            .y = 0.0,
            .z = 0.0,
        },
    );
    try applyAxisArray(
        allocator,
        &result,
        step_spec.array_count_y orelse 1,
        .{
            .x = 0.0,
            .y = step_spec.array_offset_y orelse 1.0,
            .z = 0.0,
        },
    );
    try applyAxisArray(
        allocator,
        &result,
        step_spec.array_count_z orelse 1,
        .{
            .x = 0.0,
            .y = 0.0,
            .z = step_spec.array_offset_z orelse 1.0,
        },
    );

    return result;
}

fn applyAxisArray(
    allocator: std.mem.Allocator,
    mesh: *mesh_mod.Mesh,
    count: usize,
    offset: mesh_mod.Vec3,
) !void {
    if (count <= 1) return;

    const duplicated = try mesh_transform.duplicateMeshArray(allocator, mesh, .{
        .count = count,
        .offset = offset,
    });
    mesh.deinit();
    mesh.* = duplicated;
}

// Seed overrides use the same `name:param=value,...` shape as steps so saved
// recipes and inline authoring both map onto one small, teachable grammar.
fn parseSeedSpec(token: []const u8) !SeedSpec {
    var iterator = std.mem.splitScalar(u8, token, ':');
    const seed_name = iterator.first();
    const params_text = iterator.next();
    if (iterator.next() != null) return error.InvalidPipelineSeedSyntax;

    var spec = SeedSpec{
        .seed = try Seed.parse(seed_name),
    };

    var seen_verts_x = false;
    var seen_verts_y = false;
    var seen_verts_z = false;
    var seen_size_x = false;
    var seen_size_y = false;
    var seen_size_z = false;
    var seen_radius = false;
    var seen_height = false;
    var seen_segments = false;
    var seen_rings = false;
    var seen_top_cap = false;
    var seen_bottom_cap = false;
    var seen_with_uvs = false;

    if (params_text) |raw_params| {
        var params = std.mem.splitScalar(u8, raw_params, ',');
        while (params.next()) |assignment| {
            if (assignment.len == 0) continue;

            var pair = std.mem.splitScalar(u8, assignment, '=');
            const key = pair.first();
            const value_text = pair.next() orelse return error.InvalidPipelineSeedSyntax;
            if (pair.next() != null) return error.InvalidPipelineSeedSyntax;

            if (std.mem.eql(u8, key, "verts-x")) {
                if (spec.seed != .grid and spec.seed != .cuboid) return error.UnsupportedSeedParameter;
                if (seen_verts_x) return error.DuplicateSeedParameter;
                seen_verts_x = true;
                spec.verts_x = try parsePositiveInt(value_text);
                continue;
            }
            if (std.mem.eql(u8, key, "verts-y")) {
                if (spec.seed != .grid and spec.seed != .cuboid) return error.UnsupportedSeedParameter;
                if (seen_verts_y) return error.DuplicateSeedParameter;
                seen_verts_y = true;
                spec.verts_y = try parsePositiveInt(value_text);
                continue;
            }
            if (std.mem.eql(u8, key, "verts-z")) {
                if (spec.seed != .cuboid) return error.UnsupportedSeedParameter;
                if (seen_verts_z) return error.DuplicateSeedParameter;
                seen_verts_z = true;
                spec.verts_z = try parsePositiveInt(value_text);
                continue;
            }
            if (std.mem.eql(u8, key, "size-x")) {
                if (spec.seed != .grid and spec.seed != .cuboid) return error.UnsupportedSeedParameter;
                if (seen_size_x) return error.DuplicateSeedParameter;
                seen_size_x = true;
                spec.size_x = try parseFloat(value_text);
                continue;
            }
            if (std.mem.eql(u8, key, "size-y")) {
                if (spec.seed != .grid and spec.seed != .cuboid) return error.UnsupportedSeedParameter;
                if (seen_size_y) return error.DuplicateSeedParameter;
                seen_size_y = true;
                spec.size_y = try parseFloat(value_text);
                continue;
            }
            if (std.mem.eql(u8, key, "size-z")) {
                if (spec.seed != .cuboid) return error.UnsupportedSeedParameter;
                if (seen_size_z) return error.DuplicateSeedParameter;
                seen_size_z = true;
                spec.size_z = try parseFloat(value_text);
                continue;
            }
            if (std.mem.eql(u8, key, "radius")) {
                if (spec.seed != .cylinder and spec.seed != .sphere) return error.UnsupportedSeedParameter;
                if (seen_radius) return error.DuplicateSeedParameter;
                seen_radius = true;
                spec.radius = try parseFloat(value_text);
                continue;
            }
            if (std.mem.eql(u8, key, "height")) {
                if (spec.seed != .cylinder) return error.UnsupportedSeedParameter;
                if (seen_height) return error.DuplicateSeedParameter;
                seen_height = true;
                spec.height = try parseFloat(value_text);
                continue;
            }
            if (std.mem.eql(u8, key, "segments")) {
                if (spec.seed != .cylinder and spec.seed != .sphere) return error.UnsupportedSeedParameter;
                if (seen_segments) return error.DuplicateSeedParameter;
                seen_segments = true;
                spec.segments = try parsePositiveInt(value_text);
                continue;
            }
            if (std.mem.eql(u8, key, "rings")) {
                if (spec.seed != .sphere) return error.UnsupportedSeedParameter;
                if (seen_rings) return error.DuplicateSeedParameter;
                seen_rings = true;
                spec.rings = try parsePositiveInt(value_text);
                continue;
            }
            if (std.mem.eql(u8, key, "top-cap")) {
                if (spec.seed != .cylinder) return error.UnsupportedSeedParameter;
                if (seen_top_cap) return error.DuplicateSeedParameter;
                seen_top_cap = true;
                spec.top_cap = try parseBool(value_text);
                continue;
            }
            if (std.mem.eql(u8, key, "bottom-cap")) {
                if (spec.seed != .cylinder) return error.UnsupportedSeedParameter;
                if (seen_bottom_cap) return error.DuplicateSeedParameter;
                seen_bottom_cap = true;
                spec.bottom_cap = try parseBool(value_text);
                continue;
            }
            if (std.mem.eql(u8, key, "uvs")) {
                if (seen_with_uvs) return error.DuplicateSeedParameter;
                seen_with_uvs = true;
                spec.with_uvs = try parseBool(value_text);
                continue;
            }

            return error.UnsupportedSeedParameter;
        }
    }

    return spec;
}

fn parseFloat(text: []const u8) !f32 {
    return std.fmt.parseFloat(f32, text);
}

fn parseBool(text: []const u8) !bool {
    if (std.mem.eql(u8, text, "true")) return true;
    if (std.mem.eql(u8, text, "false")) return false;
    return error.InvalidPipelineBool;
}

fn parsePositiveInt(text: []const u8) !usize {
    const value = try std.fmt.parseUnsigned(usize, text, 10);
    if (value == 0) return error.InvalidPipelineRepeat;
    return value;
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

test "pipeline can parse parameterized steps and output path" {
    var parsed = try parseArgs(std.testing.allocator, &[_][]const u8{
        "grid:verts-x=8,verts-y=5,size-x=4.0,size-y=2.0,uvs=true",
        "subdivide:repeat=2",
        "extrude:distance=0.75",
        "inset:factor=0.1",
        "--write",
        "zig-out/pipeline.obj",
    });
    defer parsed.deinit(std.testing.allocator);

    try std.testing.expectEqual(Seed.grid, parsed.seed.seed);
    try std.testing.expectEqual(@as(usize, 8), parsed.seed.verts_x.?);
    try std.testing.expectEqual(@as(usize, 5), parsed.seed.verts_y.?);
    try std.testing.expectEqual(@as(f32, 4.0), parsed.seed.size_x.?);
    try std.testing.expectEqual(@as(f32, 2.0), parsed.seed.size_y.?);
    try std.testing.expectEqual(true, parsed.seed.with_uvs.?);
    try std.testing.expectEqual(@as(usize, 3), parsed.steps.items.len);
    try std.testing.expectEqual(Step.subdivide, parsed.steps.items[0].step);
    try std.testing.expectEqual(@as(usize, 2), parsed.steps.items[0].repeat);
    try std.testing.expectEqual(Step.extrude, parsed.steps.items[1].step);
    try std.testing.expectEqual(@as(f32, 0.75), parsed.steps.items[1].extrude_distance.?);
    try std.testing.expectEqual(Step.inset, parsed.steps.items[2].step);
    try std.testing.expectEqual(@as(f32, 0.1), parsed.steps.items[2].inset_factor.?);
    try std.testing.expectEqualStrings("zig-out/pipeline.obj", parsed.output_path.?);
}

test "pipeline can parse a persisted recipe file" {
    const recipe_text =
        \\# blender-zig pipeline v1
        \\seed=grid:verts-x=8,verts-y=5,size-x=4.0,size-y=2.0,uvs=true
        \\write=zig-out/recipe.obj
        \\
        \\step=subdivide:repeat=2
        \\step=extrude:distance=0.75
        \\step=inset:factor=0.1
        \\
    ;
    const owned_text = try std.testing.allocator.dupe(u8, recipe_text);
    var parsed = try parseRecipeText(std.testing.allocator, owned_text, "recipes/grid-study.bzrecipe");
    defer parsed.deinit(std.testing.allocator);

    try std.testing.expectEqual(Seed.grid, parsed.seed.seed);
    try std.testing.expectEqual(@as(usize, 8), parsed.seed.verts_x.?);
    try std.testing.expectEqual(@as(usize, 5), parsed.seed.verts_y.?);
    try std.testing.expectEqual(@as(f32, 4.0), parsed.seed.size_x.?);
    try std.testing.expectEqual(@as(f32, 2.0), parsed.seed.size_y.?);
    try std.testing.expectEqualStrings("recipes/zig-out/recipe.obj", parsed.output_path.?);
    try std.testing.expectEqual(@as(usize, 3), parsed.steps.items.len);
    try std.testing.expectEqual(Step.subdivide, parsed.steps.items[0].step);
    try std.testing.expectEqual(@as(usize, 2), parsed.steps.items[0].repeat);
    try std.testing.expectEqual(@as(f32, 0.75), parsed.steps.items[1].extrude_distance.?);
    try std.testing.expectEqual(@as(f32, 0.1), parsed.steps.items[2].inset_factor.?);
}

test "pipeline recipe args can override write path" {
    var temp = std.testing.tmpDir(.{});
    defer temp.cleanup();

    try temp.dir.writeFile(.{
        .sub_path = "authoring.bzrecipe",
        .data =
        \\seed=cuboid:size-x=3.0,size-y=2.0,size-z=1.5,verts-x=4,verts-y=3,verts-z=2,uvs=true
        \\write=zig-out/from-recipe.obj
        \\step=triangulate
        ,
    });

    const recipe_path = try temp.dir.realpathAlloc(std.testing.allocator, "authoring.bzrecipe");
    defer std.testing.allocator.free(recipe_path);

    var parsed = try parseArgs(std.testing.allocator, &[_][]const u8{
        "--recipe",
        recipe_path,
        "--write",
        "zig-out/from-cli.obj",
    });
    defer parsed.deinit(std.testing.allocator);

    try std.testing.expectEqual(Seed.cuboid, parsed.seed.seed);
    try std.testing.expectEqual(@as(f32, 3.0), parsed.seed.size_x.?);
    try std.testing.expectEqual(@as(usize, 4), parsed.seed.verts_x.?);
    try std.testing.expectEqual(@as(usize, 1), parsed.steps.items.len);
    try std.testing.expectEqualStrings("zig-out/from-cli.obj", parsed.output_path.?);
}

test "pipeline can build a parameterized modeling stack" {
    const steps = [_]StepSpec{
        .{ .step = .subdivide, .repeat = 2 },
        .{ .step = .extrude, .extrude_distance = 0.75 },
    };
    var mesh = try runMeshPipeline(std.testing.allocator, .{
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

test "pipeline can parse transform and array steps" {
    const translate = try parseStepSpec("translate:x=1.5,y=-0.25,z=2.0");
    const scale = try parseStepSpec("scale:x=0.5,y=2.0,z=1.0");
    const rotate = try parseStepSpec("rotate-z:degrees=22.5");
    const cleanup = try parseStepSpec("delete-loose:repeat=2");
    const extrude_region = try parseStepSpec("extrude-region:distance=0.8");
    const inset_region = try parseStepSpec("inset-region:width=0.2");
    const linear_array = try parseStepSpec("array:count=6,offset-x=1.5,offset-y=0.35,offset-z=0.0");
    const grid_array = try parseStepSpec("array:count-x=4,count-y=3,offset-x=1.35,offset-y=0.95");

    try std.testing.expectEqual(Step.translate, translate.step);
    try std.testing.expectEqual(@as(f32, 1.5), translate.translate_x.?);
    try std.testing.expectEqual(@as(f32, -0.25), translate.translate_y.?);
    try std.testing.expectEqual(Step.scale, scale.step);
    try std.testing.expectEqual(@as(f32, 2.0), scale.scale_y.?);
    try std.testing.expectEqual(Step.rotate_z, rotate.step);
    try std.testing.expectEqual(@as(f32, 22.5), rotate.rotate_degrees.?);
    try std.testing.expectEqual(Step.delete_loose, cleanup.step);
    try std.testing.expectEqual(@as(usize, 2), cleanup.repeat);
    try std.testing.expectEqual(Step.extrude_region, extrude_region.step);
    try std.testing.expectEqual(@as(f32, 0.8), extrude_region.extrude_distance.?);
    try std.testing.expectEqual(Step.inset_region, inset_region.step);
    try std.testing.expectEqual(@as(f32, 0.2), inset_region.inset_region_width.?);
    try std.testing.expectEqual(Step.array, linear_array.step);
    try std.testing.expectEqual(@as(usize, 6), linear_array.array_count.?);
    try std.testing.expectEqual(@as(f32, 1.5), linear_array.array_offset_x.?);
    try std.testing.expectEqual(@as(usize, 4), grid_array.array_count_x.?);
    try std.testing.expectEqual(@as(usize, 3), grid_array.array_count_y.?);
}

test "pipeline can build transform and array scenes" {
    const steps = [_]StepSpec{
        .{ .step = .scale, .scale_x = 0.45, .scale_y = 0.45, .scale_z = 1.0 },
        .{ .step = .array, .array_count_x = 4, .array_count_y = 3, .array_offset_x = 1.35, .array_offset_y = 0.95 },
        .{ .step = .rotate_z, .rotate_degrees = 12.0 },
        .{ .step = .translate, .translate_x = -2.0, .translate_y = -1.3, .translate_z = 0.0 },
    };

    var mesh = try runMeshPipeline(std.testing.allocator, .{
        .seed = .grid,
        .verts_x = 5,
        .verts_y = 4,
        .size_x = 4.0,
        .size_y = 2.5,
        .with_uvs = true,
    }, &steps);
    defer mesh.deinit();

    try std.testing.expectEqual(@as(usize, 240), mesh.vertexCount());
    try std.testing.expectEqual(@as(usize, 144), mesh.faceCount());
    try std.testing.expect(mesh.hasCornerUvs());
    try std.testing.expect(mesh.bounds != null);
    try std.testing.expect(mesh.bounds.?.max.x > mesh.bounds.?.min.x);
    try std.testing.expect(mesh.bounds.?.max.y > mesh.bounds.?.min.y);
}

test "pipeline can build region extrude shells" {
    const steps = [_]StepSpec{
        .{ .step = .extrude_region, .extrude_distance = 1.0 },
    };

    var mesh = try runMeshPipeline(std.testing.allocator, .{
        .seed = .grid,
        .verts_x = 3,
        .verts_y = 2,
        .size_x = 2.0,
        .size_y = 1.0,
        .with_uvs = true,
    }, &steps);
    defer mesh.deinit();

    try std.testing.expectEqual(@as(usize, 12), mesh.vertexCount());
    try std.testing.expectEqual(@as(usize, 10), mesh.faceCount());
    try std.testing.expectEqual(@as(usize, 20), mesh.edges.items.len);
    try std.testing.expect(mesh.hasCornerUvs());
}

test "pipeline can build region inset border rings" {
    const steps = [_]StepSpec{
        .{ .step = .inset_region, .inset_region_width = 0.2 },
    };

    var mesh = try runMeshPipeline(std.testing.allocator, .{
        .seed = .grid,
        .verts_x = 3,
        .verts_y = 2,
        .size_x = 2.0,
        .size_y = 1.0,
        .with_uvs = true,
    }, &steps);
    defer mesh.deinit();

    try std.testing.expectEqual(@as(usize, 12), mesh.vertexCount());
    try std.testing.expectEqual(@as(usize, 8), mesh.faceCount());
    try std.testing.expectEqual(@as(usize, 19), mesh.edges.items.len);
    try std.testing.expect(mesh.hasCornerUvs());
}

test "pipeline seed overrides parse equivalently inline and in recipes" {
    const inline_spec = try parseSeedSpec("cylinder:radius=1.25,height=3.0,segments=24,top-cap=true,bottom-cap=false,uvs=true");
    const from_recipe_text =
        \\seed=cylinder:radius=1.25,height=3.0,segments=24,top-cap=true,bottom-cap=false,uvs=true
        \\step=triangulate
        \\
    ;
    const owned_text = try std.testing.allocator.dupe(u8, from_recipe_text);
    var parsed = try parseRecipeText(std.testing.allocator, owned_text, "recipes/cylinder-panel-study.bzrecipe");
    defer parsed.deinit(std.testing.allocator);

    try std.testing.expectEqualDeep(inline_spec, parsed.seed);
}

test "pipeline seed overrides are deterministic across parameter order" {
    const ordered = try parseSeedSpec("grid:verts-x=8,verts-y=5,size-x=4.0,size-y=2.0,uvs=true");
    const reordered = try parseSeedSpec("grid:size-y=2.0,uvs=true,verts-y=5,size-x=4.0,verts-x=8");

    try std.testing.expectEqualDeep(ordered, reordered);
}

test "pipeline seed overrides preserve default behavior when defaults are explicit" {
    const implicit_steps = [_]StepSpec{
        .{ .step = .subdivide },
        .{ .step = .extrude, .extrude_distance = 0.75 },
    };
    var implicit = try runMeshPipeline(std.testing.allocator, .{ .seed = .grid }, &implicit_steps);
    defer implicit.deinit();

    var explicit = try runMeshPipeline(std.testing.allocator, .{
        .seed = .grid,
        .verts_x = 3,
        .verts_y = 2,
        .size_x = 2.0,
        .size_y = 1.0,
        .with_uvs = true,
    }, &implicit_steps);
    defer explicit.deinit();

    try std.testing.expectEqual(implicit.vertexCount(), explicit.vertexCount());
    try std.testing.expectEqual(implicit.faceCount(), explicit.faceCount());
    try std.testing.expectEqual(implicit.edges.items.len, explicit.edges.items.len);
    try std.testing.expectEqualDeep(implicit.corner_verts.items, explicit.corner_verts.items);
}

test "pipeline seed overrides support partial override merges" {
    const spec = try parseSeedSpec("sphere:segments=16");

    try std.testing.expectEqual(Seed.sphere, spec.seed);
    try std.testing.expectEqual(@as(usize, 16), spec.segments.?);
    try std.testing.expect(spec.radius == null);
    try std.testing.expect(spec.rings == null);
    try std.testing.expect(spec.with_uvs == null);
}

test "pipeline seed overrides build the same mesh inline and from recipe text" {
    const steps = [_]StepSpec{
        .{ .step = .subdivide, .repeat = 2 },
        .{ .step = .extrude, .extrude_distance = 0.75 },
        .{ .step = .inset, .inset_factor = 0.1 },
    };
    const inline_seed = try parseSeedSpec("grid:verts-x=8,verts-y=5,size-x=4.0,size-y=2.0,uvs=true");
    var inline_mesh = try runMeshPipeline(std.testing.allocator, inline_seed, &steps);
    defer inline_mesh.deinit();

    const recipe_text =
        \\seed=grid:verts-x=8,verts-y=5,size-x=4.0,size-y=2.0,uvs=true
        \\step=subdivide:repeat=2
        \\step=extrude:distance=0.75
        \\step=inset:factor=0.1
        \\
    ;
    const owned_text = try std.testing.allocator.dupe(u8, recipe_text);
    var parsed = try parseRecipeText(std.testing.allocator, owned_text, "recipes/grid-study.bzrecipe");
    defer parsed.deinit(std.testing.allocator);

    var recipe_mesh = try runMeshPipeline(std.testing.allocator, parsed.seed, parsed.steps.items);
    defer recipe_mesh.deinit();

    try std.testing.expectEqual(inline_mesh.vertexCount(), recipe_mesh.vertexCount());
    try std.testing.expectEqual(inline_mesh.faceCount(), recipe_mesh.faceCount());
    try std.testing.expectEqual(inline_mesh.edges.items.len, recipe_mesh.edges.items.len);
    try std.testing.expectEqualDeep(inline_mesh.positions.items, recipe_mesh.positions.items);
    try std.testing.expectEqualDeep(inline_mesh.edges.items, recipe_mesh.edges.items);
    try std.testing.expectEqualDeep(inline_mesh.face_offsets.items, recipe_mesh.face_offsets.items);
    try std.testing.expectEqualDeep(inline_mesh.corner_verts.items, recipe_mesh.corner_verts.items);
    try std.testing.expectEqualDeep(inline_mesh.corner_edges.items, recipe_mesh.corner_edges.items);
    try std.testing.expectEqualDeep(inline_mesh.corner_uvs.items, recipe_mesh.corner_uvs.items);
}

test "pipeline rejects unsupported parameters for a step" {
    try std.testing.expectError(error.UnsupportedPipelineParameter, parseStepSpec("triangulate:distance=1"));
    try std.testing.expectError(error.UnsupportedPipelineParameter, parseStepSpec("delete-loose:distance=1"));
}

test "pipeline rejects unsupported or duplicate seed parameters" {
    try std.testing.expectError(error.UnsupportedSeedParameter, parseSeedSpec("grid:segments=8"));
    try std.testing.expectError(error.DuplicateSeedParameter, parseSeedSpec("grid:verts-x=8,verts-x=9"));
}

test "pipeline rejects invalid seed values and malformed syntax" {
    try std.testing.expectError(error.InvalidPipelineBool, parseSeedSpec("cylinder:top-cap=yes"));
    try std.testing.expectError(error.InvalidPipelineSeedSyntax, parseSeedSpec("grid:verts-x=8=9"));
    try std.testing.expectError(error.InvalidPipelineRepeat, parseSeedSpec("sphere:segments=0"));
}

test "pipeline rejects invalid array modes" {
    try std.testing.expectError(error.MissingPipelineArrayCount, parseStepSpec("array:offset-x=1.0"));
    try std.testing.expectError(error.InvalidPipelineArrayMode, parseStepSpec("array:count=4,count-x=2,offset-x=1.0"));
}

test "pipeline recipe rejects mixed inline and file sources" {
    try std.testing.expectError(error.MixedPipelineSources, parseArgs(std.testing.allocator, &[_][]const u8{
        "--recipe",
        "recipes/grid-study.bzrecipe",
        "grid",
    }));
}

test "pipeline recipe requires a recipe path" {
    try std.testing.expectError(error.MissingPipelineRecipePath, parseArgs(std.testing.allocator, &[_][]const u8{
        "--recipe",
    }));
}

test "pipeline recipe surfaces file loading errors" {
    try std.testing.expectError(error.FileNotFound, parseArgs(std.testing.allocator, &[_][]const u8{
        "--recipe",
        "recipes/does-not-exist.bzrecipe",
    }));
}

test "pipeline recipe rejects missing seed" {
    const recipe_text =
        \\step=triangulate
        \\step=extrude:distance=0.5
        \\
    ;
    const owned_text = try std.testing.allocator.dupe(u8, recipe_text);
    try std.testing.expectError(
        error.MissingRecipeSeed,
        parseRecipeText(std.testing.allocator, owned_text, "recipes/missing-seed.bzrecipe"),
    );
}

test "pipeline recipe rejects duplicate keys and unknown keys" {
    {
        const owned_text = try std.testing.allocator.dupe(
            u8,
            \\seed=grid
            \\seed=cuboid
            ,
        );
        try std.testing.expectError(
            error.DuplicateRecipeSeed,
            parseRecipeText(std.testing.allocator, owned_text, "recipes/duplicate-seed.bzrecipe"),
        );
    }
    {
        const owned_text = try std.testing.allocator.dupe(
            u8,
            \\seed=grid
            \\color=red
            ,
        );
        try std.testing.expectError(
            error.UnknownRecipeKey,
            parseRecipeText(std.testing.allocator, owned_text, "recipes/unknown-key.bzrecipe"),
        );
    }
}

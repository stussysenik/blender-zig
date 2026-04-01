const std = @import("std");
const obj = @import("io/obj.zig");
const mesh_transform = @import("geometry/mesh_transform.zig");
const mesh_mod = @import("mesh.zig");
const pipeline = @import("pipeline.zig");
const replay_metadata = @import("replay_metadata.zig");

pub const PartKind = enum {
    pipeline_recipe,
    obj_mesh,
};

pub const PartSpec = struct {
    kind: PartKind,
    path: []u8,
    placement_steps: std.ArrayList(pipeline.StepSpec),
};

pub const ParsedArgs = struct {
    metadata: replay_metadata.ReplayMetadata = .{},
    parts: std.ArrayList(PartSpec),
    output_path: ?[]const u8,
    owned_scene_text: ?[]u8 = null,
    owned_output_path: ?[]u8 = null,

    pub fn deinit(self: *ParsedArgs, allocator: std.mem.Allocator) void {
        for (self.parts.items) |*part| {
            allocator.free(part.path);
            part.placement_steps.deinit(allocator);
        }
        self.parts.deinit(allocator);
        if (self.owned_scene_text) |buffer| allocator.free(buffer);
        if (self.owned_output_path) |buffer| allocator.free(buffer);
        allocator.destroy(self);
    }
};

pub fn parseArgs(allocator: std.mem.Allocator, args: []const []const u8) !*ParsedArgs {
    var recipe_path: ?[]const u8 = null;
    var output_path: ?[]const u8 = null;

    var index: usize = 0;
    while (index < args.len) : (index += 1) {
        const token = args[index];
        if (std.mem.eql(u8, token, "--write")) {
            if (index + 1 >= args.len) return error.MissingSceneOutputPath;
            if (output_path != null) return error.DuplicateSceneOutputPath;
            output_path = args[index + 1];
            index += 1;
            continue;
        }
        if (std.mem.eql(u8, token, "--recipe")) {
            if (index + 1 >= args.len) return error.MissingSceneRecipePath;
            if (recipe_path != null) return error.DuplicateSceneRecipePath;
            recipe_path = args[index + 1];
            index += 1;
            continue;
        }
        return error.UnexpectedSceneArgument;
    }

    const scene_path = recipe_path orelse return error.MissingSceneRecipePath;
    var parsed = try parseSceneFile(allocator, scene_path);
    if (output_path) |write_path| {
        parsed.output_path = write_path;
    }
    return parsed;
}

pub fn runMeshScene(allocator: std.mem.Allocator, parsed: *const ParsedArgs) !mesh_mod.Mesh {
    var scene_mesh = try mesh_mod.Mesh.init(allocator);
    errdefer scene_mesh.deinit();

    for (parsed.parts.items) |part| {
        var part_mesh = switch (part.kind) {
            .pipeline_recipe => blk: {
                var pipeline_args = pipeline.parseArgs(allocator, &[_][]const u8{ "--recipe", part.path }) catch |err| switch (err) {
                    error.FileNotFound => return error.ScenePartFileNotFound,
                    else => return err,
                };
                defer pipeline_args.deinit(allocator);

                break :blk try pipeline.runMeshPipeline(allocator, pipeline_args.seed, pipeline_args.steps.items);
            },
            .obj_mesh => blk: {
                var imported = obj.readFile(allocator, part.path) catch |err| switch (err) {
                    error.FileNotFound => return error.ScenePartFileNotFound,
                    else => return err,
                };
                defer imported.deinit();

                switch (imported) {
                    .mesh => |*mesh| break :blk try mesh.clone(allocator),
                    .parse_failure => |_| return error.InvalidScenePartImport,
                }
            },
        };
        defer part_mesh.deinit();

        var placed_mesh = try applyPlacementSteps(allocator, &part_mesh, part.placement_steps.items);
        defer placed_mesh.deinit();

        try scene_mesh.appendMesh(&placed_mesh);
    }

    return scene_mesh;
}

// Scene parts can reuse the same transform vocabulary as `mesh-pipeline`, but only
// for placement. The source study keeps its own modeling history while the scene file
// controls where each piece lands in the final composed mesh.
fn applyPlacementSteps(
    allocator: std.mem.Allocator,
    source_mesh: *const mesh_mod.Mesh,
    placement_steps: []const pipeline.StepSpec,
) !mesh_mod.Mesh {
    var mesh = try source_mesh.clone(allocator);
    errdefer mesh.deinit();

    for (placement_steps) |step| {
        const next_mesh = switch (step.step) {
            .translate => try mesh_transform.translateMesh(allocator, &mesh, .{
                .x = step.translate_x orelse 0.0,
                .y = step.translate_y orelse 0.0,
                .z = step.translate_z orelse 0.0,
            }),
            .scale => try mesh_transform.scaleMesh(allocator, &mesh, .{
                .x = step.scale_x orelse 1.0,
                .y = step.scale_y orelse 1.0,
                .z = step.scale_z orelse 1.0,
            }),
            .rotate_z => try mesh_transform.rotateMeshZ(
                allocator,
                &mesh,
                std.math.degreesToRadians(step.rotate_degrees orelse 0.0),
            ),
            else => return error.UnsupportedScenePlacementStep,
        };
        mesh.deinit();
        mesh = next_mesh;
    }

    return mesh;
}

fn parseSceneFile(allocator: std.mem.Allocator, scene_path: []const u8) !*ParsedArgs {
    const scene_text = try std.fs.cwd().readFileAlloc(allocator, scene_path, std.math.maxInt(usize));
    return parseSceneText(allocator, scene_text, scene_path);
}

fn parseSceneText(
    allocator: std.mem.Allocator,
    owned_scene_text: []u8,
    scene_path: []const u8,
) !*ParsedArgs {
    var parsed = allocator.create(ParsedArgs) catch |err| {
        allocator.free(owned_scene_text);
        return err;
    };
    parsed.* = .{
        .metadata = .{},
        .parts = .empty,
        .output_path = null,
        .owned_scene_text = owned_scene_text,
        .owned_output_path = null,
    };
    errdefer parsed.deinit(allocator);

    var seen_metadata = replay_metadata.SeenFields{};
    var lines = std.mem.splitScalar(u8, owned_scene_text, '\n');
    while (lines.next()) |line| {
        const trimmed = std.mem.trim(u8, line, " \t\r");
        if (trimmed.len == 0 or trimmed[0] == '#') continue;

        const separator_index = std.mem.indexOfScalar(u8, trimmed, '=') orelse return error.InvalidSceneLineSyntax;
        const key = std.mem.trim(u8, trimmed[0..separator_index], " \t");
        const value = std.mem.trim(u8, trimmed[separator_index + 1 ..], " \t");
        if (value.len == 0) return error.InvalidSceneLineSyntax;

        if (try replay_metadata.parseMetadataLine(&parsed.metadata, &seen_metadata, key, value)) {
            continue;
        }

        if (std.mem.eql(u8, key, "write")) {
            if (parsed.output_path != null) return error.DuplicateSceneWritePath;
            const resolved = try resolveScenePath(allocator, scene_path, value);
            parsed.owned_output_path = resolved;
            parsed.output_path = resolved;
            continue;
        }
        if (std.mem.eql(u8, key, "part")) {
            var part = try parsePartSpec(allocator, scene_path, value);
            errdefer {
                allocator.free(part.path);
                part.placement_steps.deinit(allocator);
            }
            try parsed.parts.append(allocator, part);
            continue;
        }

        return error.UnknownSceneKey;
    }

    if (parsed.parts.items.len == 0) return error.MissingScenePart;
    return parsed;
}

fn parsePartSpec(
    allocator: std.mem.Allocator,
    scene_path: []const u8,
    part_value: []const u8,
) !PartSpec {
    var tokens = std.mem.splitScalar(u8, part_value, '|');
    const raw_path = std.mem.trim(u8, tokens.first(), " \t");
    if (raw_path.len == 0) return error.InvalidScenePartSyntax;

    const resolved = try resolveScenePath(allocator, scene_path, raw_path);
    errdefer allocator.free(resolved);

    var placement_steps = std.ArrayList(pipeline.StepSpec).empty;
    errdefer placement_steps.deinit(allocator);

    while (tokens.next()) |raw_token| {
        const token = std.mem.trim(u8, raw_token, " \t");
        if (token.len == 0) return error.InvalidScenePartSyntax;

        const placement = try pipeline.parseStepSpec(token);
        switch (placement.step) {
            .translate, .scale, .rotate_z => {},
            else => return error.UnsupportedScenePlacementStep,
        }
        try placement_steps.append(allocator, placement);
    }

    return .{
        .kind = try inferPartKind(resolved),
        .path = resolved,
        .placement_steps = placement_steps,
    };
}

fn resolveScenePath(
    allocator: std.mem.Allocator,
    scene_path: []const u8,
    child_path: []const u8,
) ![]u8 {
    if (std.fs.path.isAbsolute(child_path)) {
        return allocator.dupe(u8, child_path);
    }
    const scene_dir = std.fs.path.dirname(scene_path) orelse {
        return allocator.dupe(u8, child_path);
    };
    return std.fs.path.resolve(allocator, &.{ scene_dir, child_path });
}

fn inferPartKind(path: []const u8) !PartKind {
    if (std.mem.endsWith(u8, path, ".bzrecipe")) return .pipeline_recipe;
    if (std.mem.endsWith(u8, path, ".obj")) return .obj_mesh;
    return error.UnsupportedScenePartFormat;
}

test "scene args parse recipe parts and CLI write override" {
    var temp = std.testing.tmpDir(.{});
    defer temp.cleanup();

    try temp.dir.writeFile(.{
        .sub_path = "part-a.bzrecipe",
        .data =
        \\seed=grid
        \\step=triangulate
        ,
    });
    try temp.dir.writeFile(.{
        .sub_path = "scene.bzscene",
        .data =
        \\write=zig-out/from-scene.obj
        \\part=part-a.bzrecipe
        ,
    });

    const scene_path = try temp.dir.realpathAlloc(std.testing.allocator, "scene.bzscene");
    defer std.testing.allocator.free(scene_path);

    var parsed = try parseArgs(std.testing.allocator, &[_][]const u8{
        "--recipe",
        scene_path,
        "--write",
        "zig-out/from-cli.obj",
    });
    defer parsed.deinit(std.testing.allocator);

    try std.testing.expectEqual(@as(usize, 1), parsed.parts.items.len);
    try std.testing.expectEqual(PartKind.pipeline_recipe, parsed.parts.items[0].kind);
    try std.testing.expectEqual(@as(usize, 0), parsed.parts.items[0].placement_steps.items.len);
    try std.testing.expectEqualStrings("zig-out/from-cli.obj", parsed.output_path.?);
}

test "scene can parse replay metadata from a persisted scene file" {
    var temp = std.testing.tmpDir(.{});
    defer temp.cleanup();

    try temp.dir.writeFile(.{
        .sub_path = "part-a.bzrecipe",
        .data =
        \\seed=grid
        ,
    });
    try temp.dir.writeFile(.{
        .sub_path = "scene.bzscene",
        .data =
        \\format-version=1
        \\id=phase-17/modeling-bench
        \\title=Phase 17 Modeling Bench
        \\part=part-a.bzrecipe
        ,
    });

    const scene_path = try temp.dir.realpathAlloc(std.testing.allocator, "scene.bzscene");
    defer std.testing.allocator.free(scene_path);

    var parsed = try parseArgs(std.testing.allocator, &[_][]const u8{ "--recipe", scene_path });
    defer parsed.deinit(std.testing.allocator);

    try std.testing.expectEqual(@as(u32, 1), parsed.metadata.format_version);
    try std.testing.expectEqualStrings("phase-17/modeling-bench", parsed.metadata.id.?);
    try std.testing.expectEqualStrings("Phase 17 Modeling Bench", parsed.metadata.title.?);
}

test "scene rejects unsupported replay metadata format versions" {
    var temp = std.testing.tmpDir(.{});
    defer temp.cleanup();

    try temp.dir.writeFile(.{
        .sub_path = "scene.bzscene",
        .data =
        \\format-version=2
        \\part=piece.obj
        ,
    });

    const scene_path = try temp.dir.realpathAlloc(std.testing.allocator, "scene.bzscene");
    defer std.testing.allocator.free(scene_path);

    try std.testing.expectError(
        error.UnsupportedReplayFormatVersion,
        parseArgs(std.testing.allocator, &[_][]const u8{ "--recipe", scene_path }),
    );
}

test "scene runtime composes multiple pipeline recipes into one mesh" {
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

    var parsed = try parseArgs(std.testing.allocator, &[_][]const u8{ "--recipe", scene_path });
    defer parsed.deinit(std.testing.allocator);

    var mesh = try runMeshScene(std.testing.allocator, parsed);
    defer mesh.deinit();

    try std.testing.expectEqual(@as(usize, 14), mesh.vertexCount());
    try std.testing.expectEqual(@as(usize, 10), mesh.faceCount());
    try std.testing.expect(mesh.hasCornerUvs());
}

test "scene runtime applies per-part placement steps in file order" {
    var temp = std.testing.tmpDir(.{});
    defer temp.cleanup();

    try temp.dir.writeFile(.{
        .sub_path = "tower.bzrecipe",
        .data =
        \\seed=cuboid:size-x=1.0,size-y=3.0,size-z=2.0,verts-x=2,verts-y=2,verts-z=2,uvs=true
        ,
    });
    try temp.dir.writeFile(.{
        .sub_path = "scene.bzscene",
        .data =
        \\part=tower.bzrecipe|translate:x=3.0,y=1.0,z=2.0|rotate-z:degrees=90
        ,
    });

    const scene_path = try temp.dir.realpathAlloc(std.testing.allocator, "scene.bzscene");
    defer std.testing.allocator.free(scene_path);

    var parsed = try parseArgs(std.testing.allocator, &[_][]const u8{ "--recipe", scene_path });
    defer parsed.deinit(std.testing.allocator);

    try std.testing.expectEqual(@as(usize, 2), parsed.parts.items[0].placement_steps.items.len);

    var mesh = try runMeshScene(std.testing.allocator, parsed);
    defer mesh.deinit();

    try std.testing.expectEqual(@as(usize, 8), mesh.vertexCount());
    try std.testing.expect(mesh.bounds != null);
    try std.testing.expectApproxEqAbs(@as(f32, -2.5), mesh.bounds.?.min.x, 0.0001);
    try std.testing.expectApproxEqAbs(@as(f32, 0.5), mesh.bounds.?.max.x, 0.0001);
    try std.testing.expectApproxEqAbs(@as(f32, 2.5), mesh.bounds.?.min.y, 0.0001);
    try std.testing.expectApproxEqAbs(@as(f32, 3.5), mesh.bounds.?.max.y, 0.0001);
    try std.testing.expectApproxEqAbs(@as(f32, 1.0), mesh.bounds.?.min.z, 0.0001);
    try std.testing.expectApproxEqAbs(@as(f32, 3.0), mesh.bounds.?.max.z, 0.0001);
}

test "scene runtime composes recipe parts even when only some parts keep corner uvs" {
    var temp = std.testing.tmpDir(.{});
    defer temp.cleanup();

    try temp.dir.writeFile(.{
        .sub_path = "wire.bzrecipe",
        .data =
        \\seed=grid:verts-x=3,verts-y=2,size-x=4.0,size-y=2.0,uvs=true
        \\step=delete-edge
        \\step=fill-hole
        ,
    });
    try temp.dir.writeFile(.{
        .sub_path = "panel.bzrecipe",
        .data =
        \\seed=grid:verts-x=3,verts-y=2,size-x=2.0,size-y=1.0,uvs=true
        \\step=inset-region:width=0.15
        ,
    });
    try temp.dir.writeFile(.{
        .sub_path = "scene.bzscene",
        .data =
        \\part=wire.bzrecipe
        \\part=panel.bzrecipe|translate:x=3.0,y=0.0,z=0.0
        ,
    });

    const scene_path = try temp.dir.realpathAlloc(std.testing.allocator, "scene.bzscene");
    defer std.testing.allocator.free(scene_path);

    var parsed = try parseArgs(std.testing.allocator, &[_][]const u8{ "--recipe", scene_path });
    defer parsed.deinit(std.testing.allocator);

    var mesh = try runMeshScene(std.testing.allocator, parsed);
    defer mesh.deinit();

    try std.testing.expect(mesh.hasCornerUvs());
    try std.testing.expectEqual(mesh.corner_verts.items.len, mesh.corner_uvs.items.len);
    try std.testing.expectEqual(@as(usize, 18), mesh.vertexCount());
    try std.testing.expectEqual(@as(usize, 9), mesh.faceCount());
}

test "scene runtime can combine recipe parts with imported obj parts" {
    var temp = std.testing.tmpDir(.{});
    defer temp.cleanup();

    try temp.dir.writeFile(.{
        .sub_path = "part.bzrecipe",
        .data =
        \\seed=cuboid:size-x=1.0,size-y=1.0,size-z=1.0,verts-x=2,verts-y=2,verts-z=2,uvs=true
        ,
    });
    try temp.dir.writeFile(.{
        .sub_path = "piece.obj",
        .data =
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
        ,
    });
    try temp.dir.writeFile(.{
        .sub_path = "scene.bzscene",
        .data =
        \\part=piece.obj
        \\part=part.bzrecipe
        ,
    });

    const scene_path = try temp.dir.realpathAlloc(std.testing.allocator, "scene.bzscene");
    defer std.testing.allocator.free(scene_path);

    var parsed = try parseArgs(std.testing.allocator, &[_][]const u8{ "--recipe", scene_path });
    defer parsed.deinit(std.testing.allocator);

    var mesh = try runMeshScene(std.testing.allocator, parsed);
    defer mesh.deinit();

    try std.testing.expectEqual(@as(usize, 12), mesh.vertexCount());
    try std.testing.expectEqual(@as(usize, 7), mesh.faceCount());
    try std.testing.expect(mesh.hasCornerUvs());
}

test "scene runtime fails clearly when a scene part file is missing" {
    var temp = std.testing.tmpDir(.{});
    defer temp.cleanup();

    try temp.dir.writeFile(.{
        .sub_path = "scene.bzscene",
        .data =
        \\part=missing.obj
        ,
    });

    const scene_path = try temp.dir.realpathAlloc(std.testing.allocator, "scene.bzscene");
    defer std.testing.allocator.free(scene_path);

    var parsed = try parseArgs(std.testing.allocator, &[_][]const u8{ "--recipe", scene_path });
    defer parsed.deinit(std.testing.allocator);

    try std.testing.expectError(error.ScenePartFileNotFound, runMeshScene(std.testing.allocator, parsed));
}

test "scene recipe rejects unsupported part formats" {
    var temp = std.testing.tmpDir(.{});
    defer temp.cleanup();

    try temp.dir.writeFile(.{
        .sub_path = "scene.bzscene",
        .data =
        \\part=thing.ply
        ,
    });

    const scene_path = try temp.dir.realpathAlloc(std.testing.allocator, "scene.bzscene");
    defer std.testing.allocator.free(scene_path);

    try std.testing.expectError(
        error.UnsupportedScenePartFormat,
        parseArgs(std.testing.allocator, &[_][]const u8{ "--recipe", scene_path }),
    );
}

test "scene recipe rejects unsupported placement steps" {
    var temp = std.testing.tmpDir(.{});
    defer temp.cleanup();

    try temp.dir.writeFile(.{
        .sub_path = "part.bzrecipe",
        .data =
        \\seed=grid
        ,
    });
    try temp.dir.writeFile(.{
        .sub_path = "scene.bzscene",
        .data =
        \\part=part.bzrecipe|extrude:distance=0.5
        ,
    });

    const scene_path = try temp.dir.realpathAlloc(std.testing.allocator, "scene.bzscene");
    defer std.testing.allocator.free(scene_path);

    try std.testing.expectError(
        error.UnsupportedScenePlacementStep,
        parseArgs(std.testing.allocator, &[_][]const u8{ "--recipe", scene_path }),
    );
}

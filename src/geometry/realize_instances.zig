const std = @import("std");
const curves_mod = @import("curves.zig");
const math = @import("../math.zig");

pub const InstanceTransform = struct {
    translation: math.Vec3 = math.Vec3.init(0, 0, 0),

    pub fn identity() InstanceTransform {
        return .{};
    }

    pub fn apply(self: InstanceTransform, position: math.Vec3) math.Vec3 {
        return position.add(self.translation);
    }
};

pub const GeometrySet = struct {
    allocator: std.mem.Allocator,
    curves: ?curves_mod.CurvesGeometry = null,
    instances: ?Instances = null,

    pub fn init(allocator: std.mem.Allocator) GeometrySet {
        return .{ .allocator = allocator };
    }

    pub fn fromCurvesOwned(allocator: std.mem.Allocator, curves: curves_mod.CurvesGeometry) GeometrySet {
        return .{
            .allocator = allocator,
            .curves = curves,
        };
    }

    pub fn fromCurvesClone(allocator: std.mem.Allocator, curves: *const curves_mod.CurvesGeometry) std.mem.Allocator.Error!GeometrySet {
        return .{
            .allocator = allocator,
            .curves = try curves.clone(allocator),
        };
    }

    pub fn fromInstancesOwned(allocator: std.mem.Allocator, instances: Instances) GeometrySet {
        return .{
            .allocator = allocator,
            .instances = instances,
        };
    }

    pub fn deinit(self: *GeometrySet) void {
        if (self.curves) |*curves| {
            curves.deinit();
            self.curves = null;
        }
        if (self.instances) |*instances| {
            instances.deinit();
            self.instances = null;
        }
    }

    pub fn clone(self: *const GeometrySet, allocator: std.mem.Allocator) std.mem.Allocator.Error!GeometrySet {
        var cloned = GeometrySet.init(allocator);
        errdefer cloned.deinit();

        if (self.curves) |*curves| {
            cloned.curves = try curves.clone(allocator);
        }
        if (self.instances) |*instances| {
            cloned.instances = try instances.clone(allocator);
        }
        return cloned;
    }
};

pub const NamedInstanceFloatAttribute = struct {
    name: []u8,
    values: std.ArrayList(f32) = .empty,

    fn init(allocator: std.mem.Allocator, name: []const u8) std.mem.Allocator.Error!NamedInstanceFloatAttribute {
        return .{
            .name = try allocator.dupe(u8, name),
        };
    }

    fn deinit(self: *NamedInstanceFloatAttribute, allocator: std.mem.Allocator) void {
        allocator.free(self.name);
        self.values.deinit(allocator);
    }

    fn clone(self: *const NamedInstanceFloatAttribute, allocator: std.mem.Allocator) std.mem.Allocator.Error!NamedInstanceFloatAttribute {
        var copy = try NamedInstanceFloatAttribute.init(allocator, self.name);
        errdefer copy.deinit(allocator);
        try copy.values.appendSlice(allocator, self.values.items);
        return copy;
    }
};

pub const Instance = struct {
    handle: u32,
    transform: InstanceTransform,
};

pub const Instances = struct {
    allocator: std.mem.Allocator,
    references: std.ArrayList(GeometrySet) = .empty,
    items: std.ArrayList(Instance) = .empty,
    float_attributes: std.ArrayList(NamedInstanceFloatAttribute) = .empty,

    pub fn init(allocator: std.mem.Allocator) Instances {
        return .{ .allocator = allocator };
    }

    pub fn deinit(self: *Instances) void {
        for (self.references.items) |*reference| {
            reference.deinit();
        }
        self.references.deinit(self.allocator);
        self.items.deinit(self.allocator);
        for (self.float_attributes.items) |*attribute| {
            attribute.deinit(self.allocator);
        }
        self.float_attributes.deinit(self.allocator);
    }

    pub fn clone(self: *const Instances, allocator: std.mem.Allocator) std.mem.Allocator.Error!Instances {
        var copy = Instances.init(allocator);
        errdefer copy.deinit();

        for (self.references.items) |*reference| {
            try copy.references.append(allocator, try reference.clone(allocator));
        }
        try copy.items.appendSlice(allocator, self.items.items);
        for (self.float_attributes.items) |*attribute| {
            try copy.float_attributes.append(allocator, try attribute.clone(allocator));
        }
        return copy;
    }

    pub fn addReference(self: *Instances, geometry: GeometrySet) std.mem.Allocator.Error!u32 {
        try self.references.append(self.allocator, geometry);
        return @intCast(self.references.items.len - 1);
    }

    pub fn addInstance(self: *Instances, handle: u32, transform: InstanceTransform) std.mem.Allocator.Error!void {
        std.debug.assert(handle < self.references.items.len);
        try self.items.append(self.allocator, .{
            .handle = handle,
            .transform = transform,
        });
        for (self.float_attributes.items) |*attribute| {
            try attribute.values.append(self.allocator, 0.0);
        }
    }

    pub fn addFloatAttribute(self: *Instances, name: []const u8, default_value: f32) std.mem.Allocator.Error!void {
        var attribute = try NamedInstanceFloatAttribute.init(self.allocator, name);
        errdefer attribute.deinit(self.allocator);
        for (0..self.items.items.len) |_| {
            try attribute.values.append(self.allocator, default_value);
        }
        try self.float_attributes.append(self.allocator, attribute);
    }
};

pub const RealizeInstancesOptions = struct {
    realize_instance_attributes: bool = true,
};

pub const RealizeInstancesResult = struct {
    geometry: GeometrySet,
};

pub fn realizeInstances(
    allocator: std.mem.Allocator,
    geometry_set: *const GeometrySet,
    options: RealizeInstancesOptions,
) std.mem.Allocator.Error!RealizeInstancesResult {
    if (geometry_set.instances == null) {
        return .{ .geometry = try geometry_set.clone(allocator) };
    }

    const instances = &geometry_set.instances.?;
    var dst_curves = try curves_mod.CurvesGeometry.init(allocator);
    errdefer dst_curves.deinit();

    for (instances.items.items, 0..) |instance, instance_index| {
        const reference = &instances.references.items[instance.handle];
        if (reference.curves == null) continue;

        const src_curves = &reference.curves.?;
        for (0..src_curves.curvesNum()) |curve_index| {
            const range = src_curves.pointsByCurve(curve_index);
            const point_count = range.end - range.start;
            const positions = try allocator.alloc(math.Vec3, point_count);
            defer allocator.free(positions);
            const test_indices = try allocator.alloc(i32, point_count);
            defer allocator.free(test_indices);

            for (0..point_count) |local_index| {
                const src_index = range.start + local_index;
                positions[local_index] = instance.transform.apply(src_curves.positions.items[src_index]);
                test_indices[local_index] = src_curves.point_test_index.items[src_index];
            }

            try dst_curves.appendCurve(positions, src_curves.cyclic.items[curve_index], test_indices);
        }

        if (options.realize_instance_attributes) {
            for (instances.float_attributes.items) |*attribute| {
                if (isRestrictedCurveBuiltinAttribute(attribute.name)) {
                    continue;
                }
                try dst_curves.appendPointFloatAttributeRepeated(
                    attribute.name,
                    attribute.values.items[instance_index],
                    src_curves.pointsNum(),
                );
            }
        }
    }

    return .{ .geometry = GeometrySet.fromCurvesOwned(allocator, dst_curves) };
}

fn isRestrictedCurveBuiltinAttribute(name: []const u8) bool {
    return std.mem.eql(u8, name, "curve_type");
}

fn createRealizeTestCurves(allocator: std.mem.Allocator) !curves_mod.CurvesGeometry {
    var curves = try curves_mod.CurvesGeometry.init(allocator);
    errdefer curves.deinit();

    const positions = [_]math.Vec3{
        math.Vec3.init(0, 0, 0),
        math.Vec3.init(1, 0, 0),
        math.Vec3.init(2, 0, 0),
    };
    const test_index = [_]i32{ 0, 1, 2 };
    try curves.appendCurve(&positions, false, &test_index);
    return curves;
}

test "realize instances ignores restricted curve builtin instance attribute" {
    var source_curves = try createRealizeTestCurves(std.testing.allocator);
    defer source_curves.deinit();

    var instances = Instances.init(std.testing.allocator);

    const handle = try instances.addReference(try GeometrySet.fromCurvesClone(std.testing.allocator, &source_curves));
    try instances.addInstance(handle, InstanceTransform.identity());
    try instances.addInstance(handle, InstanceTransform.identity());
    try instances.addFloatAttribute("curve_type", 0.0);

    var instances_geometry = GeometrySet.fromInstancesOwned(std.testing.allocator, instances);
    defer instances_geometry.deinit();

    const result = try realizeInstances(std.testing.allocator, &instances_geometry, .{ .realize_instance_attributes = true });
    defer {
        var geometry = result.geometry;
        geometry.deinit();
    }

    try std.testing.expect(result.geometry.curves != null);
    const realized = &result.geometry.curves.?;
    try std.testing.expectEqual(@as(usize, 6), realized.pointsNum());
    try std.testing.expectEqual(@as(usize, 2), realized.curvesNum());
    try std.testing.expectEqualSlices(u32, &[_]u32{ 0, 3, 6 }, realized.offsets());
    try std.testing.expectEqualSlices(i32, &[_]i32{ 0, 1, 2, 0, 1, 2 }, realized.testIndices());
    try std.testing.expect(realized.getPointFloatAttribute("curve_type") == null);
}

test "realize instances copies generic instance attribute to points" {
    var source_curves = try createRealizeTestCurves(std.testing.allocator);
    defer source_curves.deinit();

    var instances = Instances.init(std.testing.allocator);

    const handle = try instances.addReference(try GeometrySet.fromCurvesClone(std.testing.allocator, &source_curves));
    try instances.addInstance(handle, InstanceTransform.identity());
    try instances.addInstance(handle, .{ .translation = math.Vec3.init(10, 0, 0) });
    try instances.addFloatAttribute("weight", 0.5);

    instances.float_attributes.items[0].values.items[1] = 1.5;

    var instances_geometry = GeometrySet.fromInstancesOwned(std.testing.allocator, instances);
    defer instances_geometry.deinit();

    const result = try realizeInstances(std.testing.allocator, &instances_geometry, .{ .realize_instance_attributes = true });
    defer {
        var geometry = result.geometry;
        geometry.deinit();
    }

    const realized = &result.geometry.curves.?;
    const weight = realized.getPointFloatAttribute("weight").?;
    try std.testing.expectEqualSlices(f32, &[_]f32{ 0.5, 0.5, 0.5, 1.5, 1.5, 1.5 }, weight);
    try std.testing.expect(math.vec3ApproxEq(realized.positions.items[3], math.Vec3.init(10, 0, 0), 0.0001));
    try std.testing.expect(math.vec3ApproxEq(realized.positions.items[5], math.Vec3.init(12, 0, 0), 0.0001));
}

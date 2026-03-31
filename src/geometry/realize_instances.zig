const std = @import("std");
const curves_mod = @import("curves.zig");
const math = @import("../math.zig");
const mesh_mod = @import("../mesh.zig");

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
    mesh: ?mesh_mod.Mesh = null,
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

    pub fn fromMeshOwned(allocator: std.mem.Allocator, mesh: mesh_mod.Mesh) GeometrySet {
        return .{
            .allocator = allocator,
            .mesh = mesh,
        };
    }

    pub fn fromMeshClone(allocator: std.mem.Allocator, mesh: *const mesh_mod.Mesh) std.mem.Allocator.Error!GeometrySet {
        return .{
            .allocator = allocator,
            .mesh = try mesh.clone(allocator),
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
        if (self.mesh) |*mesh| {
            mesh.deinit();
            self.mesh = null;
        }
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

        if (self.mesh) |*mesh| {
            cloned.mesh = try mesh.clone(allocator);
        }
        if (self.curves) |*curves| {
            cloned.curves = try curves.clone(allocator);
        }
        if (self.instances) |*instances| {
            cloned.instances = try instances.clone(allocator);
        }
        return cloned;
    }

    pub fn translate(self: *GeometrySet, delta: math.Vec3) void {
        if (self.mesh) |*mesh| {
            mesh.translate(delta);
        }
        if (self.curves) |*curves| {
            curves.translate(delta);
        }
        if (self.instances) |*instances| {
            for (instances.items.items) |*instance| {
                instance.transform.translation = instance.transform.translation.add(delta);
            }
        }
    }

    pub fn appendGeometry(self: *GeometrySet, other: *const GeometrySet) !void {
        if (other.mesh) |*other_mesh| {
            if (self.mesh) |*mesh| {
                try mesh.appendMesh(other_mesh);
            } else {
                self.mesh = try other_mesh.clone(self.allocator);
            }
        }
        if (other.curves) |*other_curves| {
            if (self.curves) |*curves| {
                try curves.appendCurves(other_curves);
            } else {
                self.curves = try other_curves.clone(self.allocator);
            }
        }
        if (other.instances) |*other_instances| {
            // Join keeps instances lazy; they only materialize when a realize step asks for it.
            if (self.instances) |*instances| {
                try instances.appendInstances(other_instances);
            } else {
                self.instances = try other_instances.clone(self.allocator);
            }
        }
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

    pub fn appendInstances(self: *Instances, other: *const Instances) std.mem.Allocator.Error!void {
        const reference_offset: u32 = @intCast(self.references.items.len);
        const existing_instances = self.items.items.len;
        const other_instances = other.items.items.len;

        for (self.float_attributes.items) |*attribute| {
            if (other.findFloatAttributeIndex(attribute.name) == null) {
                try appendRepeatedInstanceFloat(&attribute.values, self.allocator, 0.0, other_instances);
            }
        }
        for (other.float_attributes.items) |*other_attribute| {
            const attribute = try self.ensureFloatAttribute(other_attribute.name, existing_instances);
            std.debug.assert(attribute.items.len == existing_instances);
            try attribute.appendSlice(self.allocator, other_attribute.values.items);
        }

        for (other.references.items) |*reference| {
            try self.references.append(self.allocator, try reference.clone(self.allocator));
        }
        for (other.items.items) |item| {
            try self.items.append(self.allocator, .{
                .handle = item.handle + reference_offset,
                .transform = item.transform,
            });
        }
    }

    fn findFloatAttributeIndex(self: *const Instances, name: []const u8) ?usize {
        for (self.float_attributes.items, 0..) |attribute, index| {
            if (std.mem.eql(u8, attribute.name, name)) {
                return index;
            }
        }
        return null;
    }

    fn ensureFloatAttribute(self: *Instances, name: []const u8, prefix_len: usize) std.mem.Allocator.Error!*std.ArrayList(f32) {
        for (self.float_attributes.items) |*attribute| {
            if (std.mem.eql(u8, attribute.name, name)) {
                return &attribute.values;
            }
        }

        var attribute = try NamedInstanceFloatAttribute.init(self.allocator, name);
        errdefer attribute.deinit(self.allocator);
        try appendRepeatedInstanceFloat(&attribute.values, self.allocator, 0.0, prefix_len);
        try self.float_attributes.append(self.allocator, attribute);
        return &self.float_attributes.items[self.float_attributes.items.len - 1].values;
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
    var result_geometry = GeometrySet.init(allocator);
    errdefer result_geometry.deinit();

    if (geometry_set.mesh) |*mesh| {
        result_geometry.mesh = try mesh.clone(allocator);
    }
    if (geometry_set.curves) |*curves| {
        result_geometry.curves = try curves.clone(allocator);
    }
    if (geometry_set.instances == null) {
        return .{ .geometry = result_geometry };
    }

    const instances = &geometry_set.instances.?;
    for (instances.items.items, 0..) |instance, instance_index| {
        const reference = &instances.references.items[instance.handle];
        if (reference.curves == null) continue;

        const src_curves = &reference.curves.?;
        if (result_geometry.curves == null) {
            result_geometry.curves = try curves_mod.CurvesGeometry.init(allocator);
        }
        const dst_curves = &result_geometry.curves.?;
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

    return .{ .geometry = result_geometry };
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

fn createRealizeTestMesh(allocator: std.mem.Allocator) !mesh_mod.Mesh {
    var mesh = try mesh_mod.Mesh.init(allocator);
    errdefer mesh.deinit();

    _ = try mesh.appendVertex(math.Vec3.init(-1, 0, 0));
    _ = try mesh.appendVertex(math.Vec3.init(1, 0, 0));
    try mesh.appendEdge(0, 1);
    return mesh;
}

fn appendRepeatedInstanceFloat(values: *std.ArrayList(f32), allocator: std.mem.Allocator, value: f32, count: usize) std.mem.Allocator.Error!void {
    for (0..count) |_| {
        try values.append(allocator, value);
    }
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

test "realize instances can skip generic instance attributes" {
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

    const result = try realizeInstances(std.testing.allocator, &instances_geometry, .{ .realize_instance_attributes = false });
    defer {
        var geometry = result.geometry;
        geometry.deinit();
    }

    const realized = &result.geometry.curves.?;
    try std.testing.expectEqual(@as(usize, 6), realized.pointsNum());
    try std.testing.expect(realized.getPointFloatAttribute("weight") == null);
    try std.testing.expect(math.vec3ApproxEq(realized.positions.items[3], math.Vec3.init(10, 0, 0), 0.0001));
    try std.testing.expect(math.vec3ApproxEq(realized.positions.items[5], math.Vec3.init(12, 0, 0), 0.0001));
}

test "realize instances preserves direct mesh and curve components" {
    const direct_mesh = try createRealizeTestMesh(std.testing.allocator);
    const direct_curves = try createRealizeTestCurves(std.testing.allocator);
    var source_curves = try createRealizeTestCurves(std.testing.allocator);
    defer source_curves.deinit();

    var instances = Instances.init(std.testing.allocator);
    const handle = try instances.addReference(try GeometrySet.fromCurvesClone(std.testing.allocator, &source_curves));
    try instances.addInstance(handle, .{ .translation = math.Vec3.init(10, 0, 0) });
    try instances.addFloatAttribute("weight", 2.0);

    var geometry = GeometrySet.fromInstancesOwned(std.testing.allocator, instances);
    geometry.mesh = direct_mesh;
    geometry.curves = direct_curves;
    defer geometry.deinit();

    const result = try realizeInstances(std.testing.allocator, &geometry, .{ .realize_instance_attributes = true });
    defer {
        var realized_geometry = result.geometry;
        realized_geometry.deinit();
    }

    try std.testing.expect(result.geometry.mesh != null);
    try std.testing.expectEqual(@as(usize, 2), result.geometry.mesh.?.vertexCount());

    const realized_curves = &result.geometry.curves.?;
    try std.testing.expectEqual(@as(usize, 6), realized_curves.pointsNum());
    try std.testing.expectEqual(@as(usize, 2), realized_curves.curvesNum());
    try std.testing.expect(math.vec3ApproxEq(realized_curves.positions.items[0], math.Vec3.init(0, 0, 0), 0.0001));
    try std.testing.expect(math.vec3ApproxEq(realized_curves.positions.items[3], math.Vec3.init(10, 0, 0), 0.0001));
    try std.testing.expectEqualSlices(f32, &[_]f32{ 0.0, 0.0, 0.0, 2.0, 2.0, 2.0 }, realized_curves.getPointFloatAttribute("weight").?);
}

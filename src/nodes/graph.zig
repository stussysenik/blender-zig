const std = @import("std");
const curves_mod = @import("../geometry/curves.zig");
const geometry_mod = @import("../geometry/realize_instances.zig");
const math = @import("../math.zig");
const mesh_mod = @import("../mesh.zig");
const line_primitive = @import("../geometry/primitives/line.zig");
const grid_primitive = @import("../geometry/primitives/grid.zig");
const cuboid_primitive = @import("../geometry/primitives/cuboid.zig");
const uv_sphere_primitive = @import("../geometry/primitives/uv_sphere.zig");

pub const NodeId = u32;

pub const SocketType = enum {
    geometry,
    vector3,
};

pub const NodeRole = enum {
    source,
    value,
    transform,
    merge,
};

pub const LineNode = struct {
    start: math.Vec3 = math.Vec3.init(0, 0, 0),
    delta: math.Vec3 = math.Vec3.init(1, 0, 0),
    count: usize = 8,
};

pub const CurveLineNode = struct {
    start: math.Vec3 = math.Vec3.init(0, 0, 0),
    delta: math.Vec3 = math.Vec3.init(1, 0, 0),
    count: usize = 8,
    cyclic: bool = false,
};

pub const GridNode = struct {
    verts_x: usize = 8,
    verts_y: usize = 5,
    size_x: f32 = 2.0,
    size_y: f32 = 1.0,
    with_uvs: bool = true,
};

pub const CuboidNode = struct {
    size: math.Vec3 = math.Vec3.init(2, 2, 2),
    verts_x: usize = 2,
    verts_y: usize = 2,
    verts_z: usize = 2,
    with_uvs: bool = true,
};

pub const UvSphereNode = struct {
    radius: f32 = 1.0,
    segments: usize = 16,
    rings: usize = 8,
    with_uvs: bool = true,
};

pub const TranslateNode = struct {
    translation: math.Vec3 = math.Vec3.init(0, 0, 0),
};

pub const CurveInstanceArrayNode = struct {
    count: usize = 2,
    step: math.Vec3 = math.Vec3.init(1, 0, 0),
};

pub const RealizeInstancesNode = struct {
    realize_instance_attributes: bool = true,
};

pub const NodeOp = union(enum) {
    line: LineNode,
    curve_line: CurveLineNode,
    grid: GridNode,
    cuboid: CuboidNode,
    uv_sphere: UvSphereNode,
    vector_constant: math.Vec3,
    curve_instance_array: CurveInstanceArrayNode,
    translate: TranslateNode,
    realize_instances: RealizeInstancesNode,
    join_geometry: void,

    pub fn role(self: NodeOp) NodeRole {
        return switch (self) {
            .line, .curve_line, .grid, .cuboid, .uv_sphere => .source,
            .vector_constant => .value,
            .curve_instance_array, .translate, .realize_instances => .transform,
            .join_geometry => .merge,
        };
    }

    pub fn outputSocketType(self: NodeOp) SocketType {
        return switch (self) {
            .vector_constant => .vector3,
            else => .geometry,
        };
    }

    pub fn acceptsInput(self: NodeOp, socket_type: SocketType) bool {
        return switch (self) {
            .curve_instance_array, .realize_instances => socket_type == .geometry,
            .translate => socket_type == .geometry or socket_type == .vector3,
            .join_geometry => socket_type == .geometry,
            else => false,
        };
    }

    pub fn maxInputs(self: NodeOp, socket_type: SocketType) ?usize {
        return switch (self) {
            .curve_instance_array, .realize_instances => switch (socket_type) {
                .geometry => 1,
                .vector3 => 0,
            },
            .translate => switch (socket_type) {
                .geometry, .vector3 => 1,
            },
            .join_geometry => switch (socket_type) {
                .geometry => null,
                .vector3 => 0,
            },
            else => 0,
        };
    }
};

pub const Node = struct {
    name: []const u8,
    role: NodeRole,
    op: NodeOp,

    pub fn init(name: []const u8, op: NodeOp) Node {
        return .{
            .name = name,
            .role = op.role(),
            .op = op,
        };
    }
};

pub const Edge = struct {
    from: NodeId,
    to: NodeId,
    socket_type: SocketType = .geometry,
};

pub const NodeValue = union(enum) {
    geometry: geometry_mod.GeometrySet,
    vector3: math.Vec3,

    pub fn deinit(self: *NodeValue) void {
        switch (self.*) {
            .geometry => |*geometry| geometry.deinit(),
            .vector3 => {},
        }
    }
};

pub const Evaluation = struct {
    allocator: std.mem.Allocator,
    values: []?NodeValue,

    pub fn init(allocator: std.mem.Allocator, count: usize) std.mem.Allocator.Error!Evaluation {
        const values = try allocator.alloc(?NodeValue, count);
        for (values) |*slot| {
            slot.* = null;
        }
        return .{
            .allocator = allocator,
            .values = values,
        };
    }

    pub fn deinit(self: *Evaluation) void {
        for (self.values) |*maybe_value| {
            if (maybe_value.*) |*value| {
                value.deinit();
            }
        }
        self.allocator.free(self.values);
    }

    pub fn geometry(self: *const Evaluation, node_id: NodeId) ?*const geometry_mod.GeometrySet {
        if (node_id >= self.values.len) return null;
        if (self.values[node_id]) |*value| {
            return switch (value.*) {
                .geometry => |*value_geometry| value_geometry,
                .vector3 => null,
            };
        }
        return null;
    }

    pub fn mesh(self: *const Evaluation, node_id: NodeId) ?*const mesh_mod.Mesh {
        const geometry_value = self.geometry(node_id) orelse return null;
        if (geometry_value.mesh) |*geometry_mesh| {
            return geometry_mesh;
        }
        return null;
    }

    pub fn curves(self: *const Evaluation, node_id: NodeId) ?*const curves_mod.CurvesGeometry {
        const geometry_value = self.geometry(node_id) orelse return null;
        if (geometry_value.curves) |*geometry_curves| {
            return geometry_curves;
        }
        return null;
    }

    pub fn vector3(self: *const Evaluation, node_id: NodeId) ?math.Vec3 {
        if (node_id >= self.values.len) return null;
        if (self.values[node_id]) |value| {
            return switch (value) {
                .vector3 => |vector| vector,
                .geometry => null,
            };
        }
        return null;
    }
};

pub const Graph = struct {
    allocator: std.mem.Allocator,
    nodes: std.ArrayList(Node) = .empty,
    edges: std.ArrayList(Edge) = .empty,

    pub fn init(allocator: std.mem.Allocator) Graph {
        return .{ .allocator = allocator };
    }

    pub fn deinit(self: *Graph) void {
        self.nodes.deinit(self.allocator);
        self.edges.deinit(self.allocator);
    }

    pub fn addNode(self: *Graph, node: Node) !NodeId {
        std.debug.assert(node.role == node.op.role());
        try self.nodes.append(self.allocator, node);
        return @intCast(self.nodes.items.len - 1);
    }

    pub fn addEdge(self: *Graph, from: NodeId, to: NodeId) !void {
        try self.addTypedEdge(from, to, .geometry);
    }

    pub fn addTypedEdge(self: *Graph, from: NodeId, to: NodeId, socket_type: SocketType) !void {
        std.debug.assert(from < self.nodes.items.len);
        std.debug.assert(to < self.nodes.items.len);

        const from_node = self.nodes.items[from];
        const to_node = self.nodes.items[to];
        if (from_node.op.outputSocketType() != socket_type) {
            return error.IncompatibleSocketType;
        }
        if (!to_node.op.acceptsInput(socket_type)) {
            return error.IncompatibleSocketType;
        }
        if (to_node.op.maxInputs(socket_type)) |limit| {
            var matching_input_count: usize = 0;
            for (self.edges.items) |edge| {
                if (edge.to == to and edge.socket_type == socket_type) {
                    matching_input_count += 1;
                }
            }
            if (matching_input_count >= limit) {
                return error.TooManyInputs;
            }
        }

        try self.edges.append(self.allocator, .{
            .from = from,
            .to = to,
            .socket_type = socket_type,
        });
    }

    pub fn topologicalOrder(self: *const Graph, allocator: std.mem.Allocator) ![]NodeId {
        var indegree = try allocator.alloc(u32, self.nodes.items.len);
        defer allocator.free(indegree);
        @memset(indegree, 0);

        for (self.edges.items) |edge| {
            indegree[edge.to] += 1;
        }

        var queue = try std.ArrayList(NodeId).initCapacity(allocator, self.nodes.items.len);
        defer queue.deinit(allocator);
        for (indegree, 0..) |degree, index| {
            if (degree == 0) {
                try queue.append(allocator, @intCast(index));
            }
        }

        var order = try std.ArrayList(NodeId).initCapacity(allocator, self.nodes.items.len);
        errdefer order.deinit(allocator);

        var cursor: usize = 0;
        while (cursor < queue.items.len) : (cursor += 1) {
            const current = queue.items[cursor];
            try order.append(allocator, current);

            for (self.edges.items) |edge| {
                if (edge.from != current) continue;
                indegree[edge.to] -= 1;
                if (indegree[edge.to] == 0) {
                    try queue.append(allocator, edge.to);
                }
            }
        }

        if (order.items.len != self.nodes.items.len) {
            return error.CycleDetected;
        }

        return order.toOwnedSlice(allocator);
    }

    pub fn evaluate(self: *const Graph, allocator: std.mem.Allocator) !Evaluation {
        const order = try self.topologicalOrder(allocator);
        defer allocator.free(order);

        var evaluation = try Evaluation.init(allocator, self.nodes.items.len);
        errdefer evaluation.deinit();

        for (order) |node_id| {
            evaluation.values[node_id] = try self.evaluateNode(allocator, &evaluation, node_id);
        }
        return evaluation;
    }

    fn evaluateNode(self: *const Graph, allocator: std.mem.Allocator, evaluation: *const Evaluation, node_id: NodeId) !NodeValue {
        const node = self.nodes.items[node_id];
        return switch (node.op) {
            .line => |params| .{
                .geometry = geometry_mod.GeometrySet.fromMeshOwned(allocator, try line_primitive.createLineMesh(
                    allocator,
                    params.start,
                    params.delta,
                    params.count,
                )),
            },
            .curve_line => |params| .{
                .geometry = geometry_mod.GeometrySet.fromCurvesOwned(allocator, try createCurveLineGeometry(allocator, params)),
            },
            .grid => |params| .{
                .geometry = geometry_mod.GeometrySet.fromMeshOwned(allocator, try grid_primitive.createGridMesh(
                    allocator,
                    params.verts_x,
                    params.verts_y,
                    params.size_x,
                    params.size_y,
                    params.with_uvs,
                )),
            },
            .cuboid => |params| .{
                .geometry = geometry_mod.GeometrySet.fromMeshOwned(allocator, try cuboid_primitive.createCuboidMesh(
                    allocator,
                    params.size,
                    params.verts_x,
                    params.verts_y,
                    params.verts_z,
                    params.with_uvs,
                )),
            },
            .uv_sphere => |params| .{
                .geometry = geometry_mod.GeometrySet.fromMeshOwned(allocator, try uv_sphere_primitive.createUvSphereMesh(
                    allocator,
                    params.radius,
                    params.segments,
                    params.rings,
                    params.with_uvs,
                )),
            },
            .vector_constant => |value| .{ .vector3 = value },
            .curve_instance_array => |params| .{
                .geometry = try createCurveInstanceArrayGeometry(allocator, try self.singleInputGeometry(node_id, evaluation), params),
            },
            .translate => |params| blk: {
                const source_geometry = try self.singleInputGeometry(node_id, evaluation);
                const translation = self.singleInputVector3(node_id, evaluation) catch |err| switch (err) {
                    error.MissingInput => params.translation,
                    else => return err,
                };
                var geometry = try source_geometry.clone(allocator);
                geometry.translate(translation);
                break :blk .{ .geometry = geometry };
            },
            .realize_instances => |params| blk: {
                const source_geometry = try self.singleInputGeometry(node_id, evaluation);
                const realized = try geometry_mod.realizeInstances(allocator, source_geometry, .{
                    .realize_instance_attributes = params.realize_instance_attributes,
                });
                break :blk .{ .geometry = realized.geometry };
            },
            .join_geometry => blk: {
                var merged_geometry: ?geometry_mod.GeometrySet = null;
                errdefer if (merged_geometry) |*geometry| {
                    geometry.deinit();
                };

                var input_count: usize = 0;
                for (self.edges.items) |edge| {
                    if (edge.to != node_id or edge.socket_type != .geometry) continue;
                    const source_geometry = try self.resolvedInputGeometry(evaluation, edge.from);
                    if (merged_geometry) |*geometry| {
                        try geometry.appendGeometry(source_geometry);
                    } else {
                        merged_geometry = try source_geometry.clone(allocator);
                    }
                    input_count += 1;
                }

                if (input_count == 0) {
                    return error.MissingInput;
                }
                break :blk .{ .geometry = merged_geometry.? };
            },
        };
    }

    fn singleInputGeometry(self: *const Graph, node_id: NodeId, evaluation: *const Evaluation) !*const geometry_mod.GeometrySet {
        var source_geometry: ?*const geometry_mod.GeometrySet = null;
        var input_count: usize = 0;

        for (self.edges.items) |edge| {
            if (edge.to != node_id or edge.socket_type != .geometry) continue;
            source_geometry = try self.resolvedInputGeometry(evaluation, edge.from);
            input_count += 1;
        }

        return switch (input_count) {
            0 => error.MissingInput,
            1 => source_geometry.?,
            else => error.InvalidInputArity,
        };
    }

    fn resolvedInputGeometry(self: *const Graph, evaluation: *const Evaluation, from: NodeId) !*const geometry_mod.GeometrySet {
        _ = self;
        return evaluation.geometry(from) orelse error.MissingInput;
    }

    fn singleInputVector3(self: *const Graph, node_id: NodeId, evaluation: *const Evaluation) !math.Vec3 {
        var source_vector: ?math.Vec3 = null;
        var input_count: usize = 0;

        for (self.edges.items) |edge| {
            if (edge.to != node_id or edge.socket_type != .vector3) continue;
            source_vector = try self.resolvedInputVector3(evaluation, edge.from);
            input_count += 1;
        }

        return switch (input_count) {
            0 => error.MissingInput,
            1 => source_vector.?,
            else => error.InvalidInputArity,
        };
    }

    fn resolvedInputVector3(self: *const Graph, evaluation: *const Evaluation, from: NodeId) !math.Vec3 {
        _ = self;
        return evaluation.vector3(from) orelse error.MissingInput;
    }
};

fn createCurveLineGeometry(allocator: std.mem.Allocator, params: CurveLineNode) !curves_mod.CurvesGeometry {
    if (params.count == 0) return error.InvalidResolution;

    var curves = try curves_mod.CurvesGeometry.init(allocator);
    errdefer curves.deinit();

    const positions = try allocator.alloc(math.Vec3, params.count);
    defer allocator.free(positions);
    const test_indices = try allocator.alloc(i32, params.count);
    defer allocator.free(test_indices);

    for (0..params.count) |index| {
        positions[index] = params.start.add(params.delta.scale(@as(f32, @floatFromInt(index))));
        test_indices[index] = @intCast(index);
    }

    try curves.appendCurve(positions, params.cyclic, test_indices);
    return curves;
}

fn createCurveInstanceArrayGeometry(
    allocator: std.mem.Allocator,
    source_geometry: *const geometry_mod.GeometrySet,
    params: CurveInstanceArrayNode,
) !geometry_mod.GeometrySet {
    if (params.count == 0) return error.InvalidResolution;
    if (source_geometry.curves == null) return error.MissingCurvesComponent;

    var geometry = geometry_mod.GeometrySet.init(allocator);
    errdefer geometry.deinit();

    if (source_geometry.mesh) |*mesh| {
        geometry.mesh = try mesh.clone(allocator);
    }

    var instances = geometry_mod.Instances.init(allocator);
    errdefer instances.deinit();

    const handle = try instances.addReference(try geometry_mod.GeometrySet.fromCurvesClone(allocator, &source_geometry.curves.?));

    // The instance array node is deliberately narrow: repeat one curves payload at a fixed step.
    for (0..params.count) |index| {
        const offset = params.step.scale(@as(f32, @floatFromInt(index)));
        try instances.addInstance(handle, .{ .translation = offset });
    }

    geometry.instances = instances;
    return geometry;
}

test "graph topological order is stable for a simple pipeline" {
    var graph = Graph.init(std.testing.allocator);
    defer graph.deinit();

    const source = try graph.addNode(Node.init("grid", .{ .grid = .{} }));
    const transform = try graph.addNode(Node.init("translate", .{
        .translate = .{ .translation = math.Vec3.init(1, 0, 0) },
    }));
    const sink = try graph.addNode(Node.init("join", .{ .join_geometry = {} }));

    try graph.addEdge(source, transform);
    try graph.addEdge(transform, sink);

    const order = try graph.topologicalOrder(std.testing.allocator);
    defer std.testing.allocator.free(order);

    try std.testing.expectEqualSlices(NodeId, &[_]NodeId{ source, transform, sink }, order);
}

test "graph reports cycles" {
    var graph = Graph.init(std.testing.allocator);
    defer graph.deinit();

    const a = try graph.addNode(Node.init("a", .{ .join_geometry = {} }));
    const b = try graph.addNode(Node.init("b", .{
        .translate = .{ .translation = math.Vec3.init(1, 0, 0) },
    }));

    try graph.addEdge(a, b);
    try graph.addEdge(b, a);

    try std.testing.expectError(error.CycleDetected, graph.topologicalOrder(std.testing.allocator));
}

test "graph evaluates a translated line pipeline" {
    var graph = Graph.init(std.testing.allocator);
    defer graph.deinit();

    const line = try graph.addNode(Node.init("line", .{
        .line = .{
            .start = math.Vec3.init(0, 1, 0),
            .delta = math.Vec3.init(1, 0, 0),
            .count = 3,
        },
    }));
    const translate = try graph.addNode(Node.init("translate", .{
        .translate = .{ .translation = math.Vec3.init(5, 2, 0) },
    }));

    try graph.addEdge(line, translate);

    var evaluation = try graph.evaluate(std.testing.allocator);
    defer evaluation.deinit();

    const mesh = evaluation.mesh(translate).?;
    try std.testing.expectEqual(@as(usize, 3), mesh.vertexCount());
    try std.testing.expect(math.vec3ApproxEq(mesh.positions.items[0], math.Vec3.init(5, 3, 0), 0.0001));
    try std.testing.expect(math.vec3ApproxEq(mesh.positions.items[2], math.Vec3.init(7, 3, 0), 0.0001));
}

test "graph evaluation stores geometry values" {
    var graph = Graph.init(std.testing.allocator);
    defer graph.deinit();

    const line = try graph.addNode(Node.init("line", .{
        .line = .{
            .start = math.Vec3.init(0, 0, 0),
            .delta = math.Vec3.init(1, 0, 0),
            .count = 2,
        },
    }));

    var evaluation = try graph.evaluate(std.testing.allocator);
    defer evaluation.deinit();

    const geometry = evaluation.geometry(line).?;
    try std.testing.expect(geometry.mesh != null);
    try std.testing.expectEqual(@as(usize, 2), geometry.mesh.?.vertexCount());
}

test "graph evaluates a curve source node" {
    var graph = Graph.init(std.testing.allocator);
    defer graph.deinit();

    const curve = try graph.addNode(Node.init("curve-line", .{
        .curve_line = .{
            .start = math.Vec3.init(1, 2, 0),
            .delta = math.Vec3.init(0.5, 0, 0),
            .count = 4,
        },
    }));

    var evaluation = try graph.evaluate(std.testing.allocator);
    defer evaluation.deinit();

    const curves = evaluation.curves(curve).?;
    try std.testing.expectEqual(@as(usize, 4), curves.pointsNum());
    try std.testing.expectEqual(@as(usize, 1), curves.curvesNum());
    try std.testing.expect(math.vec3ApproxEq(curves.positions.items[0], math.Vec3.init(1, 2, 0), 0.0001));
    try std.testing.expect(math.vec3ApproxEq(curves.positions.items[3], math.Vec3.init(2.5, 2, 0), 0.0001));
}

test "curve instance array node builds instances and preserves direct mesh" {
    var graph = Graph.init(std.testing.allocator);
    defer graph.deinit();

    const grid = try graph.addNode(Node.init("grid", .{
        .grid = .{
            .verts_x = 2,
            .verts_y = 2,
            .size_x = 2,
            .size_y = 2,
            .with_uvs = false,
        },
    }));
    const curve = try graph.addNode(Node.init("curve-line", .{
        .curve_line = .{
            .start = math.Vec3.init(0, 0, 0),
            .delta = math.Vec3.init(1, 0, 0),
            .count = 3,
        },
    }));
    const join = try graph.addNode(Node.init("join", .{ .join_geometry = {} }));
    const array = try graph.addNode(Node.init("curve-array", .{
        .curve_instance_array = .{
            .count = 2,
            .step = math.Vec3.init(10, 0, 0),
        },
    }));

    try graph.addEdge(grid, join);
    try graph.addEdge(curve, join);
    try graph.addEdge(join, array);

    var evaluation = try graph.evaluate(std.testing.allocator);
    defer evaluation.deinit();

    const geometry = evaluation.geometry(array).?;
    try std.testing.expect(geometry.mesh != null);
    try std.testing.expect(geometry.instances != null);
    try std.testing.expectEqual(@as(usize, 4), geometry.mesh.?.vertexCount());
    try std.testing.expectEqual(@as(usize, 2), geometry.instances.?.items.items.len);
}

test "curve instance array node requires curves" {
    var graph = Graph.init(std.testing.allocator);
    defer graph.deinit();

    const grid = try graph.addNode(Node.init("grid", .{
        .grid = .{
            .verts_x = 2,
            .verts_y = 2,
            .size_x = 2,
            .size_y = 2,
            .with_uvs = false,
        },
    }));
    const array = try graph.addNode(Node.init("curve-array", .{
        .curve_instance_array = .{},
    }));

    try graph.addEdge(grid, array);
    try std.testing.expectError(error.MissingCurvesComponent, graph.evaluate(std.testing.allocator));
}

test "graph joins primitive meshes in edge order" {
    var graph = Graph.init(std.testing.allocator);
    defer graph.deinit();

    const line = try graph.addNode(Node.init("line", .{
        .line = .{
            .start = math.Vec3.init(10, 0, 0),
            .delta = math.Vec3.init(1, 0, 0),
            .count = 2,
        },
    }));
    const grid = try graph.addNode(Node.init("grid", .{
        .grid = .{
            .verts_x = 2,
            .verts_y = 2,
            .size_x = 2,
            .size_y = 2,
            .with_uvs = false,
        },
    }));
    const join = try graph.addNode(Node.init("join", .{ .join_geometry = {} }));

    try graph.addEdge(line, join);
    try graph.addEdge(grid, join);

    var evaluation = try graph.evaluate(std.testing.allocator);
    defer evaluation.deinit();

    const mesh = evaluation.mesh(join).?;
    try std.testing.expectEqual(@as(usize, 6), mesh.vertexCount());
    try std.testing.expectEqual(@as(usize, 5), mesh.edges.items.len);
    try std.testing.expectEqual(@as(usize, 1), mesh.faceCount());
    try std.testing.expect(math.vec3ApproxEq(mesh.positions.items[0], math.Vec3.init(10, 0, 0), 0.0001));
    try std.testing.expect(math.vec3ApproxEq(mesh.positions.items[1], math.Vec3.init(11, 0, 0), 0.0001));
    try std.testing.expect(math.vec3ApproxEq(mesh.positions.items[2], math.Vec3.init(-1, -1, 0), 0.0001));
}

test "translate nodes reject multiple mesh inputs" {
    var graph = Graph.init(std.testing.allocator);
    defer graph.deinit();

    const a = try graph.addNode(Node.init("line-a", .{ .line = .{ .count = 2 } }));
    const b = try graph.addNode(Node.init("line-b", .{
        .line = .{
            .start = math.Vec3.init(5, 0, 0),
            .count = 2,
        },
    }));
    const translate = try graph.addNode(Node.init("translate", .{
        .translate = .{ .translation = math.Vec3.init(1, 0, 0) },
    }));

    try graph.addEdge(a, translate);
    try std.testing.expectError(error.TooManyInputs, graph.addEdge(b, translate));
}

test "typed edges reject incompatible socket types" {
    var graph = Graph.init(std.testing.allocator);
    defer graph.deinit();

    const vector = try graph.addNode(Node.init("offset", .{
        .vector_constant = math.Vec3.init(1, 2, 3),
    }));
    const join = try graph.addNode(Node.init("join", .{ .join_geometry = {} }));

    try std.testing.expectError(error.IncompatibleSocketType, graph.addTypedEdge(vector, join, .vector3));
}

test "translate nodes can consume vector inputs" {
    var graph = Graph.init(std.testing.allocator);
    defer graph.deinit();

    const grid = try graph.addNode(Node.init("grid", .{
        .grid = .{
            .verts_x = 2,
            .verts_y = 2,
            .size_x = 2,
            .size_y = 2,
            .with_uvs = false,
        },
    }));
    const vector = try graph.addNode(Node.init("offset", .{
        .vector_constant = math.Vec3.init(3, 4, 5),
    }));
    const translate = try graph.addNode(Node.init("translate", .{
        .translate = .{},
    }));

    try graph.addEdge(grid, translate);
    try graph.addTypedEdge(vector, translate, .vector3);

    var evaluation = try graph.evaluate(std.testing.allocator);
    defer evaluation.deinit();

    const mesh = evaluation.mesh(translate).?;
    try std.testing.expectEqual(@as(usize, 4), mesh.vertexCount());
    try std.testing.expectEqual(@as(usize, 1), mesh.faceCount());
    try std.testing.expect(math.vec3ApproxEq(mesh.positions.items[0], math.Vec3.init(2, 3, 5), 0.0001));
    try std.testing.expect(math.vec3ApproxEq(mesh.positions.items[3], math.Vec3.init(4, 5, 5), 0.0001));
}

test "join geometry keeps mesh and curve components together" {
    var graph = Graph.init(std.testing.allocator);
    defer graph.deinit();

    const grid = try graph.addNode(Node.init("grid", .{
        .grid = .{
            .verts_x = 2,
            .verts_y = 2,
            .size_x = 2,
            .size_y = 2,
            .with_uvs = false,
        },
    }));
    const curve = try graph.addNode(Node.init("curve-line", .{
        .curve_line = .{
            .start = math.Vec3.init(10, 0, 0),
            .delta = math.Vec3.init(1, 0, 0),
            .count = 3,
        },
    }));
    const join = try graph.addNode(Node.init("join", .{ .join_geometry = {} }));

    try graph.addEdge(grid, join);
    try graph.addEdge(curve, join);

    var evaluation = try graph.evaluate(std.testing.allocator);
    defer evaluation.deinit();

    const geometry_value = evaluation.geometry(join).?;
    try std.testing.expect(geometry_value.mesh != null);
    try std.testing.expect(geometry_value.curves != null);
    try std.testing.expectEqual(@as(usize, 4), geometry_value.mesh.?.vertexCount());
    try std.testing.expectEqual(@as(usize, 3), geometry_value.curves.?.pointsNum());
}

test "realize instances node expands curve arrays and keeps direct mesh" {
    var graph = Graph.init(std.testing.allocator);
    defer graph.deinit();

    const grid = try graph.addNode(Node.init("grid", .{
        .grid = .{
            .verts_x = 2,
            .verts_y = 2,
            .size_x = 2,
            .size_y = 2,
            .with_uvs = false,
        },
    }));
    const curve = try graph.addNode(Node.init("curve-line", .{
        .curve_line = .{
            .start = math.Vec3.init(0, 0, 0),
            .delta = math.Vec3.init(1, 0, 0),
            .count = 3,
        },
    }));
    const join = try graph.addNode(Node.init("join", .{ .join_geometry = {} }));
    const array = try graph.addNode(Node.init("curve-array", .{
        .curve_instance_array = .{
            .count = 2,
            .step = math.Vec3.init(10, 0, 0),
        },
    }));
    const realize = try graph.addNode(Node.init("realize", .{
        .realize_instances = .{},
    }));

    try graph.addEdge(grid, join);
    try graph.addEdge(curve, join);
    try graph.addEdge(join, array);
    try graph.addEdge(array, realize);

    var evaluation = try graph.evaluate(std.testing.allocator);
    defer evaluation.deinit();

    const geometry = evaluation.geometry(realize).?;
    try std.testing.expect(geometry.mesh != null);
    try std.testing.expect(geometry.curves != null);
    try std.testing.expect(geometry.instances == null);
    try std.testing.expectEqual(@as(usize, 4), geometry.mesh.?.vertexCount());
    try std.testing.expectEqual(@as(usize, 6), geometry.curves.?.pointsNum());
    try std.testing.expect(math.vec3ApproxEq(geometry.curves.?.positions.items[0], math.Vec3.init(0, 0, 0), 0.0001));
    try std.testing.expect(math.vec3ApproxEq(geometry.curves.?.positions.items[3], math.Vec3.init(10, 0, 0), 0.0001));
}

test "realize instances node is a no-op when geometry has no instances" {
    var graph = Graph.init(std.testing.allocator);
    defer graph.deinit();

    const curve = try graph.addNode(Node.init("curve-line", .{
        .curve_line = .{
            .start = math.Vec3.init(1, 2, 0),
            .delta = math.Vec3.init(0.5, 0, 0),
            .count = 4,
        },
    }));
    const realize = try graph.addNode(Node.init("realize", .{
        .realize_instances = .{},
    }));

    try graph.addEdge(curve, realize);

    var evaluation = try graph.evaluate(std.testing.allocator);
    defer evaluation.deinit();

    const geometry = evaluation.geometry(realize).?;
    try std.testing.expect(geometry.mesh == null);
    try std.testing.expect(geometry.curves != null);
    try std.testing.expect(geometry.instances == null);
    try std.testing.expectEqual(@as(usize, 4), geometry.curves.?.pointsNum());
    try std.testing.expectEqual(@as(usize, 1), geometry.curves.?.curvesNum());
    try std.testing.expect(math.vec3ApproxEq(geometry.curves.?.positions.items[0], math.Vec3.init(1, 2, 0), 0.0001));
    try std.testing.expect(math.vec3ApproxEq(geometry.curves.?.positions.items[3], math.Vec3.init(2.5, 2, 0), 0.0001));
}

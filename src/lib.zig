const std = @import("std");

pub const math = @import("math.zig");
pub const mesh = @import("mesh.zig");

pub const blenlib = struct {
    pub const DisjointSet = @import("blenlib/disjoint_set.zig").DisjointSet;
    pub const OffsetIndices = @import("blenlib/offset_indices.zig").OffsetIndices;
    pub const OffsetRange = @import("blenlib/offset_indices.zig").Range;
    pub const accumulateCountsToOffsets = @import("blenlib/offset_indices.zig").accumulateCountsToOffsets;
    pub const fillConstantGroupSize = @import("blenlib/offset_indices.zig").fillConstantGroupSize;
};

pub const geometry = struct {
    pub const CurvesGeometry = @import("geometry/curves.zig").CurvesGeometry;
    pub const curvesMergeEndpoints = @import("geometry/curves.zig").curvesMergeEndpoints;
    pub const sampleCurvePadded = @import("geometry/curves.zig").sampleCurvePadded;
    pub const sampleCurvePaddedForCurve = @import("geometry/curves.zig").sampleCurvePaddedForCurve;
    pub const GeometrySet = @import("geometry/realize_instances.zig").GeometrySet;
    pub const Instances = @import("geometry/realize_instances.zig").Instances;
    pub const InstanceTransform = @import("geometry/realize_instances.zig").InstanceTransform;
    pub const RealizeInstancesOptions = @import("geometry/realize_instances.zig").RealizeInstancesOptions;
    pub const realizeInstances = @import("geometry/realize_instances.zig").realizeInstances;
    pub const createLineMesh = @import("geometry/primitives/line.zig").createLineMesh;
    pub const createGridMesh = @import("geometry/primitives/grid.zig").createGridMesh;
    pub const createCuboidMesh = @import("geometry/primitives/cuboid.zig").createCuboidMesh;
    pub const createUvSphereMesh = @import("geometry/primitives/uv_sphere.zig").createUvSphereMesh;
};

pub const io = struct {
    pub const obj = @import("io/obj.zig");
};

pub const nodes = struct {
    pub const Evaluation = @import("nodes/graph.zig").Evaluation;
    pub const Graph = @import("nodes/graph.zig").Graph;
    pub const Node = @import("nodes/graph.zig").Node;
    pub const NodeOp = @import("nodes/graph.zig").NodeOp;
    pub const NodeRole = @import("nodes/graph.zig").NodeRole;
    pub const SocketType = @import("nodes/graph.zig").SocketType;
};

test {
    std.testing.refAllDecls(@This());
    _ = @import("blenlib/disjoint_set.zig");
    _ = @import("blenlib/offset_indices.zig");
    _ = @import("mesh.zig");
    _ = @import("geometry/curves.zig");
    _ = @import("geometry/realize_instances.zig");
    _ = @import("geometry/primitives/line.zig");
    _ = @import("geometry/primitives/grid.zig");
    _ = @import("geometry/primitives/cuboid.zig");
    _ = @import("geometry/primitives/uv_sphere.zig");
    _ = @import("io/obj.zig");
    _ = @import("nodes/graph.zig");
}

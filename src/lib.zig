const std = @import("std");

// `lib.zig` is the public map of the rewrite. Export every supported subsystem here so
// contributors can discover the runtime surface without scanning the whole tree.
pub const math = @import("math.zig");
pub const mesh = @import("mesh.zig");
pub const pipeline = @import("pipeline.zig");

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
    pub const CurvesToMeshOptions = @import("geometry/curves_to_mesh.zig").Options;
    pub const convertCurvesToPolylineMesh = @import("geometry/curves_to_mesh.zig").convertCurvesToPolylineMesh;
    pub const CurveToMeshOptions = @import("geometry/curves_to_mesh.zig").CurveToMeshOptions;
    pub const curveToWireMesh = @import("geometry/curves_to_mesh.zig").curveToWireMesh;
    pub const curveToMeshSweep = @import("geometry/curves_to_mesh.zig").curveToMeshSweep;
    pub const DissolveOptions = @import("geometry/mesh_dissolve.zig").DissolveOptions;
    pub const dissolveEdges = @import("geometry/mesh_dissolve.zig").dissolveEdges;
    pub const PlanarDissolveOptions = @import("geometry/mesh_dissolve.zig").PlanarDissolveOptions;
    pub const dissolvePlanar = @import("geometry/mesh_dissolve.zig").dissolvePlanar;
    pub const ExtrudeOptions = @import("geometry/mesh_extrude.zig").ExtrudeOptions;
    pub const extrudeIndividual = @import("geometry/mesh_extrude.zig").extrudeIndividual;
    pub const InsetOptions = @import("geometry/mesh_inset.zig").InsetOptions;
    pub const insetIndividual = @import("geometry/mesh_inset.zig").insetIndividual;
    pub const SubdivideOptions = @import("geometry/mesh_subdivide.zig").SubdivideOptions;
    pub const subdivideFaces = @import("geometry/mesh_subdivide.zig").subdivideFaces;
    pub const meshEdgesToCurves = @import("geometry/mesh_to_curve.zig").meshEdgesToCurves;
    pub const MergeByDistanceOptions = @import("geometry/mesh_merge_by_distance.zig").MergeByDistanceOptions;
    pub const mergeByDistance = @import("geometry/mesh_merge_by_distance.zig").mergeByDistance;
    pub const triangulateMesh = @import("geometry/mesh_triangulate.zig").triangulateMesh;
    pub const GeometrySet = @import("geometry/realize_instances.zig").GeometrySet;
    pub const Instances = @import("geometry/realize_instances.zig").Instances;
    pub const InstanceTransform = @import("geometry/realize_instances.zig").InstanceTransform;
    pub const RealizeInstancesOptions = @import("geometry/realize_instances.zig").RealizeInstancesOptions;
    pub const realizeInstances = @import("geometry/realize_instances.zig").realizeInstances;
    pub const createLineMesh = @import("geometry/primitives/line.zig").createLineMesh;
    pub const createGridMesh = @import("geometry/primitives/grid.zig").createGridMesh;
    pub const createCuboidMesh = @import("geometry/primitives/cuboid.zig").createCuboidMesh;
    pub const createCylinderMesh = @import("geometry/primitives/cylinder_cone.zig").createCylinderMesh;
    pub const createConeMesh = @import("geometry/primitives/cylinder_cone.zig").createConeMesh;
    pub const createUvSphereMesh = @import("geometry/primitives/uv_sphere.zig").createUvSphereMesh;
};

pub const io = struct {
    pub const obj = @import("io/obj.zig");
    pub const ply = @import("io/ply.zig");
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
    _ = @import("pipeline.zig");
    _ = @import("geometry/curves.zig");
    _ = @import("geometry/curves_to_mesh.zig");
    _ = @import("geometry/mesh_dissolve.zig");
    _ = @import("geometry/mesh_extrude.zig");
    _ = @import("geometry/mesh_inset.zig");
    _ = @import("geometry/mesh_subdivide.zig");
    _ = @import("geometry/mesh_to_curve.zig");
    _ = @import("geometry/mesh_merge_by_distance.zig");
    _ = @import("geometry/mesh_triangulate.zig");
    _ = @import("geometry/realize_instances.zig");
    _ = @import("geometry/primitives/line.zig");
    _ = @import("geometry/primitives/grid.zig");
    _ = @import("geometry/primitives/cuboid.zig");
    _ = @import("geometry/primitives/cylinder_cone.zig");
    _ = @import("geometry/primitives/uv_sphere.zig");
    _ = @import("io/obj.zig");
    _ = @import("io/ply.zig");
    _ = @import("nodes/graph.zig");
}

const std = @import("std");
const math = @import("../math.zig");
const offset_indices = @import("../blenlib/offset_indices.zig");

pub const NamedFloatAttribute = struct {
    name: []u8,
    values: std.ArrayList(f32) = .empty,

    fn init(allocator: std.mem.Allocator, name: []const u8) !NamedFloatAttribute {
        return .{
            .name = try allocator.dupe(u8, name),
        };
    }

    fn deinit(self: *NamedFloatAttribute, allocator: std.mem.Allocator) void {
        allocator.free(self.name);
        self.values.deinit(allocator);
    }

    fn clone(self: *const NamedFloatAttribute, allocator: std.mem.Allocator) !NamedFloatAttribute {
        var clone_attr = try NamedFloatAttribute.init(allocator, self.name);
        errdefer clone_attr.deinit(allocator);
        try clone_attr.values.appendSlice(allocator, self.values.items);
        return clone_attr;
    }
};

pub const CurvesGeometry = struct {
    allocator: std.mem.Allocator,
    positions: std.ArrayList(math.Vec3) = .empty,
    curve_offsets: std.ArrayList(u32) = .empty,
    cyclic: std.ArrayList(bool) = .empty,
    point_test_index: std.ArrayList(i32) = .empty,
    point_float_attributes: std.ArrayList(NamedFloatAttribute) = .empty,

    pub fn init(allocator: std.mem.Allocator) !CurvesGeometry {
        var curves = CurvesGeometry{ .allocator = allocator };
        try curves.curve_offsets.append(allocator, 0);
        return curves;
    }

    pub fn deinit(self: *CurvesGeometry) void {
        self.positions.deinit(self.allocator);
        self.curve_offsets.deinit(self.allocator);
        self.cyclic.deinit(self.allocator);
        self.point_test_index.deinit(self.allocator);
        for (self.point_float_attributes.items) |*attribute| {
            attribute.deinit(self.allocator);
        }
        self.point_float_attributes.deinit(self.allocator);
    }

    pub fn pointsNum(self: *const CurvesGeometry) usize {
        return self.positions.items.len;
    }

    pub fn curvesNum(self: *const CurvesGeometry) usize {
        return self.cyclic.items.len;
    }

    pub fn offsets(self: *const CurvesGeometry) []const u32 {
        return self.curve_offsets.items;
    }

    pub fn cyclicFlags(self: *const CurvesGeometry) []const bool {
        return self.cyclic.items;
    }

    pub fn testIndices(self: *const CurvesGeometry) []const i32 {
        return self.point_test_index.items;
    }

    pub fn getPointFloatAttribute(self: *const CurvesGeometry, name: []const u8) ?[]const f32 {
        for (self.point_float_attributes.items) |*attribute| {
            if (std.mem.eql(u8, attribute.name, name)) {
                return attribute.values.items;
            }
        }
        return null;
    }

    pub fn appendPointFloatAttributeRepeated(
        self: *CurvesGeometry,
        name: []const u8,
        value: f32,
        count: usize,
    ) !void {
        const attribute = try self.ensurePointFloatAttribute(name);
        for (0..count) |_| {
            try attribute.append(self.allocator, value);
        }
    }

    pub fn clone(self: *const CurvesGeometry, allocator: std.mem.Allocator) !CurvesGeometry {
        var clone_curves = try CurvesGeometry.init(allocator);
        errdefer clone_curves.deinit();

        try clone_curves.positions.appendSlice(allocator, self.positions.items);
        clone_curves.curve_offsets.clearRetainingCapacity();
        try clone_curves.curve_offsets.appendSlice(allocator, self.curve_offsets.items);
        try clone_curves.cyclic.appendSlice(allocator, self.cyclic.items);
        try clone_curves.point_test_index.appendSlice(allocator, self.point_test_index.items);
        for (self.point_float_attributes.items) |*attribute| {
            try clone_curves.point_float_attributes.append(allocator, try attribute.clone(allocator));
        }
        return clone_curves;
    }

    pub fn pointsByCurve(self: *const CurvesGeometry, curve_index: usize) offset_indices.Range {
        std.debug.assert(curve_index < self.curvesNum());
        return .{
            .start = self.curve_offsets.items[curve_index],
            .end = self.curve_offsets.items[curve_index + 1],
        };
    }

    pub fn appendCurve(
        self: *CurvesGeometry,
        points: []const math.Vec3,
        is_cyclic: bool,
        maybe_test_index: ?[]const i32,
    ) !void {
        try self.appendPointSpan(points, maybe_test_index);
        try self.finishCurve(is_cyclic);
    }

    fn appendPointSpan(
        self: *CurvesGeometry,
        points: []const math.Vec3,
        maybe_test_index: ?[]const i32,
    ) !void {
        try self.positions.appendSlice(self.allocator, points);
        if (maybe_test_index) |indices| {
            std.debug.assert(indices.len == points.len);
            try self.point_test_index.appendSlice(self.allocator, indices);
        } else {
            std.debug.assert(self.point_test_index.items.len == 0);
        }
    }

    fn finishCurve(self: *CurvesGeometry, is_cyclic: bool) !void {
        try self.cyclic.append(self.allocator, is_cyclic);
        try self.curve_offsets.append(self.allocator, @intCast(self.positions.items.len));
    }

    fn ensurePointFloatAttribute(self: *CurvesGeometry, name: []const u8) !*std.ArrayList(f32) {
        for (self.point_float_attributes.items) |*attribute| {
            if (std.mem.eql(u8, attribute.name, name)) {
                return &attribute.values;
            }
        }

        try self.point_float_attributes.append(self.allocator, try NamedFloatAttribute.init(self.allocator, name));
        return &self.point_float_attributes.items[self.point_float_attributes.items.len - 1].values;
    }
};

pub fn curvesMergeEndpoints(
    allocator: std.mem.Allocator,
    src_curves: *const CurvesGeometry,
    connect_to_curve: []const i32,
    flip_direction: []const bool,
) !CurvesGeometry {
    std.debug.assert(connect_to_curve.len == src_curves.curvesNum());
    std.debug.assert(flip_direction.len == src_curves.curvesNum());

    const old_by_new_map = try toposortConnectedCurves(allocator, connect_to_curve);
    defer allocator.free(old_by_new_map);

    var ranges = try findConnectedRanges(allocator, src_curves, old_by_new_map, connect_to_curve);
    defer ranges.deinit();

    var ordered_curves = try reorderAndFlipCurves(allocator, src_curves, old_by_new_map, flip_direction);
    defer ordered_curves.deinit();

    var merged_curves = try joinCurveRanges(allocator, &ordered_curves, ranges.offsets.items);
    errdefer merged_curves.deinit();

    std.debug.assert(merged_curves.cyclic.items.len == ranges.cyclic.items.len);
    @memcpy(merged_curves.cyclic.items, ranges.cyclic.items);
    return merged_curves;
}

pub fn sampleCurvePadded(
    allocator: std.mem.Allocator,
    positions: []const math.Vec3,
    cyclic: bool,
    r_indices: []i32,
    r_factors: []f32,
) !void {
    std.debug.assert(r_indices.len == r_factors.len);
    const num_dst_points = r_indices.len;
    const src_points = positions.len;

    if (num_dst_points == 0) return;
    if (num_dst_points == 1) {
        r_indices[0] = 0;
        r_factors[0] = 0.0;
        return;
    }
    if (src_points == 0) return;
    if (src_points == 1) {
        @memset(r_indices, 0);
        @memset(r_factors, 0.0);
        return;
    }

    if (num_dst_points >= src_points) {
        const dst_sample_offsets = try allocator.alloc(u32, src_points + 1);
        defer allocator.free(dst_sample_offsets);

        try assignSamplesToSegments(allocator, num_dst_points, positions, cyclic, dst_sample_offsets);

        const dst_samples_by_src_point = offset_indices.OffsetIndices.init(dst_sample_offsets);
        for (0..src_points) |src_point_i| {
            const samples = dst_samples_by_src_point.at(src_point_i);
            const sample_count = samples.len();
            for (0..sample_count) |sample_i| {
                const sample = samples.start + @as(u32, @intCast(sample_i));
                r_indices[sample] = @intCast(src_point_i);
                r_factors[sample] = @as(f32, @floatFromInt(sample_i)) /
                    @as(f32, @floatFromInt(sample_count));
            }
        }
    } else {
        const sample_by_point = try buildPointToSampleMap(
            allocator,
            positions,
            cyclic,
            num_dst_points - @as(usize, if (cyclic) 0 else 1),
        );
        defer allocator.free(sample_by_point);

        for (0..src_points) |src_point_i| {
            const sample_start = sample_by_point[src_point_i];
            const sample_end = sample_by_point[src_point_i + 1];
            const sample_begin: usize = @intFromFloat(@ceil(sample_start));
            const sample_limit: usize = @intFromFloat(@ceil(sample_end));

            for (sample_begin..sample_limit) |sample| {
                r_indices[sample] = @intCast(src_point_i);
                r_factors[sample] = safeDivide(@as(f32, @floatFromInt(sample)) - sample_start, sample_end - sample_start);
            }
        }

        if (!cyclic) {
            r_indices[r_indices.len - 1] = @intCast(src_points - 1);
            r_factors[r_factors.len - 1] = 0.0;
        }
    }
}

pub fn sampleCurvePaddedForCurve(
    allocator: std.mem.Allocator,
    curves: *const CurvesGeometry,
    curve_index: usize,
    reverse: bool,
    r_indices: []i32,
    r_factors: []f32,
) !void {
    std.debug.assert(curve_index < curves.curvesNum());
    std.debug.assert(r_indices.len == r_factors.len);

    const points = curves.pointsByCurve(curve_index);
    const positions = curves.positions.items[points.start..points.end];
    const cyclic = curves.cyclic.items[curve_index];

    if (reverse) {
        const reverse_positions = try allocator.alloc(math.Vec3, positions.len);
        defer allocator.free(reverse_positions);

        for (0..positions.len) |index| {
            reverse_positions[index] = positions[positions.len - 1 - index];
        }

        try sampleCurvePadded(allocator, reverse_positions, cyclic, r_indices, r_factors);
        try reverseSamples(allocator, positions.len, r_indices, r_factors);
    } else {
        try sampleCurvePadded(allocator, positions, cyclic, r_indices, r_factors);
    }
}

const ConnectedRanges = struct {
    allocator: std.mem.Allocator,
    offsets: std.ArrayList(u32) = .empty,
    cyclic: std.ArrayList(bool) = .empty,

    fn init(allocator: std.mem.Allocator) ConnectedRanges {
        return .{ .allocator = allocator };
    }

    fn deinit(self: *ConnectedRanges) void {
        self.offsets.deinit(self.allocator);
        self.cyclic.deinit(self.allocator);
    }
};

const ReachableMarker = struct {
    reachable: []bool,

    fn onCurve(self: *@This(), curve_index: u32) !void {
        self.reachable[curve_index] = true;
    }
};

const CurveCollector = struct {
    allocator: std.mem.Allocator,
    curves: *std.ArrayList(u32),

    fn onCurve(self: *@This(), curve_index: u32) !void {
        try self.curves.append(self.allocator, curve_index);
    }
};

fn buildPointToSampleMap(
    allocator: std.mem.Allocator,
    positions: []const math.Vec3,
    cyclic: bool,
    samples_num: usize,
) ![]f32 {
    const sample_by_point = try allocator.alloc(f32, positions.len + 1);
    sample_by_point[0] = 0.0;

    for (1..positions.len) |index| {
        sample_by_point[index] = sample_by_point[index - 1] + distance(positions[index - 1], positions[index]);
    }

    sample_by_point[sample_by_point.len - 1] = if (cyclic)
        sample_by_point[positions.len - 1] + distance(positions[positions.len - 1], positions[0])
    else
        sample_by_point[positions.len - 1];

    const length_epsilon: f32 = 1e-4;
    if (sample_by_point[sample_by_point.len - 1] <= length_epsilon) {
        for (sample_by_point, 0..) |*value, index| {
            value.* = @floatFromInt(index);
        }
    }

    const total_length = sample_by_point[sample_by_point.len - 1];
    const length_to_sample_count = safeDivide(@as(f32, @floatFromInt(samples_num)), total_length);
    for (sample_by_point) |*value| {
        value.* *= length_to_sample_count;
    }

    return sample_by_point;
}

fn assignSamplesToSegments(
    allocator: std.mem.Allocator,
    num_dst_points: usize,
    src_positions: []const math.Vec3,
    cyclic: bool,
    dst_sample_offsets: []u32,
) !void {
    std.debug.assert(src_positions.len > 0);
    std.debug.assert(num_dst_points > 0);
    std.debug.assert(num_dst_points >= src_positions.len);
    std.debug.assert(dst_sample_offsets.len == src_positions.len + 1);

    const num_free_samples = num_dst_points - src_positions.len;
    const sample_by_point = try buildPointToSampleMap(allocator, src_positions, cyclic, num_free_samples);
    defer allocator.free(sample_by_point);

    var samples_start: u32 = 0;
    for (0..src_positions.len) |src_point_i| {
        dst_sample_offsets[src_point_i] = samples_start;

        const free_samples = @as(i32, @intFromFloat(@round(sample_by_point[src_point_i + 1]))) -
            @as(i32, @intFromFloat(@round(sample_by_point[src_point_i])));
        samples_start += 1 + @as(u32, @intCast(free_samples));
    }
    dst_sample_offsets[dst_sample_offsets.len - 1] = @intCast(num_dst_points);
}

fn reverseSamples(
    allocator: std.mem.Allocator,
    points_num: usize,
    r_indices: []i32,
    r_factors: []f32,
) !void {
    const reverse_indices = try allocator.alloc(i32, r_indices.len);
    defer allocator.free(reverse_indices);
    const reverse_factors = try allocator.alloc(f32, r_factors.len);
    defer allocator.free(reverse_factors);

    var cursor: usize = 0;

    for (0..r_indices.len) |i| {
        const index = r_indices[i];
        const factor = r_factors[i];
        const is_last_segment = index >= @as(i32, @intCast(points_num - 1));

        if (is_last_segment and factor > 0.0) {
            reverse_indices[cursor] = @intCast(points_num - 1);
            reverse_factors[cursor] = 1.0 - factor;
            cursor += 1;
        }
    }

    for (0..r_indices.len) |i| {
        const index = r_indices[i];
        const factor = r_factors[i];
        const is_last_segment = index >= @as(i32, @intCast(points_num - 1));

        if (factor > 0.0) {
            if (is_last_segment) continue;
            reverse_indices[cursor] = @intCast(points_num - 2 - @as(usize, @intCast(index)));
            reverse_factors[cursor] = 1.0 - factor;
        } else {
            reverse_indices[cursor] = @intCast(points_num - 1 - @as(usize, @intCast(index)));
            reverse_factors[cursor] = 0.0;
        }
        cursor += 1;
    }

    std.debug.assert(cursor == r_indices.len);
    @memcpy(r_indices, reverse_indices);
    @memcpy(r_factors, reverse_factors);
}

fn distance(a: math.Vec3, b: math.Vec3) f32 {
    const dx = a.x - b.x;
    const dy = a.y - b.y;
    const dz = a.z - b.z;
    return @sqrt(dx * dx + dy * dy + dz * dz);
}

fn safeDivide(numerator: f32, denominator: f32) f32 {
    if (@abs(denominator) <= 1e-8) return 0.0;
    return numerator / denominator;
}

fn foreachConnectedCurve(
    allocator: std.mem.Allocator,
    connect_to_curve: []const i32,
    flags: []u8,
    start: u32,
    callback: anytype,
) !void {
    const inserted_flag: u8 = 1;
    const on_stack_flag: u8 = 2;

    if ((flags[start] & inserted_flag) != 0) {
        return;
    }

    var stack: std.ArrayList(u32) = .empty;
    defer stack.deinit(allocator);

    try stack.append(allocator, start);
    flags[start] |= on_stack_flag;
    try callback.onCurve(start);

    while (stack.items.len > 0) {
        const current = stack.items[stack.items.len - 1];
        const next = connect_to_curve[current];
        if (isValidCurveIndex(connect_to_curve.len, next)) {
            const next_curve: u32 = @intCast(next);
            if ((flags[next_curve] & inserted_flag) == 0) {
                if ((flags[next_curve] & on_stack_flag) == 0) {
                    try stack.append(allocator, next_curve);
                    flags[next_curve] |= on_stack_flag;
                    try callback.onCurve(next_curve);
                    continue;
                }
            }
        }

        flags[current] |= inserted_flag;
        _ = stack.pop();
    }
}

fn toposortConnectedCurves(
    allocator: std.mem.Allocator,
    connect_to_curve: []const i32,
) ![]u32 {
    const curve_count = connect_to_curve.len;

    const flags = try allocator.alloc(u8, curve_count);
    defer allocator.free(flags);
    @memset(flags, 0);

    const is_start_curve = try allocator.alloc(bool, curve_count);
    defer allocator.free(is_start_curve);
    @memset(is_start_curve, true);

    for (connect_to_curve) |next| {
        if (isValidCurveIndex(curve_count, next)) {
            is_start_curve[@intCast(next)] = false;
        }
    }

    const is_reachable = try allocator.alloc(bool, curve_count);
    defer allocator.free(is_reachable);
    @memset(is_reachable, false);

    for (0..curve_count) |curve_index| {
        if (!is_start_curve[curve_index]) continue;
        var marker = ReachableMarker{ .reachable = is_reachable };
        try foreachConnectedCurve(allocator, connect_to_curve, flags, @intCast(curve_index), &marker);
    }

    @memset(flags, 0);
    var sorted_curves: std.ArrayList(u32) = .empty;
    errdefer sorted_curves.deinit(allocator);

    for (0..curve_count) |curve_index| {
        if (!is_start_curve[curve_index] and is_reachable[curve_index]) continue;
        var collector = CurveCollector{
            .allocator = allocator,
            .curves = &sorted_curves,
        };
        try foreachConnectedCurve(allocator, connect_to_curve, flags, @intCast(curve_index), &collector);
    }

    std.debug.assert(sorted_curves.items.len == curve_count);
    return sorted_curves.toOwnedSlice(allocator);
}

fn reorderAndFlipCurves(
    allocator: std.mem.Allocator,
    src_curves: *const CurvesGeometry,
    old_by_new_map: []const u32,
    flip_direction: []const bool,
) !CurvesGeometry {
    var dst_curves = try CurvesGeometry.init(allocator);
    errdefer dst_curves.deinit();

    for (old_by_new_map) |old_curve| {
        const curve_range = src_curves.pointsByCurve(old_curve);
        const point_slice = src_curves.positions.items[curve_range.start..curve_range.end];
        const test_slice = src_curves.point_test_index.items[curve_range.start..curve_range.end];
        const should_flip = flip_direction[old_curve];

        if (should_flip) {
            for (0..point_slice.len) |index| {
                const reverse_index = point_slice.len - 1 - index;
                try dst_curves.appendPointSpan(
                    point_slice[reverse_index .. reverse_index + 1],
                    test_slice[reverse_index .. reverse_index + 1],
                );
            }
        } else {
            try dst_curves.appendPointSpan(point_slice, test_slice);
        }
        try dst_curves.finishCurve(src_curves.cyclic.items[old_curve]);
    }

    return dst_curves;
}

fn findConnectedRanges(
    allocator: std.mem.Allocator,
    src_curves: *const CurvesGeometry,
    old_by_new_map: []const u32,
    connect_to_curve: []const i32,
) !ConnectedRanges {
    var new_by_old = try allocator.alloc(u32, old_by_new_map.len);
    defer allocator.free(new_by_old);

    for (old_by_new_map, 0..) |src_curve, dst_curve| {
        new_by_old[src_curve] = @intCast(dst_curve);
    }

    var result = ConnectedRanges.init(allocator);
    errdefer result.deinit();

    var start_index: ?u32 = null;
    for (old_by_new_map, 0..) |src_curve, dst_curve_usize| {
        const dst_curve: u32 = @intCast(dst_curve_usize);

        if (start_index == null) {
            try result.offsets.append(allocator, 0);
            try result.cyclic.append(allocator, src_curves.cyclic.items[src_curve]);
            start_index = dst_curve;
        }

        result.offsets.items[result.offsets.items.len - 1] += 1;

        const src_connect_to = connect_to_curve[src_curve];
        const is_connected = isValidCurveIndex(old_by_new_map.len, src_connect_to);
        const dst_connect_to: i32 = if (is_connected) @intCast(new_by_old[@intCast(src_connect_to)]) else -1;

        if (dst_connect_to != @as(i32, @intCast(dst_curve)) + 1) {
            const chain_start = start_index.?;
            const is_chain = is_connected or dst_curve != chain_start;
            if (is_chain) {
                result.cyclic.items[result.cyclic.items.len - 1] = (dst_connect_to == @as(i32, @intCast(chain_start)));
            }
            start_index = null;
        }
    }

    try result.offsets.append(allocator, 0);
    offset_indices.accumulateCountsToOffsets(result.offsets.items, 0);
    return result;
}

fn joinCurveRanges(
    allocator: std.mem.Allocator,
    ordered_curves: *const CurvesGeometry,
    joined_curve_offsets: []const u32,
) !CurvesGeometry {
    var dst_curves = try CurvesGeometry.init(allocator);
    errdefer dst_curves.deinit();

    const grouped_curves = offset_indices.OffsetIndices.init(joined_curve_offsets);
    for (0..grouped_curves.len()) |dst_curve_index| {
        const source_range = grouped_curves.at(dst_curve_index);
        for (source_range.start..source_range.end) |ordered_curve_index_u32| {
            const ordered_range = ordered_curves.pointsByCurve(ordered_curve_index_u32);
            try dst_curves.appendPointSpan(
                ordered_curves.positions.items[ordered_range.start..ordered_range.end],
                ordered_curves.point_test_index.items[ordered_range.start..ordered_range.end],
            );
        }
        try dst_curves.finishCurve(false);
    }

    return dst_curves;
}

fn isValidCurveIndex(curve_count: usize, index: i32) bool {
    return index >= 0 and index < curve_count;
}

fn createTestCurves(
    allocator: std.mem.Allocator,
    offsets: []const u32,
    cyclic: []const bool,
) !CurvesGeometry {
    std.debug.assert(offsets.len > 0);
    std.debug.assert(cyclic.len + 1 == offsets.len);

    var curves = try CurvesGeometry.init(allocator);
    errdefer curves.deinit();

    for (cyclic, 0..) |is_cyclic, curve_index| {
        const start = offsets[curve_index];
        const end = offsets[curve_index + 1];
        const point_count = end - start;

        const positions = try allocator.alloc(math.Vec3, point_count);
        defer allocator.free(positions);
        const indices = try allocator.alloc(i32, point_count);
        defer allocator.free(indices);

        for (0..point_count) |local_index| {
            const point_index = start + @as(u32, @intCast(local_index));
            positions[local_index] = .{
                .x = @floatFromInt(point_index),
                .y = 0,
                .z = 0,
            };
            indices[local_index] = @intCast(point_index);
        }

        try curves.appendCurve(positions, is_cyclic, indices);
    }

    return curves;
}

const TestCurveShape = enum {
    zero,
    circle,
    eight,
    helix,
};

fn createTestShape(shape: TestCurveShape, positions: []math.Vec3) void {
    switch (shape) {
        .zero => {
            for (positions) |*position| {
                position.* = math.Vec3.init(0, 0, 0);
            }
        },
        .circle => {
            for (positions, 0..) |*position, point_i| {
                const angle = 2.0 * std.math.pi * @as(f32, @floatFromInt(point_i)) / @as(f32, @floatFromInt(positions.len));
                position.* = math.Vec3.init(@cos(angle), @sin(angle), 0.0);
            }
        },
        .eight => {
            for (positions, 0..) |*position, point_i| {
                const angle = 2.0 * std.math.pi * @as(f32, @floatFromInt(point_i)) / @as(f32, @floatFromInt(positions.len));
                position.* = math.Vec3.init(@cos(angle), @sin(angle * 2.0), 0.0);
            }
        },
        .helix => {
            const turns: i32 = 3;
            const pitch: f32 = 0.3;
            for (positions, 0..) |*position, point_i| {
                const factor = @as(f32, @floatFromInt(turns)) *
                    @as(f32, @floatFromInt(point_i)) /
                    @as(f32, @floatFromInt(positions.len - 1));
                const angle = 2.0 * std.math.pi * factor;
                position.* = math.Vec3.init(@cos(angle), @sin(angle), pitch * factor);
            }
        },
    }
}

fn createInterpolationTestCurves(
    allocator: std.mem.Allocator,
    offsets: []const u32,
    cyclic: []const bool,
    shape: TestCurveShape,
) !CurvesGeometry {
    std.debug.assert(offsets.len > 0);
    std.debug.assert(cyclic.len + 1 == offsets.len);

    var curves = try CurvesGeometry.init(allocator);
    errdefer curves.deinit();

    for (cyclic, 0..) |is_cyclic, curve_index| {
        const start = offsets[curve_index];
        const end = offsets[curve_index + 1];
        const point_count = end - start;

        const positions = try allocator.alloc(math.Vec3, point_count);
        defer allocator.free(positions);
        createTestShape(shape, positions);

        const indices = try allocator.alloc(i32, point_count);
        defer allocator.free(indices);
        for (0..point_count) |local_index| {
            indices[local_index] = @intCast(start + @as(u32, @intCast(local_index)));
        }

        try curves.appendCurve(positions, is_cyclic, indices);
    }

    return curves;
}

fn expectCurveState(
    curves: *const CurvesGeometry,
    expected_offsets: []const u32,
    expected_cyclic: []const bool,
    expected_indices: []const i32,
) !void {
    try std.testing.expectEqualSlices(u32, expected_offsets, curves.offsets());
    try std.testing.expectEqualSlices(bool, expected_cyclic, curves.cyclicFlags());
    try std.testing.expectEqualSlices(i32, expected_indices, curves.testIndices());
}

fn expectFloatSlicesNear(expected: []const f32, actual: []const f32, epsilon: f32) !void {
    try std.testing.expectEqual(expected.len, actual.len);
    for (expected, actual, 0..) |expected_value, actual_value, index| {
        if (@abs(expected_value - actual_value) > epsilon) {
            std.debug.print("float mismatch at index {d}: expected {d}, actual {d}\n", .{ index, expected_value, actual_value });
            return error.TestExpectedApproxEqAbs;
        }
    }
}

fn testSampleCurve(
    allocator: std.mem.Allocator,
    curves: *const CurvesGeometry,
    curve_index: usize,
    reverse: bool,
    expected_indices: []const i32,
    expected_factors: []const f32,
) !void {
    std.debug.assert(expected_indices.len == expected_factors.len);

    const indices = try allocator.alloc(i32, expected_indices.len);
    defer allocator.free(indices);
    const factors = try allocator.alloc(f32, expected_factors.len);
    defer allocator.free(factors);

    @memset(indices, -9999);
    @memset(factors, -12345.6);

    try sampleCurvePaddedForCurve(allocator, curves, curve_index, reverse, indices, factors);
    try std.testing.expectEqualSlices(i32, expected_indices, indices);
    try expectFloatSlicesNear(expected_factors, factors, 1e-4);
}

test "curves merge endpoints keeps disconnected curves unchanged" {
    var src_curves = try createTestCurves(std.testing.allocator, &[_]u32{ 0, 3, 6, 9, 12 }, &[_]bool{ false, true, true, false });
    defer src_curves.deinit();

    const connect_to_curve = [_]i32{ -1, -1, -1, -1 };
    const flip_direction = [_]bool{ false, false, false, false };

    var merged = try curvesMergeEndpoints(std.testing.allocator, &src_curves, &connect_to_curve, &flip_direction);
    defer merged.deinit();

    try expectCurveState(&merged, &[_]u32{ 0, 3, 6, 9, 12 }, &[_]bool{ false, true, true, false }, &[_]i32{ 0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11 });
}

test "curves merge endpoints connects a single curve" {
    var src_curves = try createTestCurves(std.testing.allocator, &[_]u32{ 0, 3, 6, 9, 12 }, &[_]bool{ false, true, true, false });
    defer src_curves.deinit();

    const connect_to_curve = [_]i32{ -1, -1, -1, 1 };
    const flip_direction = [_]bool{ false, false, false, false };

    var merged = try curvesMergeEndpoints(std.testing.allocator, &src_curves, &connect_to_curve, &flip_direction);
    defer merged.deinit();

    try expectCurveState(&merged, &[_]u32{ 0, 3, 6, 12 }, &[_]bool{ false, true, false }, &[_]i32{ 0, 1, 2, 6, 7, 8, 9, 10, 11, 3, 4, 5 });
}

test "curves merge endpoints supports direction flips" {
    var src_curves = try createTestCurves(std.testing.allocator, &[_]u32{ 0, 3, 6, 9, 12 }, &[_]bool{ false, true, true, false });
    defer src_curves.deinit();

    const connect_to_curve = [_]i32{ -1, -1, -1, -1 };
    const flip_direction = [_]bool{ false, true, false, true };

    var merged = try curvesMergeEndpoints(std.testing.allocator, &src_curves, &connect_to_curve, &flip_direction);
    defer merged.deinit();

    try expectCurveState(&merged, &[_]u32{ 0, 3, 6, 9, 12 }, &[_]bool{ false, true, true, false }, &[_]i32{ 0, 1, 2, 5, 4, 3, 6, 7, 8, 11, 10, 9 });
}

test "curves merge endpoints supports connect and reverse" {
    var src_curves = try createTestCurves(std.testing.allocator, &[_]u32{ 0, 3, 6, 9, 12 }, &[_]bool{ false, true, true, false });
    defer src_curves.deinit();

    const connect_to_curve = [_]i32{ 3, 0, -1, -1 };
    const flip_direction = [_]bool{ true, false, true, false };

    var merged = try curvesMergeEndpoints(std.testing.allocator, &src_curves, &connect_to_curve, &flip_direction);
    defer merged.deinit();

    try expectCurveState(&merged, &[_]u32{ 0, 9, 12 }, &[_]bool{ false, true }, &[_]i32{ 3, 4, 5, 2, 1, 0, 9, 10, 11, 8, 7, 6 });
}

test "curves merge endpoints detects cyclic chains" {
    var src_curves = try createTestCurves(std.testing.allocator, &[_]u32{ 0, 3, 6, 9, 12 }, &[_]bool{ false, true, true, false });
    defer src_curves.deinit();

    const connect_to_curve = [_]i32{ -1, 3, -1, 1 };
    const flip_direction = [_]bool{ false, false, false, false };

    var merged = try curvesMergeEndpoints(std.testing.allocator, &src_curves, &connect_to_curve, &flip_direction);
    defer merged.deinit();

    try expectCurveState(&merged, &[_]u32{ 0, 3, 9, 12 }, &[_]bool{ false, true, true }, &[_]i32{ 0, 1, 2, 3, 4, 5, 9, 10, 11, 6, 7, 8 });
}

test "curves merge endpoints supports self connections" {
    var src_curves = try createTestCurves(std.testing.allocator, &[_]u32{ 0, 3, 6, 9, 12 }, &[_]bool{ false, false, false, false });
    defer src_curves.deinit();

    const connect_to_curve = [_]i32{ -1, 1, 2, -1 };
    const flip_direction = [_]bool{ false, false, false, false };

    var merged = try curvesMergeEndpoints(std.testing.allocator, &src_curves, &connect_to_curve, &flip_direction);
    defer merged.deinit();

    try expectCurveState(&merged, &[_]u32{ 0, 3, 6, 9, 12 }, &[_]bool{ false, true, true, false }, &[_]i32{ 0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11 });
}

test "curves merge endpoints can merge all curves into one cycle" {
    var src_curves = try createTestCurves(std.testing.allocator, &[_]u32{ 0, 3, 6, 9, 12 }, &[_]bool{ false, true, true, false });
    defer src_curves.deinit();

    const connect_to_curve = [_]i32{ 2, 0, 3, 1 };
    const flip_direction = [_]bool{ false, false, false, false };

    var merged = try curvesMergeEndpoints(std.testing.allocator, &src_curves, &connect_to_curve, &flip_direction);
    defer merged.deinit();

    try expectCurveState(&merged, &[_]u32{ 0, 12 }, &[_]bool{ true }, &[_]i32{ 0, 1, 2, 6, 7, 8, 9, 10, 11, 3, 4, 5 });
}

test "curves merge endpoints ignores one branch when multiple connect to the same curve" {
    var src_curves = try createTestCurves(std.testing.allocator, &[_]u32{ 0, 3, 6, 9, 12 }, &[_]bool{ false, true, true, false });
    defer src_curves.deinit();

    const connect_to_curve = [_]i32{ 2, 2, -1, -1 };
    const flip_direction = [_]bool{ false, false, false, false };

    var merged = try curvesMergeEndpoints(std.testing.allocator, &src_curves, &connect_to_curve, &flip_direction);
    defer merged.deinit();

    try expectCurveState(&merged, &[_]u32{ 0, 6, 9, 12 }, &[_]bool{ false, false, false }, &[_]i32{ 0, 1, 2, 6, 7, 8, 3, 4, 5, 9, 10, 11 });
}

test "sample curve empty output" {
    var curves = try createInterpolationTestCurves(std.testing.allocator, &[_]u32{ 0, 1, 3 }, &[_]bool{ false, false }, .eight);
    defer curves.deinit();

    try testSampleCurve(std.testing.allocator, &curves, 0, false, &.{}, &.{});
    try testSampleCurve(std.testing.allocator, &curves, 1, false, &.{}, &.{});
}

test "sample curve same length" {
    var curves = try createInterpolationTestCurves(std.testing.allocator, &[_]u32{ 0, 1, 3, 13, 14, 16, 26 }, &[_]bool{ false, false, false, true, true, true }, .eight);
    defer curves.deinit();

    try testSampleCurve(std.testing.allocator, &curves, 0, false, &[_]i32{0}, &[_]f32{0.0});
    try testSampleCurve(std.testing.allocator, &curves, 0, true, &[_]i32{0}, &[_]f32{0.0});
    try testSampleCurve(std.testing.allocator, &curves, 1, false, &[_]i32{ 0, 1 }, &[_]f32{ 0.0, 0.0 });
    try testSampleCurve(std.testing.allocator, &curves, 1, true, &[_]i32{ 1, 0 }, &[_]f32{ 0.0, 0.0 });
    try testSampleCurve(std.testing.allocator, &curves, 2, false, &[_]i32{ 0, 1, 2, 3, 4, 5, 6, 7, 8, 9 }, &[_]f32{ 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0 });
    try testSampleCurve(std.testing.allocator, &curves, 2, true, &[_]i32{ 9, 8, 7, 6, 5, 4, 3, 2, 1, 0 }, &[_]f32{ 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0 });
    try testSampleCurve(std.testing.allocator, &curves, 3, false, &[_]i32{0}, &[_]f32{0.0});
    try testSampleCurve(std.testing.allocator, &curves, 3, true, &[_]i32{0}, &[_]f32{0.0});
    try testSampleCurve(std.testing.allocator, &curves, 4, false, &[_]i32{ 0, 1 }, &[_]f32{ 0.0, 0.0 });
    try testSampleCurve(std.testing.allocator, &curves, 4, true, &[_]i32{ 1, 0 }, &[_]f32{ 0.0, 0.0 });
    try testSampleCurve(std.testing.allocator, &curves, 5, false, &[_]i32{ 0, 1, 2, 3, 4, 5, 6, 7, 8, 9 }, &[_]f32{ 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0 });
    try testSampleCurve(std.testing.allocator, &curves, 5, true, &[_]i32{ 9, 8, 7, 6, 5, 4, 3, 2, 1, 0 }, &[_]f32{ 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0 });
}

test "sample curve shorter and longer" {
    var curves = try createInterpolationTestCurves(std.testing.allocator, &[_]u32{ 0, 1, 3, 13, 14, 16, 26 }, &[_]bool{ false, false, false, true, true, true }, .eight);
    defer curves.deinit();

    try testSampleCurve(std.testing.allocator, &curves, 1, false, &[_]i32{0}, &[_]f32{0.0});
    try testSampleCurve(std.testing.allocator, &curves, 1, true, &[_]i32{1}, &[_]f32{0.0});
    try testSampleCurve(std.testing.allocator, &curves, 2, false, &[_]i32{ 0, 2, 5, 9 }, &[_]f32{ 0.0, 0.82178, 0.88113, 0.0 });
    try testSampleCurve(std.testing.allocator, &curves, 2, true, &[_]i32{ 9, 5, 2, 0 }, &[_]f32{ 0.0, 0.88113, 0.82178, 0.0 });
    try testSampleCurve(std.testing.allocator, &curves, 4, false, &[_]i32{0}, &[_]f32{0.0});
    try testSampleCurve(std.testing.allocator, &curves, 4, true, &[_]i32{1}, &[_]f32{0.0});
    try testSampleCurve(std.testing.allocator, &curves, 5, false, &[_]i32{ 0, 2, 5, 7 }, &[_]f32{ 0.0, 0.5, 0.0, 0.5 });
    try testSampleCurve(std.testing.allocator, &curves, 5, true, &[_]i32{ 9, 6, 4, 1 }, &[_]f32{ 0.0, 0.50492, 0.0, 0.50492 });

    try testSampleCurve(std.testing.allocator, &curves, 1, false, &[_]i32{ 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 1 }, &[_]f32{ 0.0, 0.09091, 0.18182, 0.27273, 0.36364, 0.45455, 0.54545, 0.63636, 0.72727, 0.81818, 0.90909, 0.0 });
    try testSampleCurve(std.testing.allocator, &curves, 1, true, &[_]i32{ 1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0 }, &[_]f32{ 0.0, 0.90909, 0.81818, 0.72727, 0.63636, 0.54545, 0.45455, 0.36364, 0.27273, 0.18182, 0.09091, 0.0 });
    try testSampleCurve(std.testing.allocator, &curves, 2, false, &[_]i32{ 0, 1, 2, 2, 3, 4, 5, 6, 6, 7, 8, 9 }, &[_]f32{ 0.0, 0.0, 0.0, 0.5, 0.0, 0.0, 0.0, 0.0, 0.5, 0.0, 0.0, 0.0 });
    try testSampleCurve(std.testing.allocator, &curves, 2, true, &[_]i32{ 9, 8, 7, 6, 6, 5, 4, 3, 2, 2, 1, 0 }, &[_]f32{ 0.0, 0.0, 0.0, 0.5, 0.0, 0.0, 0.0, 0.0, 0.5, 0.0, 0.0, 0.0 });
    try testSampleCurve(std.testing.allocator, &curves, 4, false, &[_]i32{ 0, 0, 0, 0, 0, 0, 1, 1, 1, 1, 1, 1 }, &[_]f32{ 0.0, 0.16667, 0.33333, 0.5, 0.66667, 0.83333, 0.0, 0.16667, 0.33333, 0.5, 0.66667, 0.83333 });
    try testSampleCurve(std.testing.allocator, &curves, 4, true, &[_]i32{ 1, 1, 1, 1, 1, 1, 0, 0, 0, 0, 0, 0 }, &[_]f32{ 0.83333, 0.66667, 0.5, 0.33333, 0.16667, 0.0, 0.83333, 0.66667, 0.5, 0.33333, 0.16667, 0.0 });
    try testSampleCurve(std.testing.allocator, &curves, 5, false, &[_]i32{ 0, 1, 2, 2, 3, 4, 5, 6, 7, 7, 8, 9 }, &[_]f32{ 0.0, 0.0, 0.0, 0.5, 0.0, 0.0, 0.0, 0.0, 0.0, 0.5, 0.0, 0.0 });
    try testSampleCurve(std.testing.allocator, &curves, 5, true, &[_]i32{ 9, 8, 7, 6, 6, 5, 4, 3, 2, 1, 1, 0 }, &[_]f32{ 0.0, 0.0, 0.0, 0.5, 0.0, 0.0, 0.0, 0.0, 0.0, 0.5, 0.0, 0.0 });
}

test "sample zero length curve" {
    var curves = try createInterpolationTestCurves(std.testing.allocator, &[_]u32{ 0, 10, 20 }, &[_]bool{ false, true }, .zero);
    defer curves.deinit();

    try testSampleCurve(std.testing.allocator, &curves, 0, false, &[_]i32{ 0, 1, 2, 3, 4, 5, 6, 7, 8, 9 }, &[_]f32{ 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0 });
    try testSampleCurve(std.testing.allocator, &curves, 1, false, &[_]i32{ 0, 1, 2, 3, 4, 5, 6, 7, 8, 9 }, &[_]f32{ 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0 });
}

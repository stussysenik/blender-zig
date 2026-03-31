const std = @import("std");

pub const Range = struct {
    start: u32,
    end: u32,

    pub fn len(self: Range) u32 {
        return self.end - self.start;
    }
};

pub const OffsetIndices = struct {
    offsets: []const u32,

    pub fn init(offsets: []const u32) OffsetIndices {
        std.debug.assert(offsets.len > 0);
        if (offsets.len > 1) {
            for (offsets[1..], offsets[0 .. offsets.len - 1]) |current, previous| {
                std.debug.assert(current >= previous);
            }
        }
        return .{ .offsets = offsets };
    }

    pub fn len(self: OffsetIndices) usize {
        return if (self.offsets.len == 0) 0 else self.offsets.len - 1;
    }

    pub fn isEmpty(self: OffsetIndices) bool {
        return self.len() == 0;
    }

    pub fn totalSize(self: OffsetIndices) u32 {
        if (self.offsets.len < 2) return 0;
        return self.offsets[self.offsets.len - 1] - self.offsets[0];
    }

    pub fn at(self: OffsetIndices, index: usize) Range {
        std.debug.assert(index < self.len());
        return .{
            .start = self.offsets[index],
            .end = self.offsets[index + 1],
        };
    }
};

pub fn accumulateCountsToOffsets(counts_to_offsets: []u32, start_offset: u32) void {
    var offset = start_offset;
    for (counts_to_offsets) |*count| {
        const current_count = count.*;
        count.* = offset;
        offset += current_count;
    }
}

pub fn fillConstantGroupSize(group_size: u32, start_offset: u32, offsets: []u32) void {
    for (offsets, 0..) |*offset, index| {
        offset.* = start_offset + group_size * @as(u32, @intCast(index));
    }
}

test "offset helpers produce compact ranges" {
    var offsets = [_]u32{ 3, 3, 1, 0 };
    accumulateCountsToOffsets(&offsets, 0);

    const compact = OffsetIndices.init(&[_]u32{ offsets[0], offsets[1], offsets[2], 7 });
    try std.testing.expectEqual(@as(usize, 3), compact.len());
    try std.testing.expectEqual(@as(u32, 3), compact.at(0).len());
    try std.testing.expectEqual(@as(u32, 3), compact.at(1).len());
    try std.testing.expectEqual(@as(u32, 1), compact.at(2).len());
}

test "constant group size fills final offset" {
    var offsets = [_]u32{ 0, 0, 0, 0 };
    fillConstantGroupSize(4, 0, &offsets);
    try std.testing.expectEqualSlices(u32, &[_]u32{ 0, 4, 8, 12 }, &offsets);
}

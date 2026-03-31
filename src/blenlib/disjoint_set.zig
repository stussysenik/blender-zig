const std = @import("std");

// Union-find is the smallest useful subset of Blender's disjoint-set utilities for
// grouping vertices and indices during geometry cleanup passes.
pub const DisjointSet = struct {
    allocator: std.mem.Allocator,
    parents: []u32,
    ranks: []u32,

    pub fn init(allocator: std.mem.Allocator, size: usize) !DisjointSet {
        const parents = try allocator.alloc(u32, size);
        errdefer allocator.free(parents);

        const ranks = try allocator.alloc(u32, size);
        errdefer allocator.free(ranks);

        for (parents, 0..) |*parent, index| {
            parent.* = @intCast(index);
        }
        @memset(ranks, 0);

        return .{
            .allocator = allocator,
            .parents = parents,
            .ranks = ranks,
        };
    }

    pub fn deinit(self: *DisjointSet) void {
        self.allocator.free(self.parents);
        self.allocator.free(self.ranks);
    }

    pub fn findRoot(self: *DisjointSet, value: u32) u32 {
        std.debug.assert(value < self.parents.len);

        var root = value;
        while (self.parents[root] != root) {
            root = self.parents[root];
        }

        var cursor = value;
        while (self.parents[cursor] != root) {
            const parent = self.parents[cursor];
            self.parents[cursor] = root;
            cursor = parent;
        }

        return root;
    }

    pub fn join(self: *DisjointSet, a: u32, b: u32) u32 {
        var root_a = self.findRoot(a);
        var root_b = self.findRoot(b);

        if (root_a == root_b) {
            return root_a;
        }

        if (self.ranks[root_a] < self.ranks[root_b]) {
            std.mem.swap(u32, &root_a, &root_b);
        }

        self.parents[root_b] = root_a;
        if (self.ranks[root_a] == self.ranks[root_b]) {
            self.ranks[root_a] += 1;
        }
        return root_a;
    }

    pub fn inSameSet(self: *DisjointSet, a: u32, b: u32) bool {
        return self.findRoot(a) == self.findRoot(b);
    }
};

test "disjoint set joins components" {
    var set = try DisjointSet.init(std.testing.allocator, 6);
    defer set.deinit();

    try std.testing.expect(!set.inSameSet(0, 4));
    _ = set.join(0, 1);
    _ = set.join(1, 2);
    _ = set.join(4, 5);

    try std.testing.expect(set.inSameSet(0, 2));
    try std.testing.expect(!set.inSameSet(0, 4));

    _ = set.join(2, 5);
    try std.testing.expect(set.inSameSet(0, 4));
}

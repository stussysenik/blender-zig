const std = @import("std");

pub const Vec2 = struct {
    x: f32,
    y: f32,

    pub fn init(x: f32, y: f32) Vec2 {
        return .{ .x = x, .y = y };
    }
};

pub const Vec3 = struct {
    x: f32,
    y: f32,
    z: f32,

    pub fn init(x: f32, y: f32, z: f32) Vec3 {
        return .{ .x = x, .y = y, .z = z };
    }

    pub fn add(self: Vec3, other: Vec3) Vec3 {
        return .{
            .x = self.x + other.x,
            .y = self.y + other.y,
            .z = self.z + other.z,
        };
    }

    pub fn scale(self: Vec3, scalar: f32) Vec3 {
        return .{
            .x = self.x * scalar,
            .y = self.y * scalar,
            .z = self.z * scalar,
        };
    }

    pub fn min(self: Vec3, other: Vec3) Vec3 {
        return .{
            .x = @min(self.x, other.x),
            .y = @min(self.y, other.y),
            .z = @min(self.z, other.z),
        };
    }

    pub fn max(self: Vec3, other: Vec3) Vec3 {
        return .{
            .x = @max(self.x, other.x),
            .y = @max(self.y, other.y),
            .z = @max(self.z, other.z),
        };
    }
};

pub const Aabb = struct {
    min: Vec3,
    max: Vec3,

    pub fn fromPoint(point: Vec3) Aabb {
        return .{ .min = point, .max = point };
    }

    pub fn include(self: *Aabb, point: Vec3) void {
        self.min = self.min.min(point);
        self.max = self.max.max(point);
    }
};

pub fn approxEq(a: f32, b: f32, epsilon: f32) bool {
    return @abs(a - b) <= epsilon;
}

pub fn vec3ApproxEq(a: Vec3, b: Vec3, epsilon: f32) bool {
    return approxEq(a.x, b.x, epsilon) and approxEq(a.y, b.y, epsilon) and approxEq(a.z, b.z, epsilon);
}

test "vec3 helpers work" {
    const start = Vec3.init(1, 2, 3);
    const delta = Vec3.init(0.5, -2, 1);
    const actual = start.add(delta).scale(2);
    try std.testing.expect(vec3ApproxEq(actual, Vec3.init(3, 0, 8), 0.0001));
}

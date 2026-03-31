const std = @import("std");

// Keep the math layer intentionally tiny: just enough vector and bounds support for
// geometry ports without importing a larger numeric dependency surface.
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

    pub fn sub(self: Vec3, other: Vec3) Vec3 {
        return .{
            .x = self.x - other.x,
            .y = self.y - other.y,
            .z = self.z - other.z,
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

    pub fn dot(self: Vec3, other: Vec3) f32 {
        return self.x * other.x + self.y * other.y + self.z * other.z;
    }

    pub fn cross(self: Vec3, other: Vec3) Vec3 {
        return .{
            .x = self.y * other.z - self.z * other.y,
            .y = self.z * other.x - self.x * other.z,
            .z = self.x * other.y - self.y * other.x,
        };
    }

    pub fn lengthSquared(self: Vec3) f32 {
        return self.dot(self);
    }

    pub fn length(self: Vec3) f32 {
        return @sqrt(self.lengthSquared());
    }

    pub fn normalizedOr(self: Vec3, fallback: Vec3) Vec3 {
        const len_sq = self.lengthSquared();
        if (len_sq <= 1e-12) return fallback;
        return self.scale(1.0 / @sqrt(len_sq));
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

pub fn vec2ApproxEq(a: Vec2, b: Vec2, epsilon: f32) bool {
    return approxEq(a.x, b.x, epsilon) and approxEq(a.y, b.y, epsilon);
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

test "vec3 cross and normalize helpers work" {
    const x = Vec3.init(1, 0, 0);
    const y = Vec3.init(0, 1, 0);
    const z = x.cross(y).normalizedOr(Vec3.init(0, 0, -1));

    try std.testing.expect(vec3ApproxEq(z, Vec3.init(0, 0, 1), 0.0001));
    try std.testing.expect(approxEq(Vec3.init(3, 4, 0).length(), 5.0, 0.0001));
}

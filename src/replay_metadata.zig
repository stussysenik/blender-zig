const std = @import("std");

pub const ReplayMetadata = struct {
    format_version: u32 = 1,
    id: ?[]const u8 = null,
    title: ?[]const u8 = null,

    pub fn hasFields(self: ReplayMetadata) bool {
        return self.id != null or self.title != null;
    }
};

pub const SeenFields = struct {
    format_version: bool = false,
    id: bool = false,
    title: bool = false,
};

pub fn parseMetadataLine(
    metadata: *ReplayMetadata,
    seen: *SeenFields,
    key: []const u8,
    value: []const u8,
) !bool {
    if (std.mem.eql(u8, key, "format-version")) {
        if (seen.format_version) return error.DuplicateReplayMetadataKey;
        seen.format_version = true;
        metadata.format_version = try parseFormatVersion(value);
        return true;
    }
    if (std.mem.eql(u8, key, "id")) {
        if (seen.id) return error.DuplicateReplayMetadataKey;
        if (!isValidReplayId(value)) return error.InvalidReplayMetadataValue;
        seen.id = true;
        metadata.id = value;
        return true;
    }
    if (std.mem.eql(u8, key, "title")) {
        if (seen.title) return error.DuplicateReplayMetadataKey;
        if (value.len == 0) return error.InvalidReplayMetadataValue;
        seen.title = true;
        metadata.title = value;
        return true;
    }
    return false;
}

fn parseFormatVersion(value: []const u8) !u32 {
    const version = std.fmt.parseInt(u32, value, 10) catch return error.InvalidReplayMetadataValue;
    if (version != 1) return error.UnsupportedReplayFormatVersion;
    return version;
}

fn isValidReplayId(value: []const u8) bool {
    if (value.len == 0) return false;
    for (value) |byte| {
        switch (byte) {
            'a'...'z', 'A'...'Z', '0'...'9', '-', '_', '.', '/' => {},
            else => return false,
        }
    }
    return true;
}

test "replay metadata parses supported keys" {
    var metadata = ReplayMetadata{};
    var seen = SeenFields{};

    try std.testing.expect(try parseMetadataLine(&metadata, &seen, "format-version", "1"));
    try std.testing.expect(try parseMetadataLine(&metadata, &seen, "id", "phase-17/replay-bench"));
    try std.testing.expect(try parseMetadataLine(&metadata, &seen, "title", "Replay Bench"));
    try std.testing.expectEqual(@as(u32, 1), metadata.format_version);
    try std.testing.expectEqualStrings("phase-17/replay-bench", metadata.id.?);
    try std.testing.expectEqualStrings("Replay Bench", metadata.title.?);
}

test "replay metadata rejects unsupported versions and invalid ids" {
    var metadata = ReplayMetadata{};
    var seen = SeenFields{};

    try std.testing.expectError(
        error.UnsupportedReplayFormatVersion,
        parseMetadataLine(&metadata, &seen, "format-version", "2"),
    );

    metadata = .{};
    seen = .{};
    try std.testing.expectError(
        error.InvalidReplayMetadataValue,
        parseMetadataLine(&metadata, &seen, "id", "phase 17 invalid"),
    );
}

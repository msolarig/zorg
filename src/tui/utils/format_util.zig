const dep = @import("../dep.zig");

const std = dep.Stdlib.std;

pub const SizeInfo = struct {
    value: f64,
    unit: []const u8,
};

pub fn formatSize(bytes: u64) SizeInfo {
    if (bytes >= 1024 * 1024 * 1024) {
        return .{
            .value = @as(f64, @floatFromInt(bytes)) / (1024.0 * 1024.0 * 1024.0),
            .unit = "G",
        };
    }
    if (bytes >= 1024 * 1024) {
        return .{
            .value = @as(f64, @floatFromInt(bytes)) / (1024.0 * 1024.0),
            .unit = "M",
        };
    }
    if (bytes >= 1024) {
        return .{
            .value = @as(f64, @floatFromInt(bytes)) / 1024.0,
            .unit = "K",
        };
    }
    return .{
        .value = @floatFromInt(bytes),
        .unit = "B",
    };
}

pub fn formatTimestamp(alloc: std.mem.Allocator, timestamp: i64) ![]const u8 {
    const now = std.time.timestamp();
    const diff = now - timestamp;

    if (diff < 60) {
        return try std.fmt.allocPrint(alloc, "{d}s ago", .{diff});
    } else if (diff < 3600) {
        return try std.fmt.allocPrint(alloc, "{d}m ago", .{@divTrunc(diff, 60)});
    } else if (diff < 86400) {
        return try std.fmt.allocPrint(alloc, "{d}h ago", .{@divTrunc(diff, 3600)});
    } else {
        return try std.fmt.allocPrint(alloc, "{d}d ago", .{@divTrunc(diff, 86400)});
    }
}


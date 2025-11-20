const std = @import("std");

pub const OutputConfig = struct {
    name: []const u8,
};

pub const OutputManager = struct {
    dir_path: []const u8,

    pub fn init(alloc: std.mem.Allocator, name: []const u8) !OutputManager {
        var buf: [256]u8 = undefined;
        const path = try std.fmt.bufPrint(&buf, "usr/out/{s}", .{name});
        try std.fs.cwd().makePath(path);
        const owned_path = try alloc.dupe(u8, path);
        return .{
            .dir_path = owned_path,
        };
    }

    pub fn deinit(self: *OutputManager, alloc: std.mem.Allocator) void {
        alloc.free(self.dir_path);
    }

    pub fn filePath(self: *OutputManager, alloc: std.mem.Allocator, fname: []const u8) ![]u8 {
        return std.fmt.allocPrint(alloc, "{s}/{s}", .{ self.dir_path, fname });
    }
};

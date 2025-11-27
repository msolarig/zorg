const std = @import("std");
const path_util = @import("../../utils/path_utility.zig");

pub const OutputConfig = struct {
    OUTPUT_DIR_NAME: []const u8,
};

pub const OutputManager = struct {
    abs_dir_path: []u8,

    pub fn init(alloc: std.mem.Allocator, name: []const u8) !OutputManager {
        const root = try path_util.getProjectRootPath(alloc);
        defer alloc.free(root);

        const full = try std.fmt.allocPrint(
            alloc,
            "{s}/usr/out/{s}",
            .{ root, name },
        );

        try std.fs.cwd().makePath(full);

        return .{
            .abs_dir_path = full,
        };
    }

    pub fn filePath(self: *OutputManager, alloc: std.mem.Allocator, fname: []const u8) ![]u8 {
        return std.fmt.allocPrint(
            alloc,
            "{s}/{s}",
            .{ self.abs_dir_path, fname },
        );
    }

    pub fn deinit(self: *OutputManager, alloc: std.mem.Allocator) void {
        alloc.free(self.abs_dir_path);
    }
};

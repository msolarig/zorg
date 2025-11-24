const std = @import("std");

pub fn getProjectRootPath(alloc: std.mem.Allocator) ![]const u8 {
    const builtin = @import("builtin");

    if (builtin.is_test) {
        return try alloc.dupe(u8, ".");
    }

    var buf: [std.fs.max_path_bytes]u8 = undefined;
    const exe_path = try std.fs.selfExePath(&buf);

    const bin_dir = std.fs.path.dirname(exe_path) orelse return error.BadExePath;
    const zig_out_dir = std.fs.path.dirname(bin_dir) orelse return error.BadExePath;
    const root_dir = std.fs.path.dirname(zig_out_dir) orelse return error.BadExePath;

    return try alloc.dupe(u8, root_dir);
}

fn findExistingFile(alloc: std.mem.Allocator, root_abs: []const u8, file_name: []const u8, dirs: []const []const u8) ![]const u8 {
    var cwd = std.fs.cwd();

    for (dirs) |dir| {
        const full = try std.fmt.allocPrint(alloc, "{s}/{s}/{s}", .{
            root_abs,
            dir,
            file_name,
        });

        if (cwd.access(full, .{})) |_| {
            return full;
        } else |_| {
            alloc.free(full);
        }
    }
    return error.FileNotFound;
}

fn resolveAutoDylibPath(alloc: std.mem.Allocator, root_abs: []const u8, zig_file: []const u8) ![]u8 {
    const file_name = std.fs.path.basename(zig_file);

    const stem = file_name[0..file_name.len];

    return try std.fmt.allocPrint(alloc, "{s}/zig-out/bin/auto/{s}.dylib", .{
        root_abs,
        stem,
    });
}

pub fn mapRelPathToAbsPath(alloc: std.mem.Allocator, map_path: []const u8) ![]const u8 {
    const file_name = std.fs.path.basename(map_path);

    if (!std.mem.endsWith(u8, file_name, ".json") and !std.mem.endsWith(u8, file_name, ".jsonc"))
        return error.InvalidFileType;

    const root_abs = try getProjectRootPath(alloc);
    defer alloc.free(root_abs);

    return try findExistingFile(
        alloc,
        root_abs,
        file_name,
        &.{
            "usr/map",
            "test/map",
        },
    );
}

pub fn autoSrcRelPathToCompiledAbsPath(alloc: std.mem.Allocator, auto_path: []const u8) ![]const u8 {
    const root_abs = try getProjectRootPath(alloc);
    defer alloc.free(root_abs);

    return try resolveAutoDylibPath(alloc, root_abs, auto_path);
}

pub fn dbRelPathToAbsPath(alloc: std.mem.Allocator, db_path: []const u8) ![]const u8 {
    const file_name = std.fs.path.basename(db_path);

    if (!std.mem.endsWith(u8, file_name, ".db"))
        return error.InvalidFilePath;

    const root_abs = try getProjectRootPath(alloc);
    defer alloc.free(root_abs);

    return try findExistingFile(
        alloc,
        root_abs,
        file_name,
        &.{
            "usr/data",
            "test/data",
        },
    );
}

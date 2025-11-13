const std = @import("std");

/// Get the root directory's absolute system path
pub fn getProjectRootPath(alloc: std.mem.Allocator) ![]u8 {
    var buf: [std.fs.max_path_bytes]u8 = undefined;
    const exe_path = try std.fs.selfExePath(&buf);

    const bin_dir = std.fs.path.dirname(exe_path) orelse return error.BadExePath;
    const zig_out_dir = std.fs.path.dirname(bin_dir) orelse return error.BadExePath;
    const project_root = std.fs.path.dirname(zig_out_dir) orelse return error.BadExePath;

    return try alloc.dupe(u8, project_root);
}

/// Converts "usr/maps/MAP.json" to its absolute system path
pub fn mapRelPathToAbsPath(alloc: std.mem.Allocator, map_path: []const u8) ![]const u8 {
  const file_name = std.fs.path.basename(map_path);
  if (!std.mem.endsWith(u8, file_name, ".json"))
        return error.InvalidFileType;

  const root_abs_path = try getProjectRootPath(alloc);
  defer alloc.free(root_abs_path);
    
  return try std.fmt.allocPrint(alloc, "{s}/usr/maps/{s}", .{root_abs_path, file_name});
}

/// Converts "usr/autos/AUTO.zig" to its absolute system path
pub fn autoSrcRelPathToCompiledAbsPath(alloc: std.mem.Allocator, auto_path: []const u8) ![]const u8 {
  const file_name = std.fs.path.basename(auto_path);
  if (!std.mem.endsWith(u8, file_name, ".zig"))
        return error.InvalidFilePath;

  const file_stem = file_name[0 .. file_name.len - ".zig".len];

  const root_abs_path = try getProjectRootPath(alloc);
  defer alloc.free(root_abs_path);
    
  return try std.fmt.allocPrint(alloc, "{s}/zig-out/bin/usr/autos/{s}.dylib", .{root_abs_path, file_stem});
}

/// Converts "usr/data/DB.db" to its absolute system path
pub fn dbRelPathToAbsPath(alloc: std.mem.Allocator, db_path: []const u8) ![]const u8 {
  const file_name = std.fs.path.basename(db_path);
  if (!std.mem.endsWith(u8, file_name, ".db"))
    return error.InvalidFilePath;

  const root_abs_path = try getProjectRootPath(alloc);
  defer alloc.free(root_abs_path);

 return try std.fmt.allocPrint(alloc, "{s}/usr/data/{s}", .{root_abs_path, file_name});
}

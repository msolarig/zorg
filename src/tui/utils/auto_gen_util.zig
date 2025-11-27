const dep = @import("../dep.zig");

const std = dep.Stdlib.std;

const project_path_util = dep.ProjectUtils.path_util;

pub fn createAuto(alloc: std.mem.Allocator, auto_name: []const u8, project_root: []const u8) !void {
    // Validate auto name
    if (auto_name.len == 0) {
        return error.EmptyAutoName;
    }

    // Build paths
    const auto_dir = try std.fs.path.join(alloc, &.{ project_root, "usr", "auto", auto_name });
    defer alloc.free(auto_dir);

    const template_path = try std.fs.path.join(alloc, &.{ project_root, "src", "temp", "sample_auto.zig" });
    defer alloc.free(template_path);

    const zdk_source = try std.fs.path.join(alloc, &.{ project_root, "zdk", "zdk.zig" });
    defer alloc.free(zdk_source);

    const auto_file = try std.fs.path.join(alloc, &.{ auto_dir, "auto.zig" });
    defer alloc.free(auto_file);

    const zdk_dest = try std.fs.path.join(alloc, &.{ auto_dir, "zdk.zig" });
    defer alloc.free(zdk_dest);

    // Check if auto already exists
    var cwd = std.fs.cwd();
    if (cwd.access(auto_dir, .{})) |_| {
        return error.AutoAlreadyExists;
    } else |_| {}

    // Check if template exists
    cwd.access(template_path, .{}) catch {
        return error.TemplateNotFound;
    };

    // Check if ZDK source exists
    cwd.access(zdk_source, .{}) catch {
        return error.ZDKNotFound;
    };

    // Create auto directory
    try cwd.makePath(auto_dir);

    // Copy template to auto.zig
    try copyFile(alloc, template_path, auto_file);

    // Copy ZDK to zdk.zig (snapshot)
    try copyFile(alloc, zdk_source, zdk_dest);
}

pub const CompileResult = struct {
    stderr: []const u8,
};

pub fn compileAuto(alloc: std.mem.Allocator, auto_name: []const u8, project_root: []const u8) !CompileResult {
    // Build paths - use absolute paths for reliable access
    const auto_dir = try std.fs.path.join(alloc, &.{ project_root, "usr", "auto", auto_name });
    defer alloc.free(auto_dir);

    const auto_file = try std.fs.path.join(alloc, &.{ auto_dir, "auto.zig" });
    defer alloc.free(auto_file);

    const output_dir = try std.fs.path.join(alloc, &.{ project_root, "zig-out", "bin", "auto" });
    defer alloc.free(output_dir);

    // Check if auto source file exists - use absolute path
    const auto_file_abs = if (std.fs.path.isAbsolute(auto_file))
        try alloc.dupe(u8, auto_file)
    else
        try std.fs.path.join(alloc, &.{ project_root, auto_file });
    defer alloc.free(auto_file_abs);
    
    var cwd = std.fs.cwd();
    cwd.access(auto_file_abs, .{}) catch {
        return error.AutoNotFound;
    };

    // Create output directory if it doesn't exist
    cwd.makePath(output_dir) catch |err| {
        if (err != error.PathAlreadyExists) {
            return err;
        }
    };

    // Compile the auto - pass absolute path and capture stderr
    return compileAutoInternal(alloc, auto_file_abs, auto_name, output_dir);
}

fn copyFile(alloc: std.mem.Allocator, src_path: []const u8, dest_path: []const u8) !void {
    const src_file = try std.fs.cwd().openFile(src_path, .{});
    defer src_file.close();

    const dest_file = try std.fs.cwd().createFile(dest_path, .{});
    defer dest_file.close();

    const src_content = try src_file.readToEndAlloc(alloc, std.math.maxInt(usize));
    defer alloc.free(src_content);

    try dest_file.writeAll(src_content);
}

fn compileAutoInternal(alloc: std.mem.Allocator, auto_file: []const u8, auto_name: []const u8, output_dir: []const u8) !CompileResult {
    const builtin = @import("builtin");
    const ext = if (builtin.os.tag == .macos) ".dylib" else ".so";

    // Get project root
    const project_root = try project_path_util.getProjectRootPath(alloc);
    defer alloc.free(project_root);
    
    // Convert absolute paths to relative paths (relative to project_root) for zig
    // Since we set cwd to project_root, zig expects relative paths
    const auto_file_rel = if (std.fs.path.isAbsolute(auto_file)) blk: {
        // Strip project_root prefix to get relative path
        if (std.mem.startsWith(u8, auto_file, project_root)) {
            const rel = auto_file[project_root.len..];
            // Skip leading slash if present
            const rel_path = if (rel.len > 0 and rel[0] == '/') rel[1..] else rel;
            break :blk try alloc.dupe(u8, rel_path);
        } else {
            break :blk try alloc.dupe(u8, auto_file);
        }
    } else try alloc.dupe(u8, auto_file);
    defer alloc.free(auto_file_rel);
    
    // Ensure output directory exists (use absolute path for makePath)
    const output_dir_abs = if (std.fs.path.isAbsolute(output_dir))
        try alloc.dupe(u8, output_dir)
    else
        try std.fs.path.join(alloc, &.{ project_root, output_dir });
    defer alloc.free(output_dir_abs);
    
    try std.fs.cwd().makePath(output_dir_abs);
    
    // Build relative output path for zig
    const output_file_name = try std.fmt.allocPrint(alloc, "{s}{s}", .{ auto_name, ext });
    defer alloc.free(output_file_name);
    
    const output_file_rel = try std.fs.path.join(alloc, &.{ output_dir, output_file_name });
    defer alloc.free(output_file_rel);
    
    // Build -femit-bin argument as a single string (like Python script does)
    const emit_bin_arg = try std.fmt.allocPrint(alloc, "-femit-bin={s}", .{output_file_rel});
    defer alloc.free(emit_bin_arg);
    
    const zig_args = [_][]const u8{
        "zig",
        "build-lib",
        "-dynamic",
        "-O",
        "ReleaseSafe",
        "-fPIC",
        "-fstrip",
        auto_file_rel,
        emit_bin_arg,
    };

    // Execute zig build-lib from project root
    // Capture stderr to show compilation errors
    const result = try std.process.Child.run(.{
        .allocator = alloc,
        .argv = &zig_args,
        .cwd = project_root,
        .max_output_bytes = 1024 * 1024, // 1MB limit
    });
    defer alloc.free(result.stdout);
    defer alloc.free(result.stderr);
    
    // Check exit code - zig will report errors if compilation fails
    // We don't need to verify the dylib exists; the engine will look for it during assembly
    switch (result.term) {
        .Exited => |code| {
            if (code != 0) {
                // Return stderr so caller can log it
                const stderr_copy = try alloc.dupe(u8, result.stderr);
                return CompileResult{ .stderr = stderr_copy };
            }
        },
        else => {
            const stderr_copy = try alloc.dupe(u8, result.stderr);
            return CompileResult{ .stderr = stderr_copy };
        },
    }
    
    // Success - return empty stderr
    return CompileResult{ .stderr = try alloc.dupe(u8, "") };
}


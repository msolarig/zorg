const std = @import("std");
const path_util = @import("path_utility.zig");
const auto_creator = @import("auto_creator.zig");

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const alloc = gpa.allocator();

    const args = try std.process.argsAlloc(alloc);
    defer std.process.argsFree(alloc, args);

    if (args.len < 2) {
        std.debug.print("Usage: {s} <auto_name>\n", .{args[0]});
        std.debug.print("Creates a new auto with the specified name.\n", .{});
        std.debug.print("\nNote: This tool is also available in the TUI via ':create-auto <name>'\n", .{});
        std.process.exit(1);
    }

    const auto_name = args[1];

    // Get project root
    const project_root = try path_util.getProjectRootPath(alloc);
    defer alloc.free(project_root);

    std.debug.print("Creating auto '{s}'...\n", .{auto_name});

    auto_creator.createAuto(alloc, auto_name, project_root) catch |err| {
        const err_msg = switch (err) {
            error.AutoAlreadyExists => "Auto already exists",
            error.TemplateNotFound => "Template not found",
            error.ZDKNotFound => "ZDK source not found",
            error.EmptyAutoName => "Auto name cannot be empty",
            else => @errorName(err),
        };
        std.debug.print("Error: Failed to create auto '{s}': {s}\n", .{ auto_name, err_msg });
        std.process.exit(1);
    };

    std.debug.print("\nSuccessfully created auto '{s}'\n", .{auto_name});
    std.debug.print("  Location: usr/auto/{s}/\n", .{auto_name});
    std.debug.print("  Files: auto.zig, zdk.zig\n", .{});
}

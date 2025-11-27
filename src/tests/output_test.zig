const std = @import("std");
const OutputManager = @import("../engine/output/output_manager.zig").OutputManager;
const logger = @import("../engine/output/logger.zig");
const abi = @import("../zdk/abi.zig");

test "Output: Logger creates valid log file" {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const alloc = gpa.allocator();

    // Create temp output directory
    const temp_dir = "test_output_logger";
    std.fs.cwd().makeDir(temp_dir) catch {};
    defer std.fs.cwd().deleteTree(temp_dir) catch {};

    var out = try OutputManager.init(alloc, temp_dir);
    defer out.deinit(alloc);

    // Create sample logs
    var immediate_logs: [2]abi.LogEntry = undefined;
    immediate_logs[0] = .{
        .level = .Error,
        .message = undefined,
        .length = 10,
    };
    @memcpy(immediate_logs[0].message[0..10], "Test error");
    
    immediate_logs[1] = .{
        .level = .Warn,
        .message = undefined,
        .length = 12,
    };
    @memcpy(immediate_logs[1].message[0..12], "Test warning");

    var buffered_logs: [1]abi.LogEntry = undefined;
    buffered_logs[0] = .{
        .level = .Info,
        .message = undefined,
        .length = 9,
    };
    @memcpy(buffered_logs[0].message[0..9], "Test info");

    // Write log file
    try logger.writeLogFile(&out, &immediate_logs, &buffered_logs, "test.log");

    // Verify file exists and has content
    const log_path = try out.filePath(alloc, "test.log");
    defer alloc.free(log_path);
    
    const file = try std.fs.cwd().openFile(log_path, .{});
    defer file.close();
    
    const contents = try file.readToEndAlloc(alloc, 1024 * 1024);
    defer alloc.free(contents);
    
    // Verify content contains our logs
    try std.testing.expect(std.mem.indexOf(u8, contents, "Test error") != null);
    try std.testing.expect(std.mem.indexOf(u8, contents, "Test warning") != null);
    try std.testing.expect(std.mem.indexOf(u8, contents, "Test info") != null);
    try std.testing.expect(std.mem.indexOf(u8, contents, "IMMEDIATE LOGS") != null);
    try std.testing.expect(std.mem.indexOf(u8, contents, "BUFFERED LOGS") != null);
}

test "Output: OutputManager creates directory" {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const alloc = gpa.allocator();

    const temp_dir = "test_output_dir";
    
    var out = try OutputManager.init(alloc, temp_dir);
    defer {
        out.deinit(alloc);
        std.fs.cwd().deleteTree("usr/out/test_output_dir") catch {};
    }

    // Verify the absolute path was created (in usr/out/)
    var dir = try std.fs.cwd().openDir(out.abs_dir_path, .{});
    dir.close();
}

test "Output: filePath generates correct paths" {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const alloc = gpa.allocator();

    const temp_dir = "test_paths";
    std.fs.cwd().makeDir(temp_dir) catch {};
    defer std.fs.cwd().deleteTree(temp_dir) catch {};

    var out = try OutputManager.init(alloc, temp_dir);
    defer out.deinit(alloc);

    const path1 = try out.filePath(alloc, "test.log");
    defer alloc.free(path1);
    
    const path2 = try out.filePath(alloc, "data.db");
    defer alloc.free(path2);

    // Verify paths contain the output directory
    try std.testing.expect(std.mem.indexOf(u8, path1, temp_dir) != null);
    try std.testing.expect(std.mem.indexOf(u8, path2, temp_dir) != null);
    
    // Verify filenames are correct
    try std.testing.expect(std.mem.endsWith(u8, path1, "test.log"));
    try std.testing.expect(std.mem.endsWith(u8, path2, "data.db"));
}

test "Output: Multiple log entries formatted correctly" {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const alloc = gpa.allocator();

    const temp_dir = "test_multi_logs";
    std.fs.cwd().makeDir(temp_dir) catch {};
    defer std.fs.cwd().deleteTree(temp_dir) catch {};

    var out = try OutputManager.init(alloc, temp_dir);
    defer out.deinit(alloc);

    // Create 10 log entries
    var logs: [10]abi.LogEntry = undefined;
    for (0..10) |i| {
        logs[i] = .{
            .level = if (i % 2 == 0) .Info else .Debug,
            .message = undefined,
            .length = 6,
        };
        @memcpy(logs[i].message[0..6], "Entry ");
    }

    try logger.writeLogFile(&out, &[_]abi.LogEntry{}, &logs, "multi.log");

    const log_path = try out.filePath(alloc, "multi.log");
    defer alloc.free(log_path);
    
    const file = try std.fs.cwd().openFile(log_path, .{});
    defer file.close();
    
    const contents = try file.readToEndAlloc(alloc, 1024 * 1024);
    defer alloc.free(contents);
    
    // Count "INF" and "DEB" occurrences
    var inf_count: usize = 0;
    var deb_count: usize = 0;
    var i: usize = 0;
    while (i < contents.len - 2) : (i += 1) {
        if (std.mem.eql(u8, contents[i..i+3], "INF")) inf_count += 1;
        if (std.mem.eql(u8, contents[i..i+3], "DEB")) deb_count += 1;
    }
    
    try std.testing.expectEqual(@as(usize, 5), inf_count);
    try std.testing.expectEqual(@as(usize, 5), deb_count);
}


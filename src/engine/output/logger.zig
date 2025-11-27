const std = @import("std");
const OutputManager = @import("output_manager.zig").OutputManager;
const abi = @import("../../zdk/abi.zig");

pub const LoggerError = error{
    FileCreationFailed,
    WriteError,
    PathError,
} || std.mem.Allocator.Error || std.fs.File.WriteError;

pub fn writeLogFile(out: *OutputManager, immediate_logs: []const abi.LogEntry, buffered_logs: []const abi.LogEntry, filename: []const u8) LoggerError!void {
    const full_path = out.filePath(std.heap.page_allocator, filename) catch |err| {
        std.debug.print("Error: Failed to resolve log file path: {s}\n", .{@errorName(err)});
        return LoggerError.PathError;
    };
    defer std.heap.page_allocator.free(full_path);

    var file = std.fs.cwd().createFile(full_path, .{ .truncate = true }) catch |err| {
        std.debug.print("Error: Failed to create log file: {s}\n", .{full_path});
        std.debug.print("Details: {s}\n", .{@errorName(err)});
        return LoggerError.FileCreationFailed;
    };
    defer file.close();

    var buf: [4096]u8 = undefined;
    var bw = file.writer(&buf);

    const timestamp = std.time.timestamp();
    const datetime = @divFloor(timestamp, 1);

    _ = try bw.file.write("=== Auto Runtime Log ===\n");
    
    var line_buf: [128]u8 = undefined;
    var line = try std.fmt.bufPrint(&line_buf, "Timestamp: {d}\n", .{datetime});
    _ = try bw.file.write(line);
    
    line = try std.fmt.bufPrint(&line_buf, "Immediate Logs: {d}\n", .{immediate_logs.len});
    _ = try bw.file.write(line);
    
    line = try std.fmt.bufPrint(&line_buf, "Buffered Logs: {d}\n\n", .{buffered_logs.len});
    _ = try bw.file.write(line);

    if (immediate_logs.len > 0) {
        _ = try bw.file.write("========================================\n");
        _ = try bw.file.write("  IMMEDIATE LOGS (Critical Messages)\n");
        _ = try bw.file.write("========================================\n\n");

        for (immediate_logs) |entry| {
            const level_str = switch (entry.level) {
                .Debug => "DEB",
                .Info => "INF",
                .Warn => "WRN",
                .Error => "ERR",
            };

            const message = entry.message[0..entry.length];
            line = try std.fmt.bufPrint(&line_buf, "[{s}] {s}\n", .{ level_str, message });
            _ = try bw.file.write(line);
        }
        
        _ = try bw.file.write("\n");
    }

    if (buffered_logs.len > 0) {
        _ = try bw.file.write("========================================\n");
        _ = try bw.file.write("  BUFFERED LOGS (Detailed Trace)\n");
        _ = try bw.file.write("========================================\n\n");

        for (buffered_logs) |entry| {
            const level_str = switch (entry.level) {
                .Debug => "DEB",
                .Info => "INF",
                .Warn => "WRN",
                .Error => "ERR",
            };

            const message = entry.message[0..entry.length];
            line = try std.fmt.bufPrint(&line_buf, "[{s}] {s}\n", .{ level_str, message });
            _ = try bw.file.write(line);
        }
    }

    try file.sync();
}


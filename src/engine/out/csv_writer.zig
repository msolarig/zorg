const std = @import("std");
const OutputManager = @import("output.zig").OutputManager;
const FillManager = @import("../../roblang/core/fill.zig").FillManager;

/// Writes fills to CSV inside: <output_manager.dir_path>/<filename>
pub fn writeFillsCSV(
    out: *OutputManager,
    alloc: std.mem.Allocator,
    fm: *FillManager,
    filename: []const u8,
) !void {
    // Build full output file path using OutputManager
    const full_path = try out.filePath(alloc, filename);
    defer alloc.free(full_path);

    // Create or truncate file
    var file = try std.fs.cwd().createFile(full_path, .{ .truncate = true });
    defer file.close();

    // Writer buffer
    var buf: [4096]u8 = undefined;
    var bw = file.writer(&buf);

    // Header
    _ = try bw.file.write("Count,Index,Timestamp,Side,Price,Volume\n");

    var fill_count: u32 = 0;

    // Write each fill
    for (fm.fills.items) |fill| {
        const side_str = switch (fill.side) {
            .Buy => "Buy",
            .Sell => "Sell",
        };

        fill_count += 1;

        var line_buf: [128]u8 = undefined;
        const line = try std.fmt.bufPrint(
            &line_buf,
            "{d:05},{d:05},{d},{s},{d:.4},{d:.4}\n",
            .{ fill_count, fill.iter, fill.timestamp, side_str, fill.price, fill.volume },
        );

        _ = try bw.file.write(line);
    }

    // Ensure the data hits disk
    try file.sync();
}

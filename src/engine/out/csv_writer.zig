const std = @import("std");
const PositionManager = @import("../../roblang/core/position.zig").PositionManager;

pub fn writePositionsCSV(pm: *PositionManager, filename: []const u8) !void {
    var path_buf: [256]u8 = undefined;
    const full_path = try std.fmt.bufPrint(&path_buf, "usr/out/{s}", .{ filename });

    var file = try std.fs.cwd().createFile(full_path, .{ .truncate = true });
    defer file.close();

    var buf: [4096]u8 = undefined;
    var bw = file.writer(&buf);

    _ = try bw.file.write("side,price,volume\n");

    for (pm.positions.items) |pos| {
        const side_str = switch (pos.side) {
            .Buy => "BUY",
            .Sell => "SELL",
        };

        var line_buf: [128]u8 = undefined;
        const line = try std.fmt.bufPrint(
            &line_buf,
            "{s},{d:.4},{d:.4}\n",
            .{ side_str, pos.price, pos.volume },
        );

        _ = try bw.file.write(line);
    }

    try file.sync();
}

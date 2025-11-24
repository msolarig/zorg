const std = @import("std");
const OutputManager = @import("output.zig").OutputManager;
const OrderManager = @import("../../zdk/core/order.zig").OrderManager;
const FillManager = @import("../../zdk/core/fill.zig").FillManager;
const PositionManager = @import("../../zdk/core/position.zig").PositionManager;

pub fn writeOrderCSV(out: *OutputManager, om: *OrderManager, filename: []const u8) !void {
    const full_path = try out.filePath(std.heap.page_allocator, filename);
    defer std.heap.page_allocator.free(full_path);

    var file = try std.fs.cwd().createFile(full_path, .{ .truncate = true });
    defer file.close();

    var buf: [4096]u8 = undefined;
    var bw = file.writer(&buf);

    _ = try bw.file.write("Count,Index,Timestamp,Side,Price,Volume\n");

    var count: usize = 0;

    for (om.orders.items) |order| {
        count += 1;

        const side_str = switch (order.side) {
            .Buy => "Buy Order",
            .Sell => "Sell Order",
        };

        var line_buf: [128]u8 = undefined;
        const line = try std.fmt.bufPrint(
            &line_buf,
            "{d:05},{d:05},{d},{s},{d:.4},{d:.4}\n",
            .{ count, order.iter, order.timestamp, side_str, order.price, order.volume },
        );

        _ = try bw.file.write(line);
    }

    try file.sync();
}

pub fn writeFillsCSV(out: *OutputManager, fm: *FillManager, filename: []const u8) !void {
    const full_path = try out.filePath(std.heap.page_allocator, filename);
    defer std.heap.page_allocator.free(full_path);

    var file = try std.fs.cwd().createFile(full_path, .{ .truncate = true });
    defer file.close();

    var buf: [4096]u8 = undefined;
    var bw = file.writer(&buf);

    _ = try bw.file.write("Count,Index,Timestamp,Side,Price,Volume\n");

    var count: usize = 0;

    for (fm.fills.items) |fill| {
        count += 1;

        const side_str = switch (fill.side) {
            .Buy => "Buy Fill",
            .Sell => "Sell Fill",
        };

        var line_buf: [128]u8 = undefined;
        const line = try std.fmt.bufPrint(
            &line_buf,
            "{d:05},{d:05},{d},{s},{d:.4},{d:.4}\n",
            .{ count, fill.iter, fill.timestamp, side_str, fill.price, fill.volume },
        );

        _ = try bw.file.write(line);
    }

    try file.sync();
}

pub fn writePositionCSV(out: *OutputManager, pm: *PositionManager, filename: []const u8) !void {
    const full_path = try out.filePath(std.heap.page_allocator, filename);
    defer std.heap.page_allocator.free(full_path);

    var file = try std.fs.cwd().createFile(full_path, .{ .truncate = true });
    defer file.close();

    var buf: [4096]u8 = undefined;
    var bw = file.writer(&buf);

    _ = try bw.file.write("side\n");

    var count: usize = 0;

    for (pm.positions.items) |position| {
        count += 1;

        const side_str = switch (position.side) {
            .Buy => "Long",
            .Sell => "Short",
        };

        var line_buf: [128]u8 = undefined;
        const line = try std.fmt.bufPrint(
            &line_buf,
            "{s}\n",
            .{side_str},
        );

        _ = try bw.file.write(line);
    }

    try file.sync();
}

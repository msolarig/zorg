const std = @import("std");
const core = @import("../zdk/core.zig");
const Fill = core.Fill;
const FillManager = core.FillManager;
const FillSide = core.FillSide;

test "Fill.init creates fill with correct values" {
    const fill = Fill.init(50, 1735516800, .Buy, 155.25, 100.0);

    try std.testing.expectEqual(fill.iter, 50);
    try std.testing.expectEqual(fill.timestamp, 1735516800);
    try std.testing.expectEqual(fill.side, .Buy);
    try std.testing.expectEqual(fill.price, 155.25);
    try std.testing.expectEqual(fill.volume, 100.0);
}

test "FillManager.init creates empty manager" {
    const fm = FillManager.init();

    try std.testing.expectEqual(fm.fills.items.len, 0);
    try std.testing.expectEqual(fm.abi_buffer.items.len, 0);
    try std.testing.expectEqual(fm.abi.count, 0);
}

test "FillManager.toABI returns empty FillABI when no fills" {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const alloc = gpa.allocator();

    var fm = FillManager.init();
    defer fm.deinit(alloc);

    const abi_result = try fm.toABI(alloc);

    try std.testing.expectEqual(abi_result.count, 0);
}

test "FillManager.deinit frees all memory" {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    const alloc = gpa.allocator();

    var fm = FillManager.init();
    _ = try fm.toABI(alloc);

    fm.deinit(alloc);

    const leak_status = gpa.deinit();
    try std.testing.expect(leak_status == .ok);
}

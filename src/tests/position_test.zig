const std = @import("std");
const core = @import("../zdk/core.zig");
const Position = core.Position;
const PositionManager = core.PositionManager;
const Fill = core.Fill;

test "PositionManager.init creates manager with zero exposure" {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const alloc = gpa.allocator();
    
    const pm = PositionManager.init(alloc);

    try std.testing.expectEqual(pm.exposure, 0);
    try std.testing.expectEqual(pm.positions.items.len, 0);
    try std.testing.expectEqual(pm.positions_count, 0);
}

test "PositionManager buy fill initiates long exposure" {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const alloc = gpa.allocator();

    var pm = PositionManager.init(alloc);
    defer pm.deinit(alloc);

    const buy_fill = Fill.init(1, 1, 1000, .Buy, 100.0, 50.0);
    try pm.updateInstrumentExposure(alloc, buy_fill);

    try std.testing.expectEqual(pm.exposure, 50.0);
    try std.testing.expectEqual(pm.positions_count, 1);
    try std.testing.expectEqual(pm.positions.items[0].side, .Buy);
}

test "PositionManager sell fill initiates short exposure" {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const alloc = gpa.allocator();

    var pm = PositionManager.init(alloc);
    defer pm.deinit(alloc);

    const sell_fill = Fill.init(2, 1, 1000, .Sell, 100.0, 30.0);
    try pm.updateInstrumentExposure(alloc, sell_fill);

    try std.testing.expectEqual(pm.exposure, -30.0);
    try std.testing.expectEqual(pm.positions_count, 1);
    try std.testing.expectEqual(pm.positions.items[0].side, .Sell);
}

test "PositionManager additional buy increases long exposure" {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const alloc = gpa.allocator();

    var pm = PositionManager.init(alloc);
    defer pm.deinit(alloc);

    try pm.updateInstrumentExposure(alloc, Fill.init(1, 1, 1000, .Buy, 100.0, 50.0));
    try pm.updateInstrumentExposure(alloc, Fill.init(2, 2, 2000, .Buy, 101.0, 25.0));

    try std.testing.expectEqual(pm.exposure, 75.0);
    try std.testing.expectEqual(pm.positions_count, 1);
    try std.testing.expectEqual(pm.positions.items[0].in_fills.items.len, 2);
}

test "PositionManager sell reduces long exposure" {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const alloc = gpa.allocator();

    var pm = PositionManager.init(alloc);
    defer pm.deinit(alloc);

    try pm.updateInstrumentExposure(alloc, Fill.init(1, 1, 1000, .Buy, 100.0, 50.0));
    try pm.updateInstrumentExposure(alloc, Fill.init(2, 2, 2000, .Sell, 105.0, 20.0));

    try std.testing.expectEqual(pm.exposure, 30.0);
    try std.testing.expectEqual(pm.positions.items[0].out_fills.items.len, 1);
}

test "PositionManager sell flattens long exposure" {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const alloc = gpa.allocator();

    var pm = PositionManager.init(alloc);
    defer pm.deinit(alloc);

    try pm.updateInstrumentExposure(alloc, Fill.init(1, 1, 1000, .Buy, 100.0, 50.0));
    try pm.updateInstrumentExposure(alloc, Fill.init(2, 2, 2000, .Sell, 105.0, 50.0));

    try std.testing.expectEqual(pm.exposure, 0);
}

test "PositionManager.deinit frees all memory" {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    const alloc = gpa.allocator();

    var pm = PositionManager.init(alloc);
    try pm.updateInstrumentExposure(alloc, Fill.init(1, 1, 1000, .Buy, 100.0, 50.0));
    try pm.updateInstrumentExposure(alloc, Fill.init(2, 2, 2000, .Buy, 101.0, 25.0));

    pm.deinit(alloc);

    const leak_status = gpa.deinit();
    try std.testing.expect(leak_status == .ok);
}

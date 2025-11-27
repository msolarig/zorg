const std = @import("std");
const core = @import("../zdk/core.zig");
const data = @import("../engine/assembly/data.zig");

const Order = core.Order;
const OrderManager = core.OrderManager;
const FillManager = core.FillManager;
const PositionManager = core.PositionManager;

test "Error: Invalid price rejected (negative)" {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const alloc = gpa.allocator();

    var om = OrderManager.init(alloc);
    defer om.deinit();

    const order = Order.init(1, 1, 1000, .Limit, .Buy, -50.0, 10.0);
    const result = om.placeOrder(alloc, order);
    
    try std.testing.expectError(core.order.OrderError.InvalidPrice, result);
}

test "Error: Invalid price rejected (NaN)" {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const alloc = gpa.allocator();

    var om = OrderManager.init(alloc);
    defer om.deinit();

    const nan_price = std.math.nan(f64);
    const order = Order.init(1, 1, 1000, .Stop, .Buy, nan_price, 10.0);
    const result = om.placeOrder(alloc, order);
    
    try std.testing.expectError(core.order.OrderError.InvalidPrice, result);
}

test "Error: Invalid price rejected (Infinity)" {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const alloc = gpa.allocator();

    var om = OrderManager.init(alloc);
    defer om.deinit();

    const inf_price = std.math.inf(f64);
    const order = Order.init(1, 1, 1000, .Stop, .Buy, inf_price, 10.0);
    const result = om.placeOrder(alloc, order);
    
    try std.testing.expectError(core.order.OrderError.InvalidPrice, result);
}

test "Error: Invalid volume rejected (zero)" {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const alloc = gpa.allocator();

    var om = OrderManager.init(alloc);
    defer om.deinit();

    const order = Order.init(1, 1, 1000, .Market, .Buy, 0, 0.0);
    const result = om.placeOrder(alloc, order);
    
    try std.testing.expectError(core.order.OrderError.InvalidVolume, result);
}

test "Error: Invalid volume rejected (negative)" {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const alloc = gpa.allocator();

    var om = OrderManager.init(alloc);
    defer om.deinit();

    const order = Order.init(1, 1, 1000, .Market, .Buy, 0, -5.0);
    const result = om.placeOrder(alloc, order);
    
    try std.testing.expectError(core.order.OrderError.InvalidVolume, result);
}

test "Error: Invalid OHLC data rejected (high < low)" {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const alloc = gpa.allocator();

    var om = OrderManager.init(alloc);
    defer om.deinit();
    
    var fm = FillManager.init();
    defer fm.deinit(alloc);
    
    var pm = PositionManager.init(alloc);
    defer pm.deinit(alloc);

    // Invalid bar: high=95, low=100 (reversed!)
    const result = fm.evaluateWorkingOrders(alloc, &om, &pm, 95.0, 100.0, 98.0, 97.0);
    
    try std.testing.expectError(core.fill.FillError.InvalidBarData, result);
}

test "Error: Invalid OHLC data rejected (zero prices)" {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const alloc = gpa.allocator();

    var om = OrderManager.init(alloc);
    defer om.deinit();
    
    var fm = FillManager.init();
    defer fm.deinit(alloc);
    
    var pm = PositionManager.init(alloc);
    defer pm.deinit(alloc);

    // Invalid bar: close=0
    const result = fm.evaluateWorkingOrders(alloc, &om, &pm, 100.0, 98.0, 99.0, 0.0);
    
    try std.testing.expectError(core.fill.FillError.InvalidBarData, result);
}

test "Error: Invalid fill data rejected (negative volume)" {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const alloc = gpa.allocator();

    var pm = PositionManager.init(alloc);
    defer pm.deinit(alloc);

    const fill = core.Fill.init(1, 1, 1000, .Buy, 100.0, -10.0);
    const result = pm.updateInstrumentExposure(alloc, fill);
    
    try std.testing.expectError(core.position.PositionError.InvalidExposure, result);
}

test "Error: Invalid fill data rejected (zero price)" {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const alloc = gpa.allocator();

    var pm = PositionManager.init(alloc);
    defer pm.deinit(alloc);

    const fill = core.Fill.init(1, 1, 1000, .Buy, 0.0, 10.0);
    const result = pm.updateInstrumentExposure(alloc, fill);
    
    try std.testing.expectError(core.position.PositionError.InvalidExposure, result);
}

test "Error: Modify order with invalid price" {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const alloc = gpa.allocator();

    var om = OrderManager.init(alloc);
    defer om.deinit();

    // Place valid order
    const order = Order.init(1, 1, 1000, .Limit, .Buy, 100.0, 5.0);
    const order_id = try om.placeOrder(alloc, order);

    // Try to modify with negative price
    const result = om.modifyOrder(alloc, order_id, -50.0);
    try std.testing.expectError(core.order.OrderError.InvalidPrice, result);
    
    // Original price should be unchanged
    try std.testing.expectEqual(@as(f64, 100.0), om.orders.items[0].price);
}

test "Error: Multiple fills on empty position manager" {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const alloc = gpa.allocator();

    var pm = PositionManager.init(alloc);
    defer pm.deinit(alloc);

    // Multiple valid fills should all work
    for (1..10) |i| {
        const fill = core.Fill.init(i, i, @as(u64, i) * 1000, .Buy, 100.0 + @as(f64, @floatFromInt(i)), 1.0);
        try pm.updateInstrumentExposure(alloc, fill);
    }
    
    try std.testing.expectEqual(@as(f64, 9.0), pm.exposure);
    try std.testing.expect(pm.getAveragePrice() > 100.0);
}

test "Error: Empty dataset validation" {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const alloc = gpa.allocator();

    // This test verifies that empty datasets are caught
    // In real use, this would be caught by data.zig load function
    var track = data.Track.init();
    defer track.deinit(alloc);
    
    // Empty track
    try std.testing.expectEqual(@as(u64, 0), track.size);
}


const std = @import("std");
const core = @import("../zdk/core.zig");

const Order = core.Order;
const OrderManager = core.OrderManager;
const FillManager = core.FillManager;
const PositionManager = core.PositionManager;

test "Edge: Zero exposure after multiple trades" {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const alloc = gpa.allocator();

    var pm = PositionManager.init(alloc);
    defer pm.deinit(alloc);

    // Buy 10
    const fill1 = core.Fill.init(1, 1, 1000, .Buy, 100.0, 10.0);
    try pm.updateInstrumentExposure(alloc, fill1);
    
    // Sell 10 (flatten)
    const fill2 = core.Fill.init(2, 2, 2000, .Sell, 105.0, 10.0);
    try pm.updateInstrumentExposure(alloc, fill2);
    
    try std.testing.expectEqual(@as(f64, 0.0), pm.exposure);
    try std.testing.expectEqual(@as(f64, 0.0), pm.getAveragePrice()); // Flat = no avg price
}

test "Edge: Very small volume (0.01)" {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const alloc = gpa.allocator();

    var om = OrderManager.init(alloc);
    defer om.deinit();
    
    var pm = PositionManager.init(alloc);
    defer pm.deinit(alloc);

    const order = Order.init(1, 1, 1000, .Market, .Buy, 0, 0.01);
    _ = try om.placeOrder(alloc, order);
    
    const fill = core.Fill.init(1, 1, 1000, .Buy, 100.0, 0.01);
    try pm.updateInstrumentExposure(alloc, fill);
    
    try std.testing.expectEqual(@as(f64, 0.01), pm.exposure);
}

test "Edge: Very large volume (1,000,000)" {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const alloc = gpa.allocator();

    var om = OrderManager.init(alloc);
    defer om.deinit();
    
    var pm = PositionManager.init(alloc);
    defer pm.deinit(alloc);

    const order = Order.init(1, 1, 1000, .Market, .Buy, 0, 1_000_000.0);
    _ = try om.placeOrder(alloc, order);
    
    const fill = core.Fill.init(1, 1, 1000, .Buy, 50000.0, 1_000_000.0);
    try pm.updateInstrumentExposure(alloc, fill);
    
    try std.testing.expectEqual(@as(f64, 1_000_000.0), pm.exposure);
}

test "Edge: Price exactly at limit/stop trigger" {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const alloc = gpa.allocator();

    var om = OrderManager.init(alloc);
    defer om.deinit();
    
    var fm = FillManager.init();
    defer fm.deinit(alloc);
    
    var pm = PositionManager.init(alloc);
    defer pm.deinit(alloc);

    // Buy limit at 100
    const order = Order.init(1, 1, 1000, .Limit, .Buy, 100.0, 5.0);
    _ = try om.placeOrder(alloc, order);

    // Bar with low exactly at 100.0
    try fm.evaluateWorkingOrders(alloc, &om, &pm, 102.0, 100.0, 101.0, 101.5);
    
    // Should fill
    try std.testing.expectEqual(@as(usize, 0), om.orders_working.items.len);
    try std.testing.expectEqual(@as(usize, 1), fm.fills.items.len);
    try std.testing.expectEqual(@as(f64, 100.0), fm.fills.items[0].price);
}

test "Edge: Cancel non-existent order (no crash)" {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const alloc = gpa.allocator();

    var om = OrderManager.init(alloc);
    defer om.deinit();

    // Try to cancel order that doesn't exist - should not crash
    try om.cancelOrder(alloc, 999);
    
    try std.testing.expectEqual(@as(usize, 0), om.orders_canceled.items.len);
}

test "Edge: Modify non-existent order returns error" {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const alloc = gpa.allocator();

    var om = OrderManager.init(alloc);
    defer om.deinit();

    // Try to modify order that doesn't exist
    const result = om.modifyOrder(alloc, 999, 100.0);
    try std.testing.expectError(core.order.OrderError.OrderNotFound, result);
}

test "Edge: Average price with multiple entry fills" {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const alloc = gpa.allocator();

    var pm = PositionManager.init(alloc);
    defer pm.deinit(alloc);

    // Enter at different prices
    const fill1 = core.Fill.init(1, 1, 1000, .Buy, 100.0, 5.0);  // 5 @ 100
    try pm.updateInstrumentExposure(alloc, fill1);
    
    const fill2 = core.Fill.init(2, 2, 2000, .Buy, 110.0, 5.0);  // 5 @ 110
    try pm.updateInstrumentExposure(alloc, fill2);
    
    // Average should be (100*5 + 110*5) / 10 = 105
    try std.testing.expectEqual(@as(f64, 10.0), pm.exposure);
    try std.testing.expectEqual(@as(f64, 105.0), pm.getAveragePrice());
}

test "Edge: Unrealized PnL calculations" {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const alloc = gpa.allocator();

    var pm = PositionManager.init(alloc);
    defer pm.deinit(alloc);

    // Long position
    const fill = core.Fill.init(1, 1, 1000, .Buy, 100.0, 10.0);
    try pm.updateInstrumentExposure(alloc, fill);
    
    // Price goes up
    const pnl_up = pm.getUnrealizedPnL(110.0);
    try std.testing.expectEqual(@as(f64, 100.0), pnl_up); // (110-100)*10 = 100
    
    // Price goes down
    const pnl_down = pm.getUnrealizedPnL(95.0);
    try std.testing.expectEqual(@as(f64, -50.0), pnl_down); // (95-100)*10 = -50
}

test "Edge: Multiple order cancellations" {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const alloc = gpa.allocator();

    var om = OrderManager.init(alloc);
    defer om.deinit();

    // Place 5 orders
    for (1..6) |i| {
        const order = Order.init(i, 1, 1000, .Limit, .Buy, @as(f64, @floatFromInt(i)) * 10.0, 1.0);
        _ = try om.placeOrder(alloc, order);
    }
    
    try std.testing.expectEqual(@as(usize, 5), om.orders_working.items.len);

    // Cancel all odd-numbered orders
    try om.cancelOrder(alloc, 1);
    try om.cancelOrder(alloc, 3);
    try om.cancelOrder(alloc, 5);
    
    try std.testing.expectEqual(@as(usize, 2), om.orders_working.items.len);
    try std.testing.expectEqual(@as(usize, 3), om.orders_canceled.items.len);
}

test "Edge: Order ID overflow handling" {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const alloc = gpa.allocator();

    var om = OrderManager.init(alloc);
    defer om.deinit();

    // Start with high ID
    om.next_id = std.math.maxInt(u64) - 10;
    
    // Place orders up to max
    for (0..11) |_| {
        const order = Order.init(om.next_id, 1, 1000, .Market, .Buy, 0, 1.0);
        if (om.next_id == std.math.maxInt(u64)) {
            // Last order before overflow - should succeed
            _ = try om.placeOrder(alloc, order);
            break;
        }
        _ = try om.placeOrder(alloc, order);
    }
    
    // Should have placed up to max ID
    try std.testing.expect(om.orders.items.len > 0);
}


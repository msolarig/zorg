const std = @import("std");
const core = @import("../zdk/core.zig");
const Order = core.Order;
const OrderManager = core.OrderManager;
const OrderDirection = core.OrderDirection;
const OrderType = core.OrderType;

test "Order.init creates order with correct values" {
    const order = Order.init(1, 100, 1735516800, .Market, .Buy, 150.50, 10.0);

    try std.testing.expectEqual(order.id, 1);
    try std.testing.expectEqual(order.iter, 100);
    try std.testing.expectEqual(order.timestamp, 1735516800);
    try std.testing.expectEqual(order.type, .Market);
    try std.testing.expectEqual(order.side, .Buy);
    try std.testing.expectEqual(order.price, 150.50);
    try std.testing.expectEqual(order.volume, 10.0);
}

test "OrderDirection enum values match C ABI" {
    try std.testing.expectEqual(@intFromEnum(OrderDirection.Buy), 1);
    try std.testing.expectEqual(@intFromEnum(OrderDirection.Sell), -1);
}

test "OrderType enum values match C ABI" {
    try std.testing.expectEqual(@intFromEnum(OrderType.Market), 0);
    try std.testing.expectEqual(@intFromEnum(OrderType.Limit), 1);
    try std.testing.expectEqual(@intFromEnum(OrderType.Stop), 2);
}

test "OrderManager.init creates empty manager" {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const alloc = gpa.allocator();

    var om = OrderManager.init(alloc);
    defer om.deinit();

    try std.testing.expectEqual(om.orders.items.len, 0);
    try std.testing.expectEqual(om.orders_working.items.len, 0);
    try std.testing.expectEqual(om.orders_canceled.items.len, 0);
    try std.testing.expectEqual(om.next_id, 1);
}

test "OrderManager.placeOrder adds order and tracks as working" {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const alloc = gpa.allocator();

    var om = OrderManager.init(alloc);
    defer om.deinit();

    const order1 = Order.init(1, 1, 1000, .Market, .Buy, 0, 100);
    const order2 = Order.init(2, 2, 2000, .Stop, .Sell, 95.0, 50);

    _ = try om.placeOrder(alloc, order1);
    _ = try om.placeOrder(alloc, order2);

    try std.testing.expectEqual(om.orders.items.len, 2);
    try std.testing.expectEqual(om.orders_working.items.len, 2);
    try std.testing.expectEqual(om.orders_working.items[0], 0);
    try std.testing.expectEqual(om.orders_working.items[1], 1);
}

test "OrderManager.deinit frees all memory" {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    const alloc = gpa.allocator();

    var om = OrderManager.init(alloc);
    _ = try om.placeOrder(alloc, Order.init(1, 1, 1000, .Market, .Buy, 0, 100));
    _ = try om.placeOrder(alloc, Order.init(2, 2, 2000, .Market, .Sell, 0, 50));

    om.deinit();

    const leak_status = gpa.deinit();
    try std.testing.expect(leak_status == .ok);
}

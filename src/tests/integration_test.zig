const std = @import("std");
const core = @import("../zdk/core.zig");
const controller = @import("../zdk/controller.zig");
const abi = @import("../zdk/abi.zig");

const Order = core.Order;
const OrderManager = core.OrderManager;
const FillManager = core.FillManager;
const PositionManager = core.PositionManager;

test "Integration: Full order lifecycle (place, fill, position update)" {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const alloc = gpa.allocator();

    var om = OrderManager.init(alloc);
    defer om.deinit();
    
    var fm = FillManager.init();
    defer fm.deinit(alloc);
    
    var pm = PositionManager.init(alloc);
    defer pm.deinit(alloc);

    // Place a buy stop order
    const order = Order.init(1, 1, 1000, .Stop, .Buy, 100.0, 10.0);
    const order_id = try om.placeOrder(alloc, order);
    try std.testing.expectEqual(@as(u64, 1), order_id);
    try std.testing.expectEqual(@as(usize, 1), om.orders_working.items.len);

    // Simulate bar that triggers the stop
    try fm.evaluateWorkingOrders(alloc, &om, &pm, 105.0, 95.0, 98.0, 102.0);

    // Order should be filled
    try std.testing.expectEqual(@as(usize, 0), om.orders_working.items.len);
    try std.testing.expectEqual(@as(usize, 1), fm.fills.items.len);
    
    // Position should be long 10
    try std.testing.expectEqual(@as(f64, 10.0), pm.exposure);
    try std.testing.expectEqual(@as(f64, 100.0), pm.getAveragePrice());
}

test "Integration: Multiple order types in sequence" {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const alloc = gpa.allocator();

    var om = OrderManager.init(alloc);
    defer om.deinit();
    
    var fm = FillManager.init();
    defer fm.deinit(alloc);
    
    var pm = PositionManager.init(alloc);
    defer pm.deinit(alloc);

    // 1. Market order entry
    const market_order = Order.init(1, 1, 1000, .Market, .Buy, 0, 5.0);
    _ = try om.placeOrder(alloc, market_order);
    try fm.evaluateWorkingOrders(alloc, &om, &pm, 100.0, 98.0, 99.0, 100.0);
    
    try std.testing.expectEqual(@as(f64, 5.0), pm.exposure);
    try std.testing.expectEqual(@as(usize, 1), fm.fills.items.len);

    // 2. Limit order to add to position
    const limit_order = Order.init(2, 2, 2000, .Limit, .Buy, 99.0, 3.0);
    _ = try om.placeOrder(alloc, limit_order);
    
    // Bar doesn't hit limit
    try fm.evaluateWorkingOrders(alloc, &om, &pm, 101.0, 100.0, 100.5, 100.5);
    try std.testing.expectEqual(@as(f64, 5.0), pm.exposure); // Unchanged
    try std.testing.expectEqual(@as(usize, 1), om.orders_working.items.len); // Still working
    
    // Bar hits limit
    try fm.evaluateWorkingOrders(alloc, &om, &pm, 100.0, 98.0, 99.5, 99.5);
    try std.testing.expectEqual(@as(f64, 8.0), pm.exposure); // Added 3
    try std.testing.expectEqual(@as(usize, 0), om.orders_working.items.len); // Filled

    // 3. Stop order to close position
    const stop_order = Order.init(3, 3, 3000, .Stop, .Sell, 95.0, 8.0);
    _ = try om.placeOrder(alloc, stop_order);
    
    // Bar triggers stop
    try fm.evaluateWorkingOrders(alloc, &om, &pm, 96.0, 94.0, 95.5, 95.0);
    
    try std.testing.expectEqual(@as(f64, 0.0), pm.exposure); // Flat
    try std.testing.expectEqual(@as(usize, 3), fm.fills.items.len); // 3 fills total
}

test "Integration: Order modification workflow" {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const alloc = gpa.allocator();

    var om = OrderManager.init(alloc);
    defer om.deinit();
    
    var fm = FillManager.init();
    defer fm.deinit(alloc);
    
    var pm = PositionManager.init(alloc);
    defer pm.deinit(alloc);

    // Place stop order
    const order = Order.init(1, 1, 1000, .Stop, .Buy, 100.0, 5.0);
    const order_id = try om.placeOrder(alloc, order);

    // Modify the price
    try om.modifyOrder(alloc, order_id, 105.0);
    try std.testing.expectEqual(@as(f64, 105.0), om.orders.items[0].price);

    // Bar at old price shouldn't fill
    try fm.evaluateWorkingOrders(alloc, &om, &pm, 102.0, 98.0, 100.0, 101.0);
    try std.testing.expectEqual(@as(usize, 1), om.orders_working.items.len);

    // Bar at new price should fill
    try fm.evaluateWorkingOrders(alloc, &om, &pm, 106.0, 104.0, 104.5, 105.5);
    try std.testing.expectEqual(@as(usize, 0), om.orders_working.items.len);
    try std.testing.expectEqual(@as(f64, 5.0), pm.exposure);
}

test "Integration: Position flip scenario" {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const alloc = gpa.allocator();

    var fm = FillManager.init();
    defer fm.deinit(alloc);
    
    var pm = PositionManager.init(alloc);
    defer pm.deinit(alloc);

    // Go long 10
    const fill1 = core.Fill.init(1, 1, 1000, .Buy, 100.0, 10.0);
    try pm.updateInstrumentExposure(alloc, fill1);
    try std.testing.expectEqual(@as(f64, 10.0), pm.exposure);

    // Flip to short 5 (sell 15 total)
    const fill2 = core.Fill.init(2, 2, 2000, .Sell, 105.0, 15.0);
    try pm.updateInstrumentExposure(alloc, fill2);
    try std.testing.expectEqual(@as(f64, -5.0), pm.exposure);
    try std.testing.expectEqual(@as(usize, 2), pm.positions_count); // 2 positions
}

test "Integration: Controller command execution" {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const alloc = gpa.allocator();

    var om = OrderManager.init(alloc);
    defer om.deinit();

    // Create command packet
    var commands: [3]abi.Command = undefined;
    var order_ids: [3]u64 = undefined;
    
    // Command 1: Place buy stop
    commands[0] = .{
        .command_type = .PlaceOrder,
        .payload = .{
            .order_request = .{
                .iter = 1,
                .timestamp = 1000,
                .order_type = .Stop,
                .direction = .Buy,
                .price = 100.0,
                .volume = 5.0,
            },
        },
    };
    
    // Command 2: Place sell limit
    commands[1] = .{
        .command_type = .PlaceOrder,
        .payload = .{
            .order_request = .{
                .iter = 1,
                .timestamp = 1000,
                .order_type = .Limit,
                .direction = .Sell,
                .price = 110.0,
                .volume = 5.0,
            },
        },
    };
    
    var packet = abi.Output.Packet{
        .count = 2,
        .commands = &commands,
        .returned_order_ids = &order_ids,
        .log_count = 0,
        .log_entries = undefined,
        .immediate_log_count = 0,
        .immediate_log_entries = undefined,
    };

    try controller.executeInstructionPacket(alloc, packet, &om);

    // Should have 2 working orders
    try std.testing.expectEqual(@as(usize, 2), om.orders_working.items.len);
    try std.testing.expectEqual(@as(u64, 1), order_ids[0]);
    try std.testing.expectEqual(@as(u64, 2), order_ids[1]);

    // Command 3: Cancel first order
    commands[0] = .{
        .command_type = .CancelOrder,
        .payload = .{
            .cancel_request = .{ .order_id = 1 },
        },
    };
    packet.count = 1;
    
    try controller.executeInstructionPacket(alloc, packet, &om);
    
    try std.testing.expectEqual(@as(usize, 1), om.orders_working.items.len);
    try std.testing.expectEqual(@as(usize, 1), om.orders_canceled.items.len);
}


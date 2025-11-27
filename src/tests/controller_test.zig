const std = @import("std");
const controller = @import("../zdk/controller.zig");
const abi = @import("../zdk/abi.zig");
const core = @import("../zdk/core.zig");

const OrderManager = core.OrderManager;

test "Controller: Place Market order" {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const alloc = gpa.allocator();

    var om = OrderManager.init(alloc);
    defer om.deinit();

    var commands: [1]abi.Command = undefined;
    var order_ids: [1]u64 = undefined;
    
    commands[0] = .{
        .command_type = .PlaceOrder,
        .payload = .{
            .order_request = .{
                .iter = 1,
                .timestamp = 1000,
                .order_type = .Market,
                .direction = .Buy,
                .price = 0, // Market orders don't use price
                .volume = 10.0,
            },
        },
    };
    
    const packet = abi.Output.Packet{
        .count = 1,
        .commands = &commands,
        .returned_order_ids = &order_ids,
        .log_count = 0,
        .log_entries = undefined,
        .immediate_log_count = 0,
        .immediate_log_entries = undefined,
    };

    try controller.executeInstructionPacket(alloc, packet, &om);
    
    try std.testing.expectEqual(@as(usize, 1), om.orders.items.len);
    try std.testing.expectEqual(@as(u64, 1), order_ids[0]);
    try std.testing.expectEqual(abi.OrderType.Market, om.orders.items[0].type);
}

test "Controller: Place Stop order" {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const alloc = gpa.allocator();

    var om = OrderManager.init(alloc);
    defer om.deinit();

    var commands: [1]abi.Command = undefined;
    var order_ids: [1]u64 = undefined;
    
    commands[0] = .{
        .command_type = .PlaceOrder,
        .payload = .{
            .order_request = .{
                .iter = 1,
                .timestamp = 1000,
                .order_type = .Stop,
                .direction = .Sell,
                .price = 95.0,
                .volume = 5.0,
            },
        },
    };
    
    const packet = abi.Output.Packet{
        .count = 1,
        .commands = &commands,
        .returned_order_ids = &order_ids,
        .log_count = 0,
        .log_entries = undefined,
        .immediate_log_count = 0,
        .immediate_log_entries = undefined,
    };

    try controller.executeInstructionPacket(alloc, packet, &om);
    
    try std.testing.expectEqual(@as(usize, 1), om.orders_working.items.len);
    try std.testing.expectEqual(abi.OrderType.Stop, om.orders.items[0].type);
    try std.testing.expectEqual(@as(f64, 95.0), om.orders.items[0].price);
}

test "Controller: Place Limit order" {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const alloc = gpa.allocator();

    var om = OrderManager.init(alloc);
    defer om.deinit();

    var commands: [1]abi.Command = undefined;
    var order_ids: [1]u64 = undefined;
    
    commands[0] = .{
        .command_type = .PlaceOrder,
        .payload = .{
            .order_request = .{
                .iter = 1,
                .timestamp = 1000,
                .order_type = .Limit,
                .direction = .Buy,
                .price = 99.0,
                .volume = 8.0,
            },
        },
    };
    
    const packet = abi.Output.Packet{
        .count = 1,
        .commands = &commands,
        .returned_order_ids = &order_ids,
        .log_count = 0,
        .log_entries = undefined,
        .immediate_log_count = 0,
        .immediate_log_entries = undefined,
    };

    try controller.executeInstructionPacket(alloc, packet, &om);
    
    try std.testing.expectEqual(@as(usize, 1), om.orders_working.items.len);
    try std.testing.expectEqual(abi.OrderType.Limit, om.orders.items[0].type);
    try std.testing.expectEqual(@as(f64, 99.0), om.orders.items[0].price);
}

test "Controller: Cancel order command" {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const alloc = gpa.allocator();

    var om = OrderManager.init(alloc);
    defer om.deinit();

    // Place order first
    const order = core.Order.init(1, 1, 1000, .Limit, .Buy, 100.0, 5.0);
    _ = try om.placeOrder(alloc, order);

    // Cancel via controller
    var commands: [1]abi.Command = undefined;
    commands[0] = .{
        .command_type = .CancelOrder,
        .payload = .{
            .cancel_request = .{ .order_id = 1 },
        },
    };
    
    const packet = abi.Output.Packet{
        .count = 1,
        .commands = &commands,
        .returned_order_ids = undefined,
        .log_count = 0,
        .log_entries = undefined,
        .immediate_log_count = 0,
        .immediate_log_entries = undefined,
    };

    try controller.executeInstructionPacket(alloc, packet, &om);
    
    try std.testing.expectEqual(@as(usize, 0), om.orders_working.items.len);
    try std.testing.expectEqual(@as(usize, 1), om.orders_canceled.items.len);
}

test "Controller: Modify order command" {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const alloc = gpa.allocator();

    var om = OrderManager.init(alloc);
    defer om.deinit();

    // Place order first
    const order = core.Order.init(1, 1, 1000, .Limit, .Buy, 100.0, 5.0);
    _ = try om.placeOrder(alloc, order);

    // Modify via controller
    var commands: [1]abi.Command = undefined;
    commands[0] = .{
        .command_type = .ModifyOrder,
        .payload = .{
            .modify_request = .{
                .order_id = 1,
                .new_price = 105.0,
            },
        },
    };
    
    const packet = abi.Output.Packet{
        .count = 1,
        .commands = &commands,
        .returned_order_ids = undefined,
        .log_count = 0,
        .log_entries = undefined,
        .immediate_log_count = 0,
        .immediate_log_entries = undefined,
    };

    try controller.executeInstructionPacket(alloc, packet, &om);
    
    try std.testing.expectEqual(@as(f64, 105.0), om.orders.items[0].price);
}

test "Controller: Invalid command data (zero volume)" {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const alloc = gpa.allocator();

    var om = OrderManager.init(alloc);
    defer om.deinit();

    var commands: [1]abi.Command = undefined;
    var order_ids: [1]u64 = undefined;
    
    commands[0] = .{
        .command_type = .PlaceOrder,
        .payload = .{
            .order_request = .{
                .iter = 1,
                .timestamp = 1000,
                .order_type = .Market,
                .direction = .Buy,
                .price = 0,
                .volume = 0.0, // Invalid!
            },
        },
    };
    
    const packet = abi.Output.Packet{
        .count = 1,
        .commands = &commands,
        .returned_order_ids = &order_ids,
        .log_count = 0,
        .log_entries = undefined,
        .immediate_log_count = 0,
        .immediate_log_entries = undefined,
    };

    const result = controller.executeInstructionPacket(alloc, packet, &om);
    try std.testing.expectError(controller.ControllerError.InvalidCommand, result);
}

test "Controller: Invalid command data (negative price for Stop)" {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const alloc = gpa.allocator();

    var om = OrderManager.init(alloc);
    defer om.deinit();

    var commands: [1]abi.Command = undefined;
    var order_ids: [1]u64 = undefined;
    
    commands[0] = .{
        .command_type = .PlaceOrder,
        .payload = .{
            .order_request = .{
                .iter = 1,
                .timestamp = 1000,
                .order_type = .Stop,
                .direction = .Buy,
                .price = -100.0, // Invalid!
                .volume = 5.0,
            },
        },
    };
    
    const packet = abi.Output.Packet{
        .count = 1,
        .commands = &commands,
        .returned_order_ids = &order_ids,
        .log_count = 0,
        .log_entries = undefined,
        .immediate_log_count = 0,
        .immediate_log_entries = undefined,
    };

    const result = controller.executeInstructionPacket(alloc, packet, &om);
    try std.testing.expectError(controller.ControllerError.InvalidCommand, result);
}

test "Controller: Batch command execution" {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const alloc = gpa.allocator();

    var om = OrderManager.init(alloc);
    defer om.deinit();

    var commands: [5]abi.Command = undefined;
    var order_ids: [5]u64 = undefined;
    
    // Place 3 orders
    for (0..3) |i| {
        commands[i] = .{
            .command_type = .PlaceOrder,
            .payload = .{
                .order_request = .{
                    .iter = @intCast(i + 1),
                    .timestamp = @intCast((i + 1) * 1000),
                    .order_type = .Limit,
                    .direction = .Buy,
                    .price = @as(f64, @floatFromInt(i)) * 10.0 + 90.0,
                    .volume = 1.0,
                },
            },
        };
    }
    
    const packet = abi.Output.Packet{
        .count = 3,
        .commands = &commands,
        .returned_order_ids = &order_ids,
        .log_count = 0,
        .log_entries = undefined,
        .immediate_log_count = 0,
        .immediate_log_entries = undefined,
    };

    try controller.executeInstructionPacket(alloc, packet, &om);
    
    try std.testing.expectEqual(@as(usize, 3), om.orders_working.items.len);
    try std.testing.expectEqual(@as(u64, 1), order_ids[0]);
    try std.testing.expectEqual(@as(u64, 2), order_ids[1]);
    try std.testing.expectEqual(@as(u64, 3), order_ids[2]);
}


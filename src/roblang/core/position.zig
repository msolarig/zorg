const std = @import("std");
const PositionABI = @import("../abi/position.zig").PositionABI;
const PositionEntryABI = @import("../abi/position.zig").PositionEntryABI;
const Order = @import("order.zig");
const OrderManager = @import("order.zig").OrderManager;

pub const PositionSide = Order.OrderDirection;

pub const Position = struct {
    side: PositionSide,
    price: f64,
    volume: f64,

    pub fn init(side: PositionSide, price: f64, volume: f64) Position {
        return Position{
            .side = side,
            .price = price,
            .volume = volume,
        };
    }
};

pub const PositionManager = struct {
    net_state: f64,
    positions: std.ArrayList(Position),
    abi_buffer: std.ArrayList(PositionEntryABI),
    abi: PositionABI,

    pub fn init() PositionManager {
        return PositionManager{
            .net_state = 0,
            .positions = .{},
            .abi_buffer = .{},
            .abi = .{ .ptr = @ptrFromInt(8), .count = 0 },
        };
    }

    pub fn evaluateWorkingOrders(self: *PositionManager, gpa: std.mem.Allocator, om: *OrderManager) !void {
        for (om.orders_working.items) |order_index| {
            const order = om.orders.items[order_index];

            switch (order.type) {
                .Market => try self.executeMarketOrder(gpa, order),
                .Stop => continue,
                .Limit => continue,
            }
        }
        om.orders_working.clearRetainingCapacity();
    }

    pub fn executeMarketOrder(self: *PositionManager, gpa: std.mem.Allocator, order: Order.Order) !void {
        const position = Position.init(order.side, order.price, order.volume);
        try self.positions.append(gpa, position);
        self.net_state += position.volume;
    }

    /// Convert internal list → ABI struct (pointer + count).
    pub fn toABI(self: *PositionManager, alloc: std.mem.Allocator) !PositionABI {
        // rebuild ABI buffer cleanly
        self.abi_buffer.clearRetainingCapacity();

        for (self.positions.items) |p| {
            try self.abi_buffer.append(alloc, .{
                .side = p.side,
                .price = p.price,
                .volume = p.volume,
            });
        }

        if (self.abi_buffer.items.len == 0)
            return PositionABI{ .ptr = @ptrFromInt(8), .count = 0 };

        return PositionABI{
            .ptr = self.abi_buffer.items.ptr,
            .count = @intCast(self.abi_buffer.items.len),
        };
    }

    pub fn deinit(self: *PositionManager, alloc: std.mem.Allocator) void {
        self.positions.deinit(alloc);
        self.abi_buffer.deinit(alloc);
    }
};

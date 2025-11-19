const std = @import("std");
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

    pub fn init() PositionManager {
        return PositionManager{
            .net_state = 0,
            .positions = .{},
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
    
    pub fn deinit(self: *PositionManager, alloc: std.mem.Allocator) void {
        self.positions.deinit(alloc);
    }
};

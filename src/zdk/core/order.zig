const std = @import("std");
const abi = @import("../abi.zig");

pub const OrderDirection = abi.OrderDirection;
pub const OrderType = abi.OrderType;

pub const Order = struct {
    iter: u64,
    timestamp: u64,
    type: OrderType,
    side: OrderDirection,
    price: f64,
    volume: f64,

    pub fn init(iter: u64, timestamp: u64, order_type: OrderType, side: OrderDirection, price: f64, volume: f64) Order {
        return Order{
            .iter = iter,
            .timestamp = timestamp,
            .type = order_type,
            .side = side,
            .price = price,
            .volume = volume,
        };
    }
};

pub const OrderManager = struct {
    orders: std.ArrayList(Order),
    orders_working: std.ArrayList(u32),
    orders_canceled: std.ArrayList(u32),

    pub fn init() OrderManager {
        return OrderManager{
            .orders = .{},
            .orders_working = .{},
            .orders_canceled = .{},
        };
    }

    pub fn placeOrder(self: *OrderManager, alloc: std.mem.Allocator, order: Order) !void {
        try self.orders.append(alloc, order);
        const idx: u32 = @intCast(self.orders.items.len - 1);
        try self.orders_working.append(alloc, idx);
    }

    /// Cancel does nothing meaningful yet — ABI has no ID.
    pub fn cancelOrder(self: *OrderManager, alloc: std.mem.Allocator, order_id: u64) !void {
        _ = self;
        _ = alloc;
        _ = order_id;

        // TODO: implement real cancel once ABI includes IDs
        return;
    }

    pub fn deinit(self: *OrderManager, alloc: std.mem.Allocator) void {
        self.orders.deinit(alloc);
        self.orders_working.deinit(alloc);
        self.orders_canceled.deinit(alloc);
    }
};

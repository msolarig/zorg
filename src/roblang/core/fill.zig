const std = @import("std");
const FillABI = @import("../abi/fill.zig").FillABI;
const FillEntryABI = @import("../abi/fill.zig").FillEntryABI;
const Order = @import("order.zig");
const OrderManager = @import("order.zig").OrderManager;

pub const FillSide = Order.OrderDirection;

pub const Fill = struct {
    iter: u64,
    timestamp: u64,
    side: FillSide,
    price: f64,
    volume: f64,

    pub fn init(iter: u64, timestamp: u64, side: FillSide, price: f64, volume: f64) Fill {
        return Fill{
            .iter =  iter,
            .timestamp = timestamp,
            .side = side,
            .price = price,
            .volume = volume,
        };
    }
};

pub const FillManager = struct {
    net_state: f64,
    fills: std.ArrayList(Fill),
    abi_buffer: std.ArrayList(FillEntryABI),
    abi: FillABI,

    pub fn init() FillManager {
        return FillManager{
            .net_state = 0,
            .fills = .{},
            .abi_buffer = .{},
            .abi = .{ .ptr = @ptrFromInt(8), .count = 0 },
        };
    }

    pub fn evaluateWorkingOrders(self: *FillManager, gpa: std.mem.Allocator, om: *OrderManager) !void {
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

    pub fn executeMarketOrder(self: *FillManager, gpa: std.mem.Allocator, order: Order.Order) !void {
        const fill = Fill.init(order.iter, order.timestamp, order.side, order.price, order.volume);
        try self.fills.append(gpa, fill);
        self.net_state += fill.volume;
    }

    /// Convert internal list → ABI struct (pointer + count).
    pub fn toABI(self: *FillManager, alloc: std.mem.Allocator) !FillABI {
        // rebuild ABI buffer cleanly
        self.abi_buffer.clearRetainingCapacity();

        for (self.fills.items) |p| {
            try self.abi_buffer.append(alloc, .{
                .iter = p.iter,
                .timestamp = p.timestamp,
                .side = p.side,
                .price = p.price,
                .volume = p.volume,
            });
        }

        if (self.abi_buffer.items.len == 0)
            return FillABI{ .ptr = @ptrFromInt(8), .count = 0 };

        return FillABI{
            .ptr = self.abi_buffer.items.ptr,
            .count = @intCast(self.abi_buffer.items.len),
        };
    }

    pub fn deinit(self: *FillManager, alloc: std.mem.Allocator) void {
        self.fills.deinit(alloc);
        self.abi_buffer.deinit(alloc);
    }
};

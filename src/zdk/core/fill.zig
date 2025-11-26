const std = @import("std");
const abi = @import("../abi.zig");
const Order = @import("order.zig");
const OrderManager = @import("order.zig").OrderManager;
const PositionManager = @import("position.zig").PositionManager;

pub const FillSide = Order.OrderDirection;

pub const Fill = struct {
    iter: u64,
    timestamp: u64,
    side: FillSide,
    price: f64,
    volume: f64,

    pub fn init(iter: u64, timestamp: u64, side: FillSide, price: f64, volume: f64) Fill {
        return Fill{
            .iter = iter,
            .timestamp = timestamp,
            .side = side,
            .price = price,
            .volume = volume,
        };
    }
};

pub const FillManager = struct {
    fills: std.ArrayList(Fill),
    abi_buffer: std.ArrayList(abi.FillEntryABI),
    abi: abi.FillABI,

    pub fn init() FillManager {
        return FillManager{
            .fills = .{},
            .abi_buffer = .{},
            .abi = .{ .ptr = @ptrFromInt(8), .count = 0 },
        };
    }

    pub fn evaluateWorkingOrders(self: *FillManager, gpa: std.mem.Allocator, om: *OrderManager, pm: *PositionManager) !void {
        for (om.orders_working.items) |order_index| {
            const order = om.orders.items[order_index];

            switch (order.type) {
                .Market => try self.executeMarketOrder(gpa, order, pm),
                .Stop => continue,
                .Limit => continue,
            }
        }
        om.orders_working.clearRetainingCapacity();
    }

    pub fn executeMarketOrder(self: *FillManager, gpa: std.mem.Allocator, order: Order.Order, pm: *PositionManager) !void {
        const fill = Fill.init(order.iter, order.timestamp, order.side, order.price, order.volume);
        try self.fills.append(gpa, fill);
        try pm.updateInstrumentExposure(gpa, fill);
    }

    pub fn toABI(self: *FillManager, alloc: std.mem.Allocator) !abi.FillABI {
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
            return abi.FillABI{ .ptr = @ptrFromInt(8), .count = 0 };

        return abi.FillABI{
            .ptr = self.abi_buffer.items.ptr,
            .count = @intCast(self.abi_buffer.items.len),
        };
    }

    pub fn deinit(self: *FillManager, alloc: std.mem.Allocator) void {
        self.fills.deinit(alloc);
        self.abi_buffer.deinit(alloc);
    }
};

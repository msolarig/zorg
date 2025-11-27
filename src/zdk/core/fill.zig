const std = @import("std");
const abi = @import("../abi.zig");
const Order = @import("order.zig");
const OrderManager = @import("order.zig").OrderManager;
const PositionManager = @import("position.zig").PositionManager;

pub const FillSide = Order.OrderDirection;

pub const FillError = error{
    InvalidPrice,
    InvalidVolume,
    InvalidBarData,
    InvalidExposure,
    NoActivePosition,
} || std.mem.Allocator.Error;

pub const Fill = struct {
    order_id: u64,
    iter: u64,
    timestamp: u64,
    side: FillSide,
    price: f64,
    volume: f64,

    pub fn init(order_id: u64, iter: u64, timestamp: u64, side: FillSide, price: f64, volume: f64) Fill {
        return Fill{
            .order_id = order_id,
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

    pub fn evaluateWorkingOrders(
        self: *FillManager,
        gpa: std.mem.Allocator,
        om: *OrderManager,
        pm: *PositionManager,
        bar_high: f64,
        bar_low: f64,
        bar_open: f64,
        bar_close: f64,
    ) FillError!void {
        // Validate bar data
        if (bar_high < bar_low or bar_open <= 0 or bar_close <= 0) {
            if (@import("builtin").is_test == false) {
                std.debug.print("Error: Invalid OHLC bar data (H:{d} L:{d} O:{d} C:{d})\n", .{bar_high, bar_low, bar_open, bar_close});
            }
            return FillError.InvalidBarData;
        }
        var i: usize = 0;
        while (i < om.orders_working.items.len) {
            const order_index = om.orders_working.items[i];
            const order = om.orders.items[order_index];

            var should_fill = false;
            var fill_price: f64 = 0;

            switch (order.type) {
                .Market => {
                    // Market orders fill at close price immediately
                    should_fill = true;
                    fill_price = bar_close;
                },
                .Stop => {
                    // Stop Buy: triggers when price goes ABOVE stop price
                    // Stop Sell: triggers when price goes BELOW stop price
                    if (order.side == .Buy) {
                        // Buy Stop: triggered if high >= stop price
                        if (bar_high >= order.price) {
                            should_fill = true;
                            // Fill at stop price or worse (open if gap through)
                            fill_price = if (bar_open > order.price) bar_open else order.price;
                        }
                    } else {
                        // Sell Stop: triggered if low <= stop price
                        if (bar_low <= order.price) {
                            should_fill = true;
                            // Fill at stop price or worse (open if gap through)
                            fill_price = if (bar_open < order.price) bar_open else order.price;
                        }
                    }
                },
                .Limit => {
                    // Limit Buy: fills when price goes AT OR BELOW limit price
                    // Limit Sell: fills when price goes AT OR ABOVE limit price
                    if (order.side == .Buy) {
                        // Buy Limit: triggered if low <= limit price
                        if (bar_low <= order.price) {
                            should_fill = true;
                            // Fill at limit price or better
                            fill_price = order.price;
                        }
                    } else {
                        // Sell Limit: triggered if high >= limit price
                        if (bar_high >= order.price) {
                            should_fill = true;
                            // Fill at limit price or better
                            fill_price = order.price;
                        }
                    }
                },
            }

            if (should_fill) {
                // Create fill at determined price
                const fill = Fill.init(order.id, order.iter, order.timestamp, order.side, fill_price, order.volume);
                try self.fills.append(gpa, fill);
                try pm.updateInstrumentExposure(gpa, fill);

                // Remove from working orders
                _ = om.working_lookup.remove(order.id);
                _ = om.orders_working.orderedRemove(i);
                // Don't increment i, since we removed current element
                continue;
            }

            i += 1;
        }
    }

    pub fn executeMarketOrder(self: *FillManager, gpa: std.mem.Allocator, order: Order.Order, pm: *PositionManager) FillError!void {
        const fill = Fill.init(order.id, order.iter, order.timestamp, order.side, order.price, order.volume);
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

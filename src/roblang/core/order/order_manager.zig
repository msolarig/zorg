const std = @import("std");
const Order = @import("order.zig").Order;

pub const OrderManager = struct {
    orders: std.ArrayList(Order),
    orders_working: std.ArrayList(u32),
    orders_canceled: std.ArrayList(u32),

    pub fn init() OrderManager {
        return OrderManager {
            .orders = .{},
            .orders_working = .{},
            .orders_canceled = .{}
        };
    }

    pub fn placeOrder(self: *OrderManager, alloc: std.mem.Allocator, order: Order) !void {
        var mut_order: Order = order;
        // if (valid order) { TODO: check order validity
            mut_order.status = .Working;
            try self.orders.append(alloc, mut_order);
            try self.orders_working.append(alloc, @intCast(self.orders.items.len));
        //}     
    }

    pub fn cancelOrder(self: *OrderManager, alloc: std.mem.Allocator, id: u32) !void {
        var i: usize = 0;
        while (i < self.orders_working.items.len) : (i += 1) {

            const order_index = self.orders_working.items[i]; // index into orders[]
            const order_ptr = &self.orders.items[order_index];

            if (order_ptr.id == id) {
                order_ptr.status = .Canceled;
                try self.orders_canceled.append(alloc, order_index);
                _ = self.orders_working.swapRemove(i);
                return;
            }
        }
        return error.OrderNotFound;
    }
};

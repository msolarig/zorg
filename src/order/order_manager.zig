const std = @import("std");
const Order = @import("order.zig").Order;

pub const OrderManager = struct {
  orders: std.ArrayList(Order),

  pub fn placeOrder(self: *OrderManager, order: Order) void {
    order.status = .Submitted;
    order.stauts = .Working; // immediately activating order for now.
    // (later make sure it meets all requirements before activating)
    self.orders.append(order);
  }
};

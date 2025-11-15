const std = @import("std");

pub const OrderType = enum(c_int) { Market, Limit, Stop };
pub const OrderSide = enum(c_int) { Buy, Sell };

pub const OrderRequest = extern struct {
    instrument: [*:0]const u8,
    side: OrderSide,
    order_type: OrderType,
    price: f64,
    volume: f64,
};

const OrderDirection = @import("../core/order.zig").OrderDirection;
const OrderType = @import("../core/order.zig").OrderType;
const OrderTimeInForce = @import("../core/order.zig").OrderTimeInForce;
const OrderTimeCondition = @import("../core/order.zig").OrderTimeCondition;
const OrderStatus = @import("../core/order.zig").OrderStatus;

pub const OrderRequest = extern struct {
    direction: OrderDirection,
    order_type: OrderType,
    price: f64,
    volume: f64,
};

pub const CancelRequest = extern struct {
    order_id: u64,
};

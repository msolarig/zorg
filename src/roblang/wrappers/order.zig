const OrderDirection = @import("../core/order/order.zig").OrderDirection;
const OrderType = @import("../core/order/order.zig").OrderType;
const OrderTimeInForce = @import("../core/order/order.zig").OrderTimeInForce;
const OrderTimeCondition = @import("../core/order/order.zig").OrderTimeCondition;
const OrderStatus = @import("../core/order/order.zig").OrderStatus;

pub const OrderRequest = extern struct {
    id: u32,
    instrument: [*:0]const u8,
    type: OrderType,
    side: OrderDirection,
    price: f64,
    volume: u64,
    time_in_force: OrderTimeInForce,
    time_condition: OrderTimeCondition,
    status: OrderStatus,
};

pub const OrderDirection = enum(c_int) { Buy, Sell };
pub const OrderType = enum(c_int) { Market, Stop, Limit };
pub const OrderTimeInForce = enum(c_int) { Day, GoodTillCancel };
pub const OrderTimeCondition = enum(c_int) { ImmediateOrCancel, FillOrKill };
pub const OrderStatus = enum(c_int) { Inactive, Submitted, Working, Filled, Canceled, Rejected, Expired };

pub const Order = struct {
    id: u32,
    instrument: [*:0]const u8,
    type: OrderType,
    side: OrderDirection,
    price: f64,
    volume: u64,
    time_in_force: OrderTimeInForce,
    time_condition: OrderTimeCondition,
    status: OrderStatus,

    pub fn init(id: u32, instrument: [*:0]const u8, order_type: OrderType, side: OrderDirection, price: f64, volume: u64, time_in_force: OrderTimeInForce, time_condition: OrderTimeCondition) Order {
        return Order{
            .id = id,
            .instrument = instrument,
            .type = order_type,
            .side = side,
            .price = price,
            .volume = volume,
            .time_in_force = time_in_force,
            .time_condition = time_condition,
            .status = .Inactive,
        };
    }
};

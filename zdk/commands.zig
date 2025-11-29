const types = @import("types.zig");

/// Command types for order management

pub const OrderRequest = extern struct {
    iter: u64,
    timestamp: u64,
    direction: types.OrderDirection,
    order_type: types.OrderType,
    price: f64,
    volume: f64,
};

pub const CancelRequest = extern struct {
    order_id: u64,
};

pub const ModifyRequest = extern struct {
    order_id: u64,
    new_price: f64,
};

pub const CommandType = enum(c_int) {
    PlaceOrder = 0,
    CancelOrder = 1,
    ModifyOrder = 2,
};

pub const CommandPayload = extern union {
    order_request: OrderRequest,
    cancel_request: CancelRequest,
    modify_request: ModifyRequest,
};

pub const Command = extern struct {
    command_type: CommandType,
    payload: CommandPayload,
};


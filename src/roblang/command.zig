const std = @import("std");
const OrderRequest = @import("order.zig").OrderRequest;

/// All possible commands an Auto can send to the engine.
pub const AutoCommandType = enum(c_int) {
    PlaceOrder,
    CancelOrder,
};

pub const CommandPayload = extern union {
    place_order: OrderRequest,
    cancel_order: extern struct {
        order_id: u64,
    },
};

pub const Command = extern struct {
    command_type: AutoCommandType,
    payload: CommandPayload,
};

/// Output value of each Auto iteration
pub const InstructionPacket = extern struct {
    count: u64,
    commands: [*]const Command,
};

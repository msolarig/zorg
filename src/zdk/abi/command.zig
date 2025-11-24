const std = @import("std");
const OrderRequest = @import("order.zig").OrderRequest;
const CancelRequest = @import("order.zig").CancelRequest;

pub const CommandType = enum(c_int) {
    PlaceOrder = 0,
    CancelOrder = 1,
};

pub const CommandPayload = extern union {
    place: OrderRequest,
    cancel: CancelRequest,
};

pub const Command = extern struct {
    command_type: CommandType,
    payload: CommandPayload,
};

pub const InstructionPacket = extern struct {
    count: u64,
    commands: [*]const Command,
};

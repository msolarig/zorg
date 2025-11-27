const std = @import("std");
const abi = @import("abi.zig");
const Order = @import("core/order.zig").Order;
const OrderManager = @import("core/order.zig").OrderManager;
const OrderError = @import("core/order.zig").OrderError;

pub const ControllerError = error{
    InvalidCommand,
    OrderExecutionFailed,
} || OrderError || std.mem.Allocator.Error;

pub fn executeInstructionPacket(gpa: std.mem.Allocator, packet: abi.Output.Packet, om: *OrderManager) ControllerError!void {
    var order_idx: usize = 0;
    for (0..packet.count) |instruction_index| {
        const command: abi.Command = packet.commands[instruction_index];

        switch (command.command_type) {
            .PlaceOrder => {
                const id = om.next_id;
                om.next_id += 1;
                
                const req = command.payload.order_request;
                
                // Validate request
                    if (req.volume <= 0 or !std.math.isFinite(req.volume)) {
                        if (@import("builtin").is_test == false) {
                            std.debug.print("Error: Invalid order volume in request: {d}\n", .{req.volume});
                        }
                        return ControllerError.InvalidCommand;
                    }
                
                const price = switch (req.order_type) {
                    .Market => 0, // Market orders don't need price
                    .Stop, .Limit => blk: {
                        if (req.price <= 0 or !std.math.isFinite(req.price)) {
                            if (@import("builtin").is_test == false) {
                                std.debug.print("Error: Invalid order price in request: {d}\n", .{req.price});
                            }
                            return ControllerError.InvalidCommand;
                        }
                        break :blk req.price;
                    },
                };
                
                const order = Order.init(
                    id,
                    req.iter,
                    req.timestamp,
                    req.order_type,
                    req.direction,
                    price,
                    req.volume,
                );
                
                _ = om.placeOrder(gpa, order) catch |err| {
                    std.debug.print("Error: Failed to place {s} order: {s}\n", .{@tagName(req.order_type), @errorName(err)});
                    return ControllerError.OrderExecutionFailed;
                };
                
                packet.returned_order_ids[order_idx] = id;
                order_idx += 1;
            },

            .CancelOrder => {
                const id = command.payload.cancel_request.order_id;
                try om.cancelOrder(gpa, id);
            },

            .ModifyOrder => {
                const modify_req = command.payload.modify_request;
                try om.modifyOrder(gpa, modify_req.order_id, modify_req.new_price);
            },
        }
    }
}

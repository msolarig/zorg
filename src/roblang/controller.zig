const std = @import("std");
const Command = @import("abi/command.zig").Command;
const Packet = @import("abi/command.zig").InstructionPacket;
const Order = @import("core/order.zig").Order;
const OrderManager = @import("core/order.zig").OrderManager;

pub fn ExecuteInstructionPacket(alloc: std.mem.Allocator, ip: Packet, om: *OrderManager) !void {
    for (0..ip.count) |instruction_index| {
        const command: Command = ip.commands[instruction_index];

        switch (command.command_type) {
            .PlaceOrder => {
                const req = command.payload.place;
                const order = Order.init(
                    req.order_type,
                    req.direction,
                    req.price,
                    req.volume,
                );
                try om.placeOrder(alloc, order);
            },

            .CancelOrder => {
                const id = command.payload.cancel.order_id;
                try om.cancelOrder(alloc, id);
            },
        }
    }
}

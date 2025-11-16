const std = @import("std");
const Command = @import("wrappers/command.zig").Command;
const Packet = @import("wrappers/command.zig").InstructionPacket;
const Order = @import("core/order/order.zig").Order;
const OrderManager = @import("core/order/order_manager.zig").OrderManager;

pub fn ExecuteInstructionPacket(alloc: std.mem.Allocator, ip: Packet,  om: *OrderManager) !void {
    for (0..ip.count) |instruction_index| {
        const command: Command = ip.commands[instruction_index];

        switch (command.command_type) {

            // Place an Order (.Submitted -> .Working)
            .PlaceOrder => {
                const cmd = command.payload.place_order;
                const order = Order.init(cmd.id, cmd.instrument, cmd.type, cmd.side, cmd.price, cmd.volume, cmd.time_in_force, cmd.time_condition);
                try om.placeOrder(alloc, order); // No validation yet, TODO
            },

            // Cancel an Order (.Working -> Canceled) 
            .CancelOrder => {
                const id: u32 = command.payload.cancel_order.order_id;
                try om.cancelOrder(alloc, id);
            }
        } 
    }
}

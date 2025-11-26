const std = @import("std");
const abi = @import("abi.zig");
const Order = @import("core/order.zig").Order;
const OrderManager = @import("core/order.zig").OrderManager;

pub fn executeInstructionPacket(gpa: std.mem.Allocator, packet: abi.Output.Packet, om: *OrderManager) !void {
    for (0..packet.count) |instruction_index| {
        const command: abi.Command = packet.commands[instruction_index];

        switch (command.command_type) {
            .PlaceOrder => {
                switch (command.payload.order_request.order_type) {
                    .Market => {
                        const req = command.payload.order_request;
                        const order = Order.init(
                            req.iter,
                            req.timestamp,
                            req.order_type,
                            req.direction,
                            0,
                            req.volume,
                        );
                        try om.placeOrder(gpa, order);
                    },

                    .Stop => {
                        const req = command.payload.order_request;
                        const order = Order.init(
                            req.iter,
                            req.timestamp,
                            req.order_type,
                            req.direction,
                            req.price,
                            req.volume,
                        );
                        try om.placeOrder(gpa, order);
                    },

                    .Limit => {
                        return;
                    },
                }
            },

            .CancelOrder => {
                const id = command.payload.cancel_request.order_id;
                try om.cancelOrder(gpa, id);
            },
        }
    }
}

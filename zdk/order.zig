const io = @import("io.zig");
const commands = @import("commands.zig");

/// Order submission helpers

pub const Order = struct {
    pub fn buyMarket(input: *const io.Input.Packet, output: *io.Output.Packet, volume: f64) u64 {
        const idx = output.count;
        output.submitOrder(.{
            .iter = input.iter,
            .timestamp = input.trail.ts[0],
            .direction = .Buy,
            .order_type = .Market,
            .price = 0,
            .volume = volume,
        });
        return output.returned_order_ids[idx];
    }

    pub fn sellMarket(input: *const io.Input.Packet, output: *io.Output.Packet, volume: f64) u64 {
        const idx = output.count;
        output.submitOrder(.{
            .iter = input.iter,
            .timestamp = input.trail.ts[0],
            .direction = .Sell,
            .order_type = .Market,
            .price = 0,
            .volume = volume,
        });
        return output.returned_order_ids[idx];
    }

    pub fn buyStop(input: *const io.Input.Packet, output: *io.Output.Packet, price: f64, volume: f64) u64 {
        const idx = output.count;
        output.submitOrder(.{
            .iter = input.iter,
            .timestamp = input.trail.ts[0],
            .direction = .Buy,
            .order_type = .Stop,
            .price = price,
            .volume = volume,
        });
        return output.returned_order_ids[idx];
    }

    pub fn sellStop(input: *const io.Input.Packet, output: *io.Output.Packet, price: f64, volume: f64) u64 {
        const idx = output.count;
        output.submitOrder(.{
            .iter = input.iter,
            .timestamp = input.trail.ts[0],
            .direction = .Sell,
            .order_type = .Stop,
            .price = price,
            .volume = volume,
        });
        return output.returned_order_ids[idx];
    }

    pub fn buyLimit(input: *const io.Input.Packet, output: *io.Output.Packet, price: f64, volume: f64) u64 {
        const idx = output.count;
        output.submitOrder(.{
            .iter = input.iter,
            .timestamp = input.trail.ts[0],
            .direction = .Buy,
            .order_type = .Limit,
            .price = price,
            .volume = volume,
        });
        return output.returned_order_ids[idx];
    }

    pub fn sellLimit(input: *const io.Input.Packet, output: *io.Output.Packet, price: f64, volume: f64) u64 {
        const idx = output.count;
        output.submitOrder(.{
            .iter = input.iter,
            .timestamp = input.trail.ts[0],
            .direction = .Sell,
            .order_type = .Limit,
            .price = price,
            .volume = volume,
        });
        return output.returned_order_ids[idx];
    }

    /// Modify the price of an existing working order
    pub fn modify(output: *io.Output.Packet, order_id: u64, new_price: f64) void {
        output.modifyOrder(order_id, new_price);
    }
};


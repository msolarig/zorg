const abi = @import("abi.zig");
const commands = @import("commands.zig");
const types = @import("types.zig");

/// Input/Output namespaces for auto communication

pub const Input = struct {
    pub const Packet = extern struct {
        iter: u64,
        trail: *const abi.TrailABI,
        account: *const abi.AccountABI,
        exposure: f64,
        average_price: f64,
    };
};

pub const Output = struct {
    pub const Packet = extern struct {
        count: u64,
        commands: [*]commands.Command,
        returned_order_ids: [*]u64,
        log_count: u64,
        log_entries: [*]types.LogEntry,
        immediate_log_count: u64,
        immediate_log_entries: [*]types.LogEntry,

        pub fn submitOrder(self: *Packet, request: commands.OrderRequest) void {
            self.commands[self.count] = commands.Command{
                .command_type = .PlaceOrder,
                .payload = .{ .order_request = request },
            };
            self.count += 1;
        }

        pub fn cancelOrder(self: *Packet, order_id: u64) void {
            self.commands[self.count] = commands.Command{
                .command_type = .CancelOrder,
                .payload = .{ .cancel_request = .{ .order_id = order_id } },
            };
            self.count += 1;
        }

        pub fn modifyOrder(self: *Packet, order_id: u64, new_price: f64) void {
            self.commands[self.count] = commands.Command{
                .command_type = .ModifyOrder,
                .payload = .{ .modify_request = .{ .order_id = order_id, .new_price = new_price } },
            };
            self.count += 1;
        }

        pub fn addLog(self: *Packet, level: types.LogLevel, message: []const u8) void {
            var entry = &self.log_entries[self.log_count];
            entry.level = level;
            entry.length = @min(message.len, 255);
            @memcpy(entry.message[0..entry.length], message[0..entry.length]);
            self.log_count += 1;
        }

        pub fn addImmediateLog(self: *Packet, level: types.LogLevel, message: []const u8) void {
            var entry = &self.immediate_log_entries[self.immediate_log_count];
            entry.level = level;
            entry.length = @min(message.len, 255);
            @memcpy(entry.message[0..entry.length], message[0..entry.length]);
            self.immediate_log_count += 1;
        }
    };
};


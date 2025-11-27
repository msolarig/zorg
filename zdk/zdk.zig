const std = @import("std");

/// ZDK (Zorg Development Kit) ABI version
/// Format: Major * 1_000_000 + Minor * 1_000 + Patch
/// Example: 1.0.0 = 1_000_000
pub const ZDK_VERSION: u32 = 1_000; // 0.1.0 (format: major * 1M + minor * 1K + patch)

pub const OrderDirection = enum(c_int) { Buy = 1, Sell = -1 };
pub const OrderType = enum(c_int) { Market = 0, Limit = 1, Stop = 2 };

pub const TrailABI = extern struct {
    ts: [*]const u64,
    op: [*]const f64,
    hi: [*]const f64,
    lo: [*]const f64,
    cl: [*]const f64,
    vo: [*]const u64,
};

pub const AccountABI = extern struct {
    balance: f64,
};

pub const FillEntryABI = extern struct {
    iter: u64,
    timestamp: u64,
    side: OrderDirection,
    price: f64,
    volume: f64,
};

pub const FillABI = extern struct {
    ptr: [*]const FillEntryABI,
    count: u64,
};

pub const OrderRequest = extern struct {
    iter: u64,
    timestamp: u64,
    direction: OrderDirection,
    order_type: OrderType,
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

// Logging types
pub const LogLevel = enum(c_int) {
    Debug = 0,
    Info = 1,
    Warn = 2,
    Error = 3,
};

pub const LogEntry = extern struct {
    level: LogLevel,
    message: [256]u8,
    length: u32,
};

// Input namespace
pub const Input = struct {
    pub const Packet = extern struct {
        iter: u64,
        trail: *const TrailABI,
        account: *const AccountABI,
        exposure: f64,
        average_price: f64,
    };
};

// Output namespace
pub const Output = struct {
    pub const Packet = extern struct {
        count: u64,
        commands: [*]Command,
        returned_order_ids: [*]u64,
        log_count: u64,
        log_entries: [*]LogEntry,
        immediate_log_count: u64,
        immediate_log_entries: [*]LogEntry,

        pub fn submitOrder(self: *Packet, request: OrderRequest) void {
            self.commands[self.count] = Command{
                .command_type = .PlaceOrder,
                .payload = .{ .order_request = request },
            };
            self.count += 1;
        }

        pub fn cancelOrder(self: *Packet, order_id: u64) void {
            self.commands[self.count] = Command{
                .command_type = .CancelOrder,
                .payload = .{ .cancel_request = .{ .order_id = order_id } },
            };
            self.count += 1;
        }

        pub fn modifyOrder(self: *Packet, order_id: u64, new_price: f64) void {
            self.commands[self.count] = Command{
                .command_type = .ModifyOrder,
                .payload = .{ .modify_request = .{ .order_id = order_id, .new_price = new_price } },
            };
            self.count += 1;
        }

        pub fn addLog(self: *Packet, level: LogLevel, message: []const u8) void {
            var entry = &self.log_entries[self.log_count];
            entry.level = level;
            entry.length = @min(message.len, 255);
            @memcpy(entry.message[0..entry.length], message[0..entry.length]);
            self.log_count += 1;
        }

        pub fn addImmediateLog(self: *Packet, level: LogLevel, message: []const u8) void {
            var entry = &self.immediate_log_entries[self.immediate_log_count];
            entry.level = level;
            entry.length = @min(message.len, 255);
            @memcpy(entry.message[0..entry.length], message[0..entry.length]);
            self.immediate_log_count += 1;
        }
    };
};

// Order namespace for order submission wrappers
pub const Order = struct {
    pub fn buyMarket(input: *const Input.Packet, output: *Output.Packet, volume: f64) u64 {
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

    pub fn sellMarket(input: *const Input.Packet, output: *Output.Packet, volume: f64) u64 {
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

    pub fn buyStop(input: *const Input.Packet, output: *Output.Packet, price: f64, volume: f64) u64 {
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

    pub fn sellStop(input: *const Input.Packet, output: *Output.Packet, price: f64, volume: f64) u64 {
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

    pub fn buyLimit(input: *const Input.Packet, output: *Output.Packet, price: f64, volume: f64) u64 {
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

    pub fn sellLimit(input: *const Input.Packet, output: *Output.Packet, price: f64, volume: f64) u64 {
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
    pub fn modify(output: *Output.Packet, order_id: u64, new_price: f64) void {
        output.modifyOrder(order_id, new_price);
    }
};

pub const ALF = *const fn (
    input: *const Input.Packet,
    output: *Output.Packet,
    arf: ?*anyopaque,
) callconv(.c) void;

pub const ADF = *const fn () callconv(.c) void;

pub const ArfInitFn = *const fn (arf: *anyopaque) callconv(.c) void;

pub const ABI = extern struct {
    version: u32,
    name: [*:0]const u8,
    alf: ALF,
    adf: ADF,
    arf_size: usize,
    arf_init: ?ArfInitFn,
};

pub const GetABIFn = *const fn () callconv(.c) *const ABI;
pub const ENTRY_SYMBOL = "getABI";

// Logging utilities
pub const Log = struct {
    /// Buffered logging - collected and written after backtest (fast, no I/O)
    pub const buffered = struct {
        pub fn debug(input: *const Input.Packet, output: *Output.Packet, comptime fmt: []const u8, args: anytype) void {
            var buf: [256]u8 = undefined;
            const user_msg = std.fmt.bufPrint(&buf, fmt, args) catch "LOG_ERROR: Message too long";
            var full_buf: [256]u8 = undefined;
            const msg = std.fmt.bufPrint(&full_buf, "[ {d:0>5} : {d} ] {s}", .{input.iter, input.trail.ts[0], user_msg}) catch user_msg;
            output.addLog(.Debug, msg);
        }

        pub fn info(input: *const Input.Packet, output: *Output.Packet, comptime fmt: []const u8, args: anytype) void {
            var buf: [256]u8 = undefined;
            const user_msg = std.fmt.bufPrint(&buf, fmt, args) catch "LOG_ERROR: Message too long";
            var full_buf: [256]u8 = undefined;
            const msg = std.fmt.bufPrint(&full_buf, "[ {d:0>5} : {d} ] {s}", .{input.iter, input.trail.ts[0], user_msg}) catch user_msg;
            output.addLog(.Info, msg);
        }

        pub fn warn(input: *const Input.Packet, output: *Output.Packet, comptime fmt: []const u8, args: anytype) void {
            var buf: [256]u8 = undefined;
            const user_msg = std.fmt.bufPrint(&buf, fmt, args) catch "LOG_ERROR: Message too long";
            var full_buf: [256]u8 = undefined;
            const msg = std.fmt.bufPrint(&full_buf, "[ {d:0>5} : {d} ] {s}", .{input.iter, input.trail.ts[0], user_msg}) catch user_msg;
            output.addLog(.Warn, msg);
        }

        pub fn err(input: *const Input.Packet, output: *Output.Packet, comptime fmt: []const u8, args: anytype) void {
            var buf: [256]u8 = undefined;
            const user_msg = std.fmt.bufPrint(&buf, fmt, args) catch "LOG_ERROR: Message too long";
            var full_buf: [256]u8 = undefined;
            const msg = std.fmt.bufPrint(&full_buf, "[ {d:0>5} : {d} ] {s}", .{input.iter, input.trail.ts[0], user_msg}) catch user_msg;
            output.addLog(.Error, msg);
        }
    };

    /// Immediate logging - buffers in separate section for critical messages (no stdout to avoid TUI corruption)
    pub const immediate = struct {
        pub fn debug(input: *const Input.Packet, output: *Output.Packet, comptime fmt: []const u8, args: anytype) void {
            var buf: [256]u8 = undefined;
            const user_msg = std.fmt.bufPrint(&buf, fmt, args) catch "LOG_ERROR: Message too long";
            var full_buf: [256]u8 = undefined;
            const msg = std.fmt.bufPrint(&full_buf, "[ {d:0>5} : {d} ] {s}", .{input.iter, input.trail.ts[0], user_msg}) catch user_msg;
            output.addImmediateLog(.Debug, msg);
        }

        pub fn info(input: *const Input.Packet, output: *Output.Packet, comptime fmt: []const u8, args: anytype) void {
            var buf: [256]u8 = undefined;
            const user_msg = std.fmt.bufPrint(&buf, fmt, args) catch "LOG_ERROR: Message too long";
            var full_buf: [256]u8 = undefined;
            const msg = std.fmt.bufPrint(&full_buf, "[ {d:0>5} : {d} ] {s}", .{input.iter, input.trail.ts[0], user_msg}) catch user_msg;
            output.addImmediateLog(.Info, msg);
        }

        pub fn warn(input: *const Input.Packet, output: *Output.Packet, comptime fmt: []const u8, args: anytype) void {
            var buf: [256]u8 = undefined;
            const user_msg = std.fmt.bufPrint(&buf, fmt, args) catch "LOG_ERROR: Message too long";
            var full_buf: [256]u8 = undefined;
            const msg = std.fmt.bufPrint(&full_buf, "[ {d:0>5} : {d} ] {s}", .{input.iter, input.trail.ts[0], user_msg}) catch user_msg;
            output.addImmediateLog(.Warn, msg);
        }

        pub fn err(input: *const Input.Packet, output: *Output.Packet, comptime fmt: []const u8, args: anytype) void {
            var buf: [256]u8 = undefined;
            const user_msg = std.fmt.bufPrint(&buf, fmt, args) catch "LOG_ERROR: Message too long";
            var full_buf: [256]u8 = undefined;
            const msg = std.fmt.bufPrint(&full_buf, "[ {d:0>5} : {d} ] {s}", .{input.iter, input.trail.ts[0], user_msg}) catch user_msg;
            output.addImmediateLog(.Error, msg);
        }
    };
};

// Time utilities
pub const Time = struct {
    /// Time of day representation (hours, minutes, seconds)
    pub const TimeOfDay = struct {
        hour: u8,
        minute: u8,
        second: u8,

        /// Create TimeOfDay from hours, minutes, seconds
        pub fn init(hour: u8, minute: u8, second: u8) TimeOfDay {
            return .{ .hour = hour, .minute = minute, .second = second };
        }

        /// Convert to total seconds since midnight
        pub fn toSeconds(self: TimeOfDay) u32 {
            return @as(u32, self.hour) * 3600 + @as(u32, self.minute) * 60 + @as(u32, self.second);
        }

        /// Check if this time is between start and end (inclusive)
        pub fn isBetween(self: TimeOfDay, start: TimeOfDay, end: TimeOfDay) bool {
            const self_secs = self.toSeconds();
            const start_secs = start.toSeconds();
            const end_secs = end.toSeconds();
            return self_secs >= start_secs and self_secs <= end_secs;
        }

        /// Check if this time is after another time
        pub fn isAfter(self: TimeOfDay, other: TimeOfDay) bool {
            return self.toSeconds() > other.toSeconds();
        }

        /// Check if this time is before another time
        pub fn isBefore(self: TimeOfDay, other: TimeOfDay) bool {
            return self.toSeconds() < other.toSeconds();
        }
    };

    /// Date representation
    pub const Date = struct {
        year: u16,
        month: u8,
        day: u8,
    };

    /// DateTime representation
    pub const DateTime = struct {
        date: Date,
        time: TimeOfDay,
    };

    /// Extract time of day from Unix timestamp (UTC)
    pub fn getTimeOfDay(timestamp: u64) TimeOfDay {
        const seconds_in_day = timestamp % 86400;
        const hour: u8 = @intCast(seconds_in_day / 3600);
        const minute: u8 = @intCast((seconds_in_day % 3600) / 60);
        const second: u8 = @intCast(seconds_in_day % 60);
        return TimeOfDay.init(hour, minute, second);
    }

    /// Extract date from Unix timestamp (UTC)
    pub fn getDate(timestamp: u64) Date {
        const days_since_epoch = timestamp / 86400;
        var year: u16 = 1970;
        var remaining_days = days_since_epoch;

        // Calculate year
        while (true) {
            const days_in_year: u64 = if (isLeapYear(year)) 366 else 365;
            if (remaining_days < days_in_year) break;
            remaining_days -= days_in_year;
            year += 1;
        }

        // Calculate month and day
        const days_in_months = if (isLeapYear(year))
            [_]u8{ 31, 29, 31, 30, 31, 30, 31, 31, 30, 31, 30, 31 }
        else
            [_]u8{ 31, 28, 31, 30, 31, 30, 31, 31, 30, 31, 30, 31 };

        var month: u8 = 1;
        for (days_in_months) |days| {
            if (remaining_days < days) break;
            remaining_days -= days;
            month += 1;
        }

        const day: u8 = @intCast(remaining_days + 1);
        return .{ .year = year, .month = month, .day = day };
    }

    /// Get full DateTime from Unix timestamp (UTC)
    pub fn getDateTime(timestamp: u64) DateTime {
        return .{
            .date = getDate(timestamp),
            .time = getTimeOfDay(timestamp),
        };
    }

    /// Check if day changed between two timestamps
    pub fn isDayChange(prev_timestamp: u64, curr_timestamp: u64) bool {
        const prev_day = prev_timestamp / 86400;
        const curr_day = curr_timestamp / 86400;
        return curr_day != prev_day;
    }

    /// Check if it's a new week
    pub fn isWeekChange(prev_timestamp: u64, curr_timestamp: u64) bool {
        const prev_week = prev_timestamp / (86400 * 7);
        const curr_week = curr_timestamp / (86400 * 7);
        return curr_week != prev_week;
    }

    /// Helper: Check if year is leap year
    fn isLeapYear(year: u16) bool {
        return (year % 4 == 0 and year % 100 != 0) or (year % 400 == 0);
    }

    /// Get day of week (0 = Thursday, 1 = Friday, ..., 6 = Wednesday)
    /// Unix epoch started on Thursday, Jan 1, 1970
    pub fn getDayOfWeek(timestamp: u64) u8 {
        const days_since_epoch = timestamp / 86400;
        return @intCast((days_since_epoch + 4) % 7);
    }
};


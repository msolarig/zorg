const std = @import("std");
const io = @import("io.zig");
const types = @import("types.zig");

/// Logging utilities

pub const Log = struct {
    /// Buffered logging - collected and written after backtest (fast, no I/O)
    pub const buffered = struct {
        pub fn debug(input: *const io.Input.Packet, output: *io.Output.Packet, comptime fmt: []const u8, args: anytype) void {
            var buf: [256]u8 = undefined;
            const user_msg = std.fmt.bufPrint(&buf, fmt, args) catch "LOG_ERROR: Message too long";
            var full_buf: [256]u8 = undefined;
            const msg = std.fmt.bufPrint(&full_buf, "[ {d:0>5} : {d} ] {s}", .{input.iter, input.trail.ts[0], user_msg}) catch user_msg;
            output.addLog(.Debug, msg);
        }

        pub fn info(input: *const io.Input.Packet, output: *io.Output.Packet, comptime fmt: []const u8, args: anytype) void {
            var buf: [256]u8 = undefined;
            const user_msg = std.fmt.bufPrint(&buf, fmt, args) catch "LOG_ERROR: Message too long";
            var full_buf: [256]u8 = undefined;
            const msg = std.fmt.bufPrint(&full_buf, "[ {d:0>5} : {d} ] {s}", .{input.iter, input.trail.ts[0], user_msg}) catch user_msg;
            output.addLog(.Info, msg);
        }

        pub fn warn(input: *const io.Input.Packet, output: *io.Output.Packet, comptime fmt: []const u8, args: anytype) void {
            var buf: [256]u8 = undefined;
            const user_msg = std.fmt.bufPrint(&buf, fmt, args) catch "LOG_ERROR: Message too long";
            var full_buf: [256]u8 = undefined;
            const msg = std.fmt.bufPrint(&full_buf, "[ {d:0>5} : {d} ] {s}", .{input.iter, input.trail.ts[0], user_msg}) catch user_msg;
            output.addLog(.Warn, msg);
        }

        pub fn err(input: *const io.Input.Packet, output: *io.Output.Packet, comptime fmt: []const u8, args: anytype) void {
            var buf: [256]u8 = undefined;
            const user_msg = std.fmt.bufPrint(&buf, fmt, args) catch "LOG_ERROR: Message too long";
            var full_buf: [256]u8 = undefined;
            const msg = std.fmt.bufPrint(&full_buf, "[ {d:0>5} : {d} ] {s}", .{input.iter, input.trail.ts[0], user_msg}) catch user_msg;
            output.addLog(.Error, msg);
        }
    };

    /// Immediate logging - buffers in separate section for critical messages (no stdout to avoid TUI corruption)
    pub const immediate = struct {
        pub fn debug(input: *const io.Input.Packet, output: *io.Output.Packet, comptime fmt: []const u8, args: anytype) void {
            var buf: [256]u8 = undefined;
            const user_msg = std.fmt.bufPrint(&buf, fmt, args) catch "LOG_ERROR: Message too long";
            var full_buf: [256]u8 = undefined;
            const msg = std.fmt.bufPrint(&full_buf, "[ {d:0>5} : {d} ] {s}", .{input.iter, input.trail.ts[0], user_msg}) catch user_msg;
            output.addImmediateLog(.Debug, msg);
        }

        pub fn info(input: *const io.Input.Packet, output: *io.Output.Packet, comptime fmt: []const u8, args: anytype) void {
            var buf: [256]u8 = undefined;
            const user_msg = std.fmt.bufPrint(&buf, fmt, args) catch "LOG_ERROR: Message too long";
            var full_buf: [256]u8 = undefined;
            const msg = std.fmt.bufPrint(&full_buf, "[ {d:0>5} : {d} ] {s}", .{input.iter, input.trail.ts[0], user_msg}) catch user_msg;
            output.addImmediateLog(.Info, msg);
        }

        pub fn warn(input: *const io.Input.Packet, output: *io.Output.Packet, comptime fmt: []const u8, args: anytype) void {
            var buf: [256]u8 = undefined;
            const user_msg = std.fmt.bufPrint(&buf, fmt, args) catch "LOG_ERROR: Message too long";
            var full_buf: [256]u8 = undefined;
            const msg = std.fmt.bufPrint(&full_buf, "[ {d:0>5} : {d} ] {s}", .{input.iter, input.trail.ts[0], user_msg}) catch user_msg;
            output.addImmediateLog(.Warn, msg);
        }

        pub fn err(input: *const io.Input.Packet, output: *io.Output.Packet, comptime fmt: []const u8, args: anytype) void {
            var buf: [256]u8 = undefined;
            const user_msg = std.fmt.bufPrint(&buf, fmt, args) catch "LOG_ERROR: Message too long";
            var full_buf: [256]u8 = undefined;
            const msg = std.fmt.bufPrint(&full_buf, "[ {d:0>5} : {d} ] {s}", .{input.iter, input.trail.ts[0], user_msg}) catch user_msg;
            output.addImmediateLog(.Error, msg);
        }
    };
};


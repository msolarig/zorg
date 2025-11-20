const std = @import("std");

// Re-export types so the engine can access them
pub const TrailABI = @import("trail.zig").TrailABI;
pub const AccountABI = @import("account.zig").AccountABI;
pub const PositionABI = @import("position.zig").PositionABI;

// Auto IO
pub const Inputs = @import("inputs.zig").AutoInputs;
pub const InstructionPacket = @import("command.zig").InstructionPacket;

// Function pointer types
pub const AutoLogicFn = *const fn (
    inputs: *const Inputs,
    packet: *InstructionPacket,
) callconv(.c) void;

pub const AutoDeinitFn = *const fn () callconv(.c) void;

/// ABI root struct
pub const AutoABI = extern struct {
    name: [*:0]const u8,
    desc: [*:0]const u8,
    logic: AutoLogicFn,
    deinit: AutoDeinitFn,
};

pub const GetAutoABIFn = *const fn () callconv(.c) *const AutoABI;
pub const ENTRY_SYMBOL = "getAutoABI";

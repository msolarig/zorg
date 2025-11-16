const std = @import("std");

// Re-export types so the engine can access them
pub const TrailABI = @import("wrappers/trail.zig").TrailABI;
pub const AccountABI = @import("wrappers/account.zig").AccountABI;
pub const PositionABI = @import("wrappers/position.zig").PositionABI;

// Inputs and commands
pub const Inputs = @import("wrappers/inputs.zig").AutoInputs;
pub const InstructionPacket = @import("wrappers/command.zig").InstructionPacket;

// Function pointer types
pub const AutoLogicFn = *const fn (
    iter_index: u64,
    inputs: *const Inputs,
) callconv(.c) InstructionPacket;

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

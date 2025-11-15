const std = @import("std");
const abi = @import("abi.zig");

/// Auto Export Function
pub export fn getAutoABI() callconv(.c) *const abi.AutoABI {
    const NAME: [*:0]const u8 = "TEST_AUTO";
    const DESC: [*:0]const u8 = "TEST_AUTO_DESCRIPTION";

    const ABI = abi.AutoABI{
        .name = NAME,
        .desc = DESC,
        .logic = autoLogicFunction,
        .deinit = deinit,
    };
    return &ABI;
}

// ----------------------------------------------------------------------
// Custom strategy parameters
// ----------------------------------------------------------------------
const minimum_required_data_points: u64 = 2;

// ----------------------------------------------------------------------
// Main logic function (AUTO → ENGINE)
// ----------------------------------------------------------------------
fn autoLogicFunction(iter: u64, inputs: abi.Inputs) callconv(.c) abi.InstructionPacket {

    // Example: print something
    std.debug.print("  AUTO LOGIC {d}, CLOSE: {d}\n", .{iter, inputs.trail.cl[0]});

    const EMPTY_COMMANDS = [_]abi.Command{};

    // Return empty command set
    return abi.InstructionPacket{
        .count = 0,
        .commands = &EMPTY_COMMANDS,
    };
}

// ----------------------------------------------------------------------
// Deinitializer
// ----------------------------------------------------------------------
fn deinit() callconv(.c) void {
    return;
}

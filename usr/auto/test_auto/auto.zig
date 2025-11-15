const std = @import("std");
const abi = @import("abi.zig");

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

    if (iter >= minimum_required_data_points) {
        const op0 = inputs.trail.op[0];
        const cl0 = inputs.trail.cl[0];

        const op1 = inputs.trail.op[1];
        const cl1 = inputs.trail.cl[1];

        const prev_bearish = (cl1 < op1);
        const curr_bullish = (cl0 > op0);
        const engulfs = (op0 <= cl1) and (cl0 >= op1);

        if (prev_bearish and curr_bullish and engulfs) {
            std.debug.print(
                "  LONG INITIATED @ iter {d} | close={d:.2}\n",
                .{ iter, cl0 }
            );
        }
    }

    // No commands generated → return empty packet
    const EMPTY: [0]abi.Command = .{};
    return abi.InstructionPacket{
        .count = 0,
        .commands = &EMPTY,
    };
}


// ----------------------------------------------------------------------
// Deinitializer
// ----------------------------------------------------------------------
fn deinit() callconv(.c) void {
    return;
}

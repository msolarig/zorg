const std = @import("std");
const abi = @import("abi.zig");

// ----------------------------------------------------------------------------------------------------------

const NAME: [*:0]const u8 = "RobSA-TEP";
const DESC: [*:0]const u8 = "ROBERT SAMPLE AUTO _n1_: A Simple TA Engulfing Algorithm ";

// ----------------------------------------------------------------------------------------------------------

// ----------------------------------------------------------------------------------------------------------
//
//
//          --|--   The famous (but probably not so useful) Bullish Engulfing
//    --|-- |   |
//    | O | | O |   This sample will show you the basic functionality & interaction with ROBlang:
//    | < | | > |       - How to access historic prices with the trail
//    | C | | C |       - How to create & append commands to the packet
//    --|-- |   |
//          --|--
//
// ----------------------------------------------------------------------------------------------------------

// CUSTOM GLOBAL VARIABLES ^ Functions ----------------------------------------------------------------------

const min_required_points: u8 = 2; // Avoid index-out-of-range errors!


inline fn submitBuyMkt(pkt: *abi.InstructionPacket, price: f64) void {
    const cmd: abi.Command = .{
        .type = .PlaceOrder,
        .payload = .{
            .place = .{
                .direction = .Buy,
                .order_type = .Market,
                .price = price,
                .volume = 1,
            },
        },
    };
    pkt.add(cmd);
}

// ----------------------------------------------------------------------------------------------------------

// AUTO LOGIC FUNCTION (ALF) --------------------------------------------------------------------------------

fn ALF(inputs: abi.Inputs, packet: *abi.InstructionPacket) callconv(.c) void {

    const op0: f64 = inputs.trail.op[0];
    const cl0: f64 = inputs.trail.cl[0];
    const op1: f64 = inputs.trail.op[1];
    const cl1: f64 = inputs.trail.cl[1];

    const prev_red = cl1 < op1;
    const cur_green = cl0 > op0;
    const cur_engulf = op0 < op1 and cl0 > cl1;

    if (inputs.iter > min_required_points)
        if (prev_red and cur_green and cur_engulf)
            submitBuyMkt(packet, op0);
}

// ----------------------------------------------------------------------------------------------------------

// AUTO DEINITIALIZATION FUNCTION (ADF) ---------------------------------------------------------------------

fn ADF() callconv(.c) void {
    //Include any DA'd memory
}

// ----------------------------------------------------------------------------------------------------------

// AUTO HANDLE EXPORT - DO NOT MODIFY -----------------------------------------------------------------------

var GLOBAL_ABI: abi.AutoABI = .{ .name = NAME, .desc = DESC, .logic = ALF, .deinit = ADF };
pub export fn getAutoABI() callconv(.c) *const abi.AutoABI {
    return &GLOBAL_ABI;
}

// ----------------------------------------------------------------------------------------------------------

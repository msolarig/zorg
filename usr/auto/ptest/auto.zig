const std = @import("std");
const abi = @import("abi.zig");

const NAME: [*:0]const u8 = "RobSA-TEP";
const DESC: [*:0]const u8 = "ROBERT SAMPLE AUTO _n1_: A Simple TA Engulfing Algorithm ";

// CUSTOM GLOBAL VARIABLES ^ Functions ----------------------------------------------------------------------

const min_required_points: u8 = 2;

inline fn submitBuyMkt(in: abi.Inputs, pkt: *abi.InstructionPacket, price: f64) void {
    const cmd: abi.Command = .{
        .type = .PlaceOrder,
        .payload = .{
            .place = .{
                .iter = in.iter,
                .timestamp = in.trail.ts[0],
                .direction = .Buy,
                .order_type = .Market,
                .price = price,
                .volume = 1,
            },
        },
    };
    pkt.add(cmd);
}

inline fn submitSellMkt(in: abi.Inputs, pkt: *abi.InstructionPacket, price: f64) void {
    const cmd: abi.Command = .{
        .type = .PlaceOrder,
        .payload = .{
            .place = .{
                .iter = in.iter,
                .timestamp = in.trail.ts[0],
                .direction = .Sell,
                .order_type = .Market,
                .price = price,
                .volume = 1,
            },
        },
    };
    pkt.add(cmd);
}

// AUTO LOGIC FUNCTION (ALF) --------------------------------------------------------------------------------

fn ALF(inputs: abi.Inputs, packet: *abi.InstructionPacket) callconv(.c) void {
    const op0: f64 = inputs.trail.op[0];
    const cl0: f64 = inputs.trail.cl[0];
    const op1: f64 = inputs.trail.op[1];
    const cl1: f64 = inputs.trail.cl[1];

    const prev_red = cl1 < op1;
    const cur_green = cl0 > op0;
    const cur_engulf = op0 < op1 and cl0 > cl1;

    if (inputs.iter > min_required_points) {
        if (prev_red and cur_green and cur_engulf) {
            if (inputs.exposure.* > 0) submitSellMkt(inputs, packet, op0);
            submitBuyMkt(inputs, packet, op0);
        }
    }
}

// AUTO DEINITIALIZATION FUNCTION (ADF) ---------------------------------------------------------------------

fn ADF() callconv(.c) void {}

// AUTO HANDLE EXPORT - DO NOT MODIFY -----------------------------------------------------------------------

var GLOBAL_ABI: abi.AutoABI = .{ .name = NAME, .desc = DESC, .logic = ALF, .deinit = ADF };
pub export fn getAutoABI() callconv(.c) *const abi.AutoABI {
    return &GLOBAL_ABI;
}

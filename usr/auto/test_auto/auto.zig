const std = @import("std");
const abi = @import("abi.zig");

// ----------------------------------------------------------------------------------------------------------

const NAME: [*:0]const u8 = "TEST_AUTO";
const DESC: [*:0]const u8 = "TEST_AUTO_DESCRIPTION";
var GLOBAL_ABI: abi.AutoABI = .{ .name = NAME, .desc = DESC, .logic = autoLogicFunction, .deinit = deinit,};
pub export fn getAutoABI() callconv(.c) *const abi.AutoABI { return &GLOBAL_ABI; }

// ----------------------------------------------------------------------------------------------------------
//
//
//          --|--   SAMPLE AUTO: The famous (but probably not so useful) Bullish Engulfing
//    --|-- |   |   
//    |   | |   |   This system serves to show the basic functionality of ROBlang. It'll teach you:
//    |   | |   |       - How to access historic prices with the trail
//    |   | |   |       - How to create & append commands to the packet
//    --|-- |   |
//          --|--
//
//
// CUSTOM GLOBAL VARIABLES ----------------------------------------------------------------------------------

var COMMAND_BUFFER: [128]abi.Command = undefined; // this needs to be passed by the caller, TODO
const min_required_points: u8 = 2; // Avoid index-out-of-range errors!

// ----------------------------------------------------------------------------------------------------------
//
// AUTO LOGIC DEFINITION ------------------------------------------------------------------------------------
//
fn autoLogicFunction(iter: u64, inputs: abi.Inputs) callconv(.c) abi.InstructionPacket {

    var pkt = abi.InstructionPacket.init(&COMMAND_BUFFER); // this has to be passed by the caller too, TODO
    
    const SubmitBuyMktOrder = res: { // Generic mkt order submission code block
        const AnyGivenBuyMktOrder: abi.Command = .{
            .type = abi.CommandType.PlaceOrder,
            .payload = .{
                .place = .{
                    .direction = .Buy,
                    .order_type = .Market,
                    .price = inputs.trail.cl[0],
                    .volume = 1,
                },
            },
        };
        break :res pkt.add(AnyGivenBuyMktOrder);
    };

    const op0: f64 = inputs.trail.op[0];
    const cl0: f64 = inputs.trail.cl[0];
    const op1: f64 = inputs.trail.op[1];
    const cl1: f64 = inputs.trail.cl[1];

    const prev_red = cl1 < op1;
    const cur_green = cl0 > op0;
    const cur_engulf = op0 < op1 and cl0 > cl1;

    if (iter > min_required_points)
        if (prev_red and cur_green and cur_engulf)
            SubmitBuyMktOrder;

    return pkt;
}

// ----------------------------------------------------------------------------------------------------------
//
// AUTO DEINITIALIZATION-------------------------------------------------------------------------------------

fn deinit() callconv(.c) void {
    //Include any DA'd memory
}

// ----------------------------------------------------------------------------------------------------------

const zdk = @import("zdk.zig");

// AUTO DETAILS ----------------------------------------------------------------------------------*

const NAME: [*:0]const u8 = "Bullish Engulfing";
const DESC: [*:0]const u8 = "Detects bullish engulfing patterns and places orders";

// PRIVATE VARIABLES -----------------------------------------------------------------------------*

const MIN_REQUIRED_POINTS: u8 = 2;

// AUTO LOGIC FUNCTION ---------------------------------------------------------------------------*

fn logic(input: *const zdk.Input.Packet, output: *zdk.Output.Packet) callconv(.c) void {
    const op0 = input.trail.op[0];
    const cl0 = input.trail.cl[0];
    const op1 = input.trail.op[1];
    const cl1 = input.trail.cl[1];

    const prev_red = cl1 < op1;
    const curr_green = cl0 > op0;
    const curr_engulfs = op0 < op1 and cl0 > cl1;

    if (input.iter > MIN_REQUIRED_POINTS) {
        if (prev_red and curr_green and curr_engulfs) {
            zdk.Order.buyMarket(input, output, 10);
        }
    }
}

// Auto Deinitialization Function ----------------------------------------------------------------*

fn deinit() callconv(.c) void {}

// ABI Handle - DO NOT MODIFY --------------------------------------------------------------------*

var abi = zdk.ABI{
    .version = zdk.VERSION,
    .name = NAME,
    .desc = DESC,
    .logic = logic,
    .deinit = deinit,
};

export fn getABI() callconv(.c) *const zdk.ABI {
    return &abi;
}

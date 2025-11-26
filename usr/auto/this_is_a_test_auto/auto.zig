const zdk = @import("zdk.zig");

// AUTO DETAILS ----------------------------------------------------------------------------------*
// TODO: Update these with your auto's name and description

const NAME: [*:0]const u8 = "My Strategy";
const DESC: [*:0]const u8 = "A basic trading strategy";

// PRIVATE VARIABLES -----------------------------------------------------------------------------*
// TODO: Add any private variables your strategy needs

// AUTO LOGIC FUNCTION ---------------------------------------------------------------------------*
// This function is called on every iteration of the backtest
// input: Contains current iteration data (trail, account, exposure)
// output: Use this to submit orders

fn logic(input: *const zdk.Input.Packet, output: *zdk.Output.Packet) callconv(.c) void {
    // TODO: Implement your trading logic here
    
    // Example: Access current price data
    const current_close = input.trail.cl[0];
    const previous_close = input.trail.cl[1];
    
    // Example: Access account balance (uncomment if needed)
    // const balance = input.account.balance;
    
    // Example: Simple strategy - buy if price went up
    if (current_close > previous_close) {
        // Buy 10 units at market price
        zdk.Order.buyMarket(input, output, 10.0);
    }
    
    // Available order functions:
    // - zdk.Order.buyMarket(input, output, volume)
    // - zdk.Order.sellMarket(input, output, volume)
    // - zdk.Order.buyLimit(input, output, price, volume)
    // - zdk.Order.sellLimit(input, output, price, volume)
    // - zdk.Order.buyStop(input, output, price, volume)
    // - zdk.Order.sellStop(input, output, price, volume)
}

// Auto Deinitialization Function ----------------------------------------------------------------*
// Called when the auto is unloaded (cleanup if needed)

fn deinit() callconv(.c) void {
    // TODO: Add any cleanup code here if needed
}

// ABI Handle - DO NOT MODIFY --------------------------------------------------------------------*
// This structure connects your auto to the engine

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


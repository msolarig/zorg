const zdk = @import("zdk.zig");

// AUTO DETAILS ----------------------------------------------------------------------------------*
// TODO: Update this with your auto's name

const NAME: [*:0]const u8 = "My Auto";
const DESC: [*:0]const u8 = ""; // Deprecated - need to take out before v1

// PRIVATE VARIABLES -----------------------------------------------------------------------------*
// TODO: Add any private variables your auto needs. For local functions, logic, or indicators, 
// it is recommended to create separate modules within the auto dir/ and import them here.

// AUTO LOGIC FUNCTION ---------------------------------------------------------------------------*
// This function is called on every iteration of the backtest
// input: Contains current iteration data (trail, account, exposure)
// output: Use this to submit orders

fn logic(input: *const zdk.Input.Packet, output: *zdk.Output.Packet) callconv(.c) void {
    // TODO: Implement your algorothmic logic here
    
    // Example: Access current price data.
    // You can access timestamp, OHLCV data.
    // Just reference (ts, op, hi, lo, cl, vo)
    const current_close = input.trail.cl[0];
    const previous_close = input.trail.cl[1];
    
    // Example: Access account balance (uncomment if needed)
    // const balance = input.account.balance;
    
    // Example: Simple strategy - buy if price went up
    if (current_close > previous_close) {
        // Buy 10 units at market price
        zdk.Order.buyMarket(input, output, 10.0);
    }
    
    // Currently available order functions:
    // - zdk.Order.buyMarket(input, output, volume)
    // - zdk.Order.sellMarket(input, output, volume)
    // - zdk.Order.buyLimit(input, output, price, volume)
    // - zdk.Order.sellLimit(input, output, price, volume)
    // - zdk.Order.buyStop(input, output, price, volume)
    // - zdk.Order.sellStop(input, output, price, volume)
    
    // For more information on ZDK version & functionality, 
    // read the zdk.zig module attached in the auto directory.
}

// Auto Deinitialization Function ----------------------------------------------------------------*
// Called when the auto is unloaded

fn deinit() callconv(.c) void {
    // TODO: Add cleanup for any dynamically allocated memory.
}

// ABI Handle - DO NOT MODIFY --------------------------------------------------------------------*
// This structure connects the auto to the engine

var abi = zdk.ABI{
    .version = zdk.VERSION,
    .name = NAME,
    .desc = DESC, // Deprecated
    .logic = logic,
    .deinit = deinit,
};

export fn getABI() callconv(.c) *const zdk.ABI {
    return &abi;
}


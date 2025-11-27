const zdk = @import("zdk.zig");

// AUTO DETAILS ----------------------------------------------------------------------------------*

const NAME: [*:0]const u8 = "Bullish Engulfing";

// AUTO RUNTIME FIELDS (ARF) ---------------------------------------------------------------------*

const ARF = struct {
    order_id: ?u64 = null,
    stop_id: ?u64 = null,
    trade_count: u64 = 0,
    prev_timestamp: u64 = 0,
    breakeven_set: bool = false,
};

fn initARF(arf_ptr: *anyopaque) callconv(.c) void {
    const arf: *ARF = @ptrCast(@alignCast(arf_ptr));
    arf.* = ARF{};
}

// AUTO LOGIC FUNCTION (ALF) --------------------------------------------------------------------*

const MIN_REQUIRED_POINTS: u8 = 2;

// Define trading session times
const SESSION_START = zdk.Time.TimeOfDay.init(9, 30, 0);   // 9:30 AM
const SESSION_END = zdk.Time.TimeOfDay.init(16, 0, 0);     // 4:00 PM

fn alf(input: *const zdk.Input.Packet, output: *zdk.Output.Packet, arf_ptr: ?*anyopaque) callconv(.c) void {
    const arf: *ARF = @ptrCast(@alignCast(arf_ptr.?));
    
    const timestamp = input.trail.ts[0];
    const current_time = zdk.Time.getTimeOfDay(timestamp);
    
    // Check for day change - reset daily state
    if (arf.prev_timestamp > 0 and zdk.Time.isDayChange(arf.prev_timestamp, timestamp)) {
        zdk.Log.buffered.info(output, "Day change detected - resetting state", .{});
        arf.order_id = null;
        arf.stop_id = null;
        arf.breakeven_set = false;
    }
    arf.prev_timestamp = timestamp;
    
    // Only trade during session hours
    if (!current_time.isBetween(SESSION_START, SESSION_END)) {
        return;
    }
    
    // Position queries (available every bar)
    const is_long = input.exposure > 0;
    const is_short = input.exposure < 0;
    const is_flat = input.exposure == 0;
    const entry_price = input.average_price;
    
    // User can calculate unrealized P&L if needed:
    // const current_price = input.trail.cl[0];
    // const unrealized_pnl = if (is_long) 
    //     (current_price - entry_price) * input.exposure
    // else if (is_short)
    //     (entry_price - current_price) * (-input.exposure)
    // else 0;
    
    _ = is_short; // Example: could check if is_short before placing buys
    _ = entry_price; // Example: could use for breakeven calculation
    
    const op0 = input.trail.op[0];
    const cl0 = input.trail.cl[0];
    const op1 = input.trail.op[1];
    const cl1 = input.trail.cl[1];

    const prev_red = cl1 < op1;
    const curr_green = cl0 > op0;
    const curr_engulfs = op0 < op1 and cl0 > cl1;

    if (input.iter > MIN_REQUIRED_POINTS) {
        // Entry logic
        if (prev_red and curr_green and curr_engulfs and arf.order_id == null and is_flat) {
            arf.order_id = zdk.Order.buyMarket(input, output, 10);
            arf.stop_id = zdk.Order.sellStop(input, output, cl0 - 5.0, 10);
            arf.trade_count += 1;
            
            // Buffered logging (collected and written after backtest)
            zdk.Log.buffered.info(output, "Bullish engulfing detected - entering long", .{});
            zdk.Log.buffered.debug(output, "Entry: {d:.2} Stop: {d:.2}", .{cl0, cl0 - 5.0});
        }
        
        // Auto-breakeven example: Move stop to entry after 10 points profit
        if (is_long and !arf.breakeven_set) {
            const current_price = input.trail.cl[0];
            const unrealized_pnl = (current_price - entry_price) * input.exposure;
            
            if (unrealized_pnl >= 10.0 and arf.stop_id != null) {
                // Modify stop to breakeven price
                zdk.Order.modify(output, arf.stop_id.?, entry_price);
                arf.breakeven_set = true;
                
                // Immediate logging (prints right away - for critical messages)
                zdk.Log.immediate.info(output, "BREAKEVEN SET at {d:.2}", .{entry_price});
            }
        }
    }
}

// AUTO DEINITIALIZATION FUNCTION (ADF) ----------------------------------------------------------*

fn adf() callconv(.c) void {}

// ABI Handle - DO NOT MODIFY --------------------------------------------------------------------*

var abi = zdk.ABI{
    .version = zdk.VERSION,
    .name = NAME,
    .alf = alf,
    .adf = adf,
    .arf_size = @sizeOf(ARF),
    .arf_init = initARF,
};

export fn getABI() callconv(.c) *const zdk.ABI {
    return &abi;
}

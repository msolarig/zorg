const zdk = @import("zdk.zig");

// AUTO DETAILS ----------------------------------------------------------------------------------*

const NAME: [*:0]const u8 = "Daily_Breakout";

// AUTO RUNTIME FIELDS (ARF) ---------------------------------------------------------------------*

const ARF = struct {
    // Order tracking
    entry_order_id: ?u64 = null,
    stop_order_id: ?u64 = null,
    
    // State flags
    has_position_today: bool = false,
    
    // Timestamp tracking
    prev_timestamp: u64 = 0,
};

fn initARF(arf_ptr: *anyopaque) callconv(.c) void {
    const arf: *ARF = @ptrCast(@alignCast(arf_ptr));
    arf.* = ARF{};
}

// AUTO LOGIC FUNCTION (ALF) --------------------------------------------------------------------*

// Auto Parameters
const LOOKBACK_PERIOD: usize = 20;  // 20-day high/low
const POSITION_SIZE: f64 = 1.0;
const STOP_LOSS_PERCENT: f64 = 0.02;  // 2% stop loss

fn alf(input: *const zdk.Input.Packet, output: *zdk.Output.Packet, arf_ptr: ?*anyopaque) callconv(.c) void {
    const arf: *ARF = @ptrCast(@alignCast(arf_ptr.?));
    
    const timestamp = input.trail.ts[0];
    const current_price = input.trail.cl[0];
    const current_high = input.trail.hi[0];
    const current_low = input.trail.lo[0];
    
    // Position state
    const is_long = input.exposure > 0;
    const is_short = input.exposure < 0;
    const is_flat = input.exposure == 0;
    
    // ======================================================================================
    // DAY CHANGE DETECTION - Reset daily state
    // ======================================================================================
    if (arf.prev_timestamp > 0 and zdk.Time.isDayChange(arf.prev_timestamp, timestamp)) {
        arf.has_position_today = false;
    }
    arf.prev_timestamp = timestamp;
    
    // ======================================================================================
    // CALCULATE LOOKBACK HIGH/LOW
    // ======================================================================================
    var lookback_high: f64 = input.trail.hi[1];  // Start from previous bar
    var lookback_low: f64 = input.trail.lo[1];
    
    var i: usize = 1;
    while (i < LOOKBACK_PERIOD and i < 10) : (i += 1) {  // Limited by trail size
        if (input.trail.hi[i] > lookback_high) {
            lookback_high = input.trail.hi[i];
        }
        if (input.trail.lo[i] < lookback_low) {
            lookback_low = input.trail.lo[i];
        }
    }
    
    zdk.Log.buffered.debug(input, output, "Lookback High: {d:.2} Low: {d:.2} Current: {d:.2}", 
        .{lookback_high, lookback_low, current_price});
    
    // ======================================================================================
    // ENTRY LOGIC - Breakout of lookback range
    // ======================================================================================
    if (is_flat and !arf.has_position_today) {
        // Bullish breakout - close above 20-day high
        if (current_high > lookback_high) {
            const stop_price = current_price * (1.0 - STOP_LOSS_PERCENT);
            
            arf.entry_order_id = zdk.Order.buyMarket(input, output, POSITION_SIZE);
            arf.stop_order_id = zdk.Order.sellStop(input, output, stop_price, POSITION_SIZE);
            arf.has_position_today = true;
            
            zdk.Log.immediate.info(input, output, "LONG ENTRY @ {d:.2} | Stop: {d:.2}", 
                .{current_price, stop_price});
            zdk.Log.buffered.info(input, output, "Breakout above {d:.2}", .{lookback_high});
        }
        // Bearish breakout - close below 20-day low
        else if (current_low < lookback_low) {
            const stop_price = current_price * (1.0 + STOP_LOSS_PERCENT);
            
            arf.entry_order_id = zdk.Order.sellMarket(input, output, POSITION_SIZE);
            arf.stop_order_id = zdk.Order.buyStop(input, output, stop_price, POSITION_SIZE);
            arf.has_position_today = true;
            
            zdk.Log.immediate.info(input, output, "SHORT ENTRY @ {d:.2} | Stop: {d:.2}", 
                .{current_price, stop_price});
            zdk.Log.buffered.info(input, output, "Breakout below {d:.2}", .{lookback_low});
        }
    }
    
    // ======================================================================================
    // POSITION MANAGEMENT
    // ======================================================================================
    if (!is_flat) {
        const entry_price = input.average_price;
        const unrealized_pnl = if (is_long)
            (current_price - entry_price) * input.exposure
        else if (is_short)
            (entry_price - current_price) * (-input.exposure)
        else
            0;
        
        zdk.Log.buffered.debug(input, output, "Position: {s} | Entry: {d:.2} | P&L: {d:.2}", 
            .{if (is_long) "LONG" else "SHORT", entry_price, unrealized_pnl});
        
        // Trail stop on profitable trades (simple trailing by 50% of gains)
        if (unrealized_pnl > entry_price * 0.05) {  // If up 5%
            const trail_price = if (is_long)
                entry_price + (current_price - entry_price) * 0.5
            else
                entry_price - (entry_price - current_price) * 0.5;
            
            if (arf.stop_order_id) |stop_id| {
                zdk.Order.modify(output, stop_id, trail_price);
                zdk.Log.immediate.info(input, output, "TRAILING STOP to {d:.2}", .{trail_price});
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


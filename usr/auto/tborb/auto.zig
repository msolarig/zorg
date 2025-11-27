const zdk = @import("zdk.zig");

// AUTO DETAILS ----------------------------------------------------------------------------------*

const NAME: [*:0]const u8 = "TBORB";

// AUTO RUNTIME FIELDS (ARF) ---------------------------------------------------------------------*

const ARF = struct {
    // Order tracking
    long_entry_id: ?u64 = null,
    short_entry_id: ?u64 = null,
    stop_loss_id: ?u64 = null,
    
    // Opening range values
    opening_range_high: f64 = 0,
    opening_range_low: f64 = 0,
    opening_range_value: f64 = 0,
    
    // State flags
    is_opening_range_active: bool = false,
    has_traded_today: bool = false,
    has_auto_breakeven_set: bool = false,
    
    // Timestamp tracking
    prev_timestamp: u64 = 0,
};

fn initARF(arf_ptr: *anyopaque) callconv(.c) void {
    const arf: *ARF = @ptrCast(@alignCast(arf_ptr));
    arf.* = ARF{};
}

// AUTO LOGIC FUNCTION (ALF) --------------------------------------------------------------------*

// Auto Parameters (compile-time configuration)
const OR_START = zdk.Time.TimeOfDay.init(8, 31, 0);   // Opening range start: 8:31 AM
const OR_END = zdk.Time.TimeOfDay.init(8, 35, 0);     // Opening range end: 8:35 AM
const FLATTEN_TIME = zdk.Time.TimeOfDay.init(15, 0, 0); // Flatten time: 3:00 PM

const POSITION_SIZE: f64 = 1;
const AUTO_BREAKEVEN_VALUE: f64 = 1.0;  // Move to breakeven after 1x opening range profit
const FEE_COVERAGE_TICKS: f64 = 2.0;     // Cover fees with 2 ticks
const TICK_SIZE: f64 = 0.25;             // Assumed tick size for now

const ENABLE_AUTO_BREAKEVEN: bool = true;
const ENABLE_FLATTEN_BY: bool = true;

fn alf(input: *const zdk.Input.Packet, output: *zdk.Output.Packet, arf_ptr: ?*anyopaque) callconv(.c) void {
    const arf: *ARF = @ptrCast(@alignCast(arf_ptr.?));
    
    const timestamp = input.trail.ts[0];
    const current_time = zdk.Time.getTimeOfDay(timestamp);
    
    // Get current bar data
    const high = input.trail.hi[0];
    const low = input.trail.lo[0];
    const close = input.trail.cl[0];
    
    // Position state
    const is_long = input.exposure > 0;
    const is_short = input.exposure < 0;
    const is_flat = input.exposure == 0;
    
    // ======================================================================================
    // DAY CHANGE DETECTION - Reset daily state
    // ======================================================================================
    if (arf.prev_timestamp > 0 and zdk.Time.isDayChange(arf.prev_timestamp, timestamp)) {
        zdk.Log.buffered.info(output, "=== NEW TRADING DAY ===", .{});
        
        // Reset all state
        arf.long_entry_id = null;
        arf.short_entry_id = null;
        arf.stop_loss_id = null;
        arf.opening_range_high = 0;
        arf.opening_range_low = 0;
        arf.opening_range_value = 0;
        arf.is_opening_range_active = false;
        arf.has_traded_today = false;
        arf.has_auto_breakeven_set = false;
    }
    arf.prev_timestamp = timestamp;
    
    // ======================================================================================
    // OPENING RANGE PERIOD - Track high/low during specified time window
    // ======================================================================================
    if (current_time.isBetween(OR_START, OR_END)) {
        if (!arf.is_opening_range_active) {
            // Initialize opening range
            arf.opening_range_high = high;
            arf.opening_range_low = low;
            arf.is_opening_range_active = true;
            arf.has_traded_today = false;
            
            zdk.Log.buffered.info(output, "Opening Range INITIATED", .{});
        } else {
            // Update opening range values
            if (high > arf.opening_range_high) {
                arf.opening_range_high = high;
            }
            if (low < arf.opening_range_low) {
                arf.opening_range_low = low;
            }
        }
    }
    
    // ======================================================================================
    // POST-OPENING RANGE - Place breakout orders
    // ======================================================================================
    if (current_time.isAfter(OR_END) and !arf.has_traded_today and arf.is_opening_range_active) {
        // Opening range completed
        arf.is_opening_range_active = false;
        arf.opening_range_value = arf.opening_range_high - arf.opening_range_low;
        
        zdk.Log.immediate.info(output, "Opening Range COMPLETED: High={d:.2} Low={d:.2} Range={d:.2}", 
            .{arf.opening_range_high, arf.opening_range_low, arf.opening_range_value});
        
        // Place breakout orders (stop entries at opening range boundaries)
        arf.long_entry_id = zdk.Order.buyStop(input, output, arf.opening_range_high, POSITION_SIZE);
        arf.short_entry_id = zdk.Order.sellStop(input, output, arf.opening_range_low, POSITION_SIZE);
        
        arf.has_traded_today = true;
        
        zdk.Log.buffered.info(output, "Breakout orders placed: Long@{d:.2} Short@{d:.2}", 
            .{arf.opening_range_high, arf.opening_range_low});
    }
    
    // ======================================================================================
    // AUTO BREAKEVEN - Move stop to entry price after profit threshold
    // ======================================================================================
    if (ENABLE_AUTO_BREAKEVEN and !is_flat and !arf.has_auto_breakeven_set) {
        const entry_price = input.average_price;
        const current_price = close;
        
        // Calculate unrealized P&L
        const unrealized_pnl = if (is_long)
            (current_price - entry_price) * input.exposure
        else if (is_short)
            (entry_price - current_price) * (-input.exposure)
        else
            0;
        
        // Check if profit exceeds threshold (as multiple of opening range)
        const breakeven_threshold = AUTO_BREAKEVEN_VALUE * arf.opening_range_value;
        
        if (unrealized_pnl >= breakeven_threshold) {
            // Cancel opposite entry order
            if (is_long and arf.short_entry_id != null) {
                output.cancelOrder(arf.short_entry_id.?);
                arf.short_entry_id = null;
            } else if (is_short and arf.long_entry_id != null) {
                output.cancelOrder(arf.long_entry_id.?);
                arf.long_entry_id = null;
            }
            
            // Set new stop at breakeven + fee coverage
            const fee_offset = FEE_COVERAGE_TICKS * TICK_SIZE;
            const breakeven_price = if (is_long)
                entry_price + fee_offset
            else
                entry_price - fee_offset;
            
            if (is_long) {
                arf.stop_loss_id = zdk.Order.sellStop(input, output, breakeven_price, POSITION_SIZE);
            } else if (is_short) {
                arf.stop_loss_id = zdk.Order.buyStop(input, output, breakeven_price, POSITION_SIZE);
            }
            
            arf.has_auto_breakeven_set = true;
            
            zdk.Log.immediate.info(output, "AUTO-BREAKEVEN SET at {d:.2} (P&L: {d:.2})", 
                .{breakeven_price, unrealized_pnl});
            zdk.Log.buffered.debug(output, "Entry: {d:.2} Current: {d:.2} Threshold: {d:.2}", 
                .{entry_price, current_price, breakeven_threshold});
        }
    }
    
    // ======================================================================================
    // FLATTEN BY TIME - Close all positions at specified time
    // ======================================================================================
    if (ENABLE_FLATTEN_BY and current_time.isAfter(FLATTEN_TIME) and !is_flat) {
        // Cancel all working orders
        if (arf.long_entry_id != null) {
            output.cancelOrder(arf.long_entry_id.?);
            arf.long_entry_id = null;
        }
        if (arf.short_entry_id != null) {
            output.cancelOrder(arf.short_entry_id.?);
            arf.short_entry_id = null;
        }
        if (arf.stop_loss_id != null) {
            output.cancelOrder(arf.stop_loss_id.?);
            arf.stop_loss_id = null;
        }
        
        // Flatten position
        if (is_long) {
            _ = zdk.Order.sellMarket(input, output, input.exposure);
        } else if (is_short) {
            _ = zdk.Order.buyMarket(input, output, -input.exposure);
        }
        
        zdk.Log.immediate.info(output, "FLATTEN BY TIME - Position closed", .{});
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


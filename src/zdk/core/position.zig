const std = @import("std");
const Fill = @import("fill.zig").Fill;
const side = @import("order.zig").OrderDirection;

pub const PositionError = error{
    InvalidExposure,
    NoActivePosition,
} || std.mem.Allocator.Error;

pub const Position = struct {
    side: side,
    in_fills: std.ArrayList(Fill),
    out_fills: std.ArrayList(Fill),

    pub fn init(gpa: std.mem.Allocator, fill: Fill) !Position {
        var pos = Position{
            .side = fill.side,
            .in_fills = .{},
            .out_fills = .{},
        };
        try pos.in_fills.append(gpa, fill);
        return pos;
    }

    pub fn deinit(self: *Position, gpa: std.mem.Allocator) void {
        self.in_fills.deinit(gpa);
        self.out_fills.deinit(gpa);
    }
};

pub const PositionManager = struct {
    exposure: f64,
    positions: std.ArrayList(Position),
    positions_count: u64,

    pub fn init(gpa: std.mem.Allocator) PositionManager {
        _ = gpa;
        return PositionManager{ 
            .exposure = 0, 
            .positions = .{}, 
            .positions_count = 0 
        };
    }

    pub fn updateInstrumentExposure(self: *PositionManager, gpa: std.mem.Allocator, fill: Fill) PositionError!void {
        // Validate fill data
        if (fill.volume <= 0 or !std.math.isFinite(fill.volume)) {
            if (@import("builtin").is_test == false) {
                std.debug.print("Error: Invalid fill volume: {d}\n", .{fill.volume});
            }
            return PositionError.InvalidExposure;
        }
        if (fill.price <= 0 or !std.math.isFinite(fill.price)) {
            if (@import("builtin").is_test == false) {
                std.debug.print("Error: Invalid fill price: {d}\n", .{fill.price});
            }
            return PositionError.InvalidExposure;
        }
        const initial_exposure: f64 = self.exposure;

        // calculate new exposure value based on fill direction
        if (fill.side == .Buy) {
            self.exposure += fill.volume;
        } else {
            self.exposure -= fill.volume;
        }

        // -----------------------------------------------------------------------------------------------
        // Declare Scenarios
        // -----------------------------------------------------------------------------------------------

        // Initiated +/- net exposure
        const initiated_position: bool = initial_exposure == 0 and self.exposure != 0;

        // Increased / Decreased Position
        const increased_exposure: bool =
            (initial_exposure > 0 and self.exposure > initial_exposure) or
            (initial_exposure < 0 and self.exposure < initial_exposure);

        const decreased_exposure: bool =
            (self.exposure > 0 and self.exposure < initial_exposure) or
            (self.exposure < 0 and self.exposure > initial_exposure);

        // flipped position
        const flipped_position: bool = (initial_exposure < 0 and self.exposure > 0) or (initial_exposure > 0 and self.exposure < 0);

        // Reached neutral exposure
        const flattened_position: bool = initial_exposure != 0 and self.exposure == 0;

        // -----------------------------------------------------------------------------------------------
        // Update Positions
        // -----------------------------------------------------------------------------------------------

        // Flip exposure
        if (flipped_position) {
            const exceeding_vol = fill.volume - initial_exposure;
            const closing_fill = Fill.init(fill.order_id, fill.iter, fill.timestamp, fill.side, fill.price, initial_exposure);
            const opening_fill = Fill.init(fill.order_id, fill.iter, fill.timestamp, fill.side, fill.price, exceeding_vol);
            try self.positions.items[self.positions_count - 1].out_fills.append(gpa, closing_fill);
            const new_position: Position = try Position.init(gpa, opening_fill);
            try self.positions.append(gpa, new_position);
            self.positions_count += 1;
            return;
        }

        // Initialize exposure
        else if (initiated_position) {
            const new_position: Position = try Position.init(gpa, fill);
            try self.positions.append(gpa, new_position);
            self.positions_count += 1;
            return;
        }

        // Increase exposure
        else if (increased_exposure) {
            try self.positions.items[self.positions_count - 1].in_fills.append(gpa, fill);
            return;
        }

        // Decrease or flatten exposure
        else if (flattened_position | decreased_exposure) {
            try self.positions.items[self.positions_count - 1].out_fills.append(gpa, fill);
            return;
        }
    }

    /// Get average entry price of current position (0 if flat)
    pub fn getAveragePrice(self: *const PositionManager) f64 {
        // If flat, no average price
        if (self.exposure == 0) return 0;
        if (self.positions_count == 0) return 0;
        
        const current_position = &self.positions.items[self.positions_count - 1];
        var total_value: f64 = 0;
        var total_volume: f64 = 0;
        
        for (current_position.in_fills.items) |fill| {
            total_value += fill.price * fill.volume;
            total_volume += fill.volume;
        }
        
        if (total_volume == 0) return 0;
        return total_value / total_volume;
    }
    
    /// Get unrealized P&L in points for current position
    pub fn getUnrealizedPnL(self: *const PositionManager, current_price: f64) f64 {
        if (self.exposure == 0) return 0;
        
        const avg_price = self.getAveragePrice();
        if (avg_price == 0) return 0;
        
        // Long: profit when price goes up
        // Short: profit when price goes down
        if (self.exposure > 0) {
            return (current_price - avg_price) * self.exposure;
        } else {
            return (avg_price - current_price) * (-self.exposure);
        }
    }

    pub fn deinit(self: *PositionManager, gpa: std.mem.Allocator) void {
        for (self.positions.items) |*position| {
            position.deinit(gpa);
        }
        self.positions.deinit(gpa);
    }
};

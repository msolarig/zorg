const std = @import("std");
const Fill = @import("fill.zig").Fill;
const side = @import("order.zig").OrderDirection;

pub const Position = struct {
    side: side,
    in_fills: std.ArrayList(Fill),
    out_fills: std.ArrayList(Fill),

    pub fn init(gpa: std.mem.Allocator, fill: Fill) !Position {
        var in_fills: std.ArrayList(Fill) = .{};
        try in_fills.append(gpa, fill);

        return Position{ .side = fill.side, .in_fills = in_fills, .out_fills = .{} };
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

    pub fn init() PositionManager {
        return PositionManager{ .exposure = 0, .positions = .{}, .positions_count = 0 };
    }

    pub fn updateInstrumentExposure(self: *PositionManager, gpa: std.mem.Allocator, fill: Fill) !void {
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
            const closing_fill = Fill.init(fill.iter, fill.timestamp, fill.side, fill.price, initial_exposure);
            const opening_fill = Fill.init(fill.iter, fill.timestamp, fill.side, fill.price, exceeding_vol);
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

    pub fn deinit(self: *PositionManager, gpa: std.mem.Allocator) void {
        for (self.positions.items) |*position| {
            position.deinit(gpa);
        }
        self.positions.deinit(gpa);
    }
};

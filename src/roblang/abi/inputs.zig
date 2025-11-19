pub const TrailABI = @import("trail.zig").TrailABI;
pub const AccountABI = @import("account.zig").AccountABI;
pub const PositionABI = @import("position.zig").PositionABI;

/// Auto receives an instance of this struct per iteration.
pub const AutoInputs = extern struct {
    trail: *const TrailABI,
    account: *const AccountABI,
    positions: ?[*]const PositionABI,
    position_count: u64,
};

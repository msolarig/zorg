pub const TrailABI = @import("trail.zig").TrailABI;
pub const AccountABI = @import("account.zig").AccountABI;
pub const FillABI = @import("fill.zig").FillABI;
pub const InstructionPacket = @import("command.zig").InstructionPacket;

/// Auto receives an instance of this struct per iteration.
pub const AutoInputs = extern struct {
    iter: u64,
    trail: *const TrailABI,
    account: *const AccountABI,
    exposure: *f64,
};

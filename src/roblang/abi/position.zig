const Side = @import("../core/order.zig").OrderDirection;

pub const PositionABI = extern struct {
    ptr: [*]const PositionEntryABI,
    count: u64,
};

pub const PositionEntryABI = extern struct {
    side: Side,
    price: f64,
    volume: f64,
};

const Side = @import("../core/order.zig").OrderDirection;

pub const FillABI = extern struct {
    ptr: [*]const FillEntryABI,
    count: u64,
};

pub const FillEntryABI = extern struct {
    iter: u64,
    timestamp: u64,
    side: Side,
    price: f64,
    volume: f64,
};

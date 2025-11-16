const std = @import("std");

/// ABI-safe Trail Implementation
pub const TrailABI = extern struct {
    ts: [*]const u64,
    op: [*]const f64,
    hi: [*]const f64,
    lo: [*]const f64,
    cl: [*]const f64,
    vo: [*]const u64,
};

const types = @import("types.zig");
const commands = @import("commands.zig");

/// ABI structures for communication between autos and engine

pub const TrailABI = extern struct {
    ts: [*]const u64,
    op: [*]const f64,
    hi: [*]const f64,
    lo: [*]const f64,
    cl: [*]const f64,
    vo: [*]const u64,
};

pub const AccountABI = extern struct {
    balance: f64,
};

pub const FillEntryABI = extern struct {
    iter: u64,
    timestamp: u64,
    side: types.OrderDirection,
    price: f64,
    volume: f64,
};

pub const FillABI = extern struct {
    ptr: [*]const FillEntryABI,
    count: u64,
};

pub const ALF = *const fn (
    input: *const @import("io.zig").Input.Packet,
    output: *@import("io.zig").Output.Packet,
    arf: ?*anyopaque,
) callconv(.c) void;

pub const ADF = *const fn () callconv(.c) void;

pub const ArfInitFn = *const fn (arf: *anyopaque) callconv(.c) void;

pub const ABI = extern struct {
    version: u32,
    name: [*:0]const u8,
    alf: ALF,
    adf: ADF,
    arf_size: usize,
    arf_init: ?ArfInitFn,
};

pub const GetABIFn = *const fn () callconv(.c) *const ABI;
pub const ENTRY_SYMBOL = "getABI";


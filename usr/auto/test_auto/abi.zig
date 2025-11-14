// ------------------------------------------------------------------------------------------------
// ABI Declarations (DO NOT MODIFY)
// ------------------------------------------------------------------------------------------------

/// inline Auto ABI (match src/engine/auto/abi.zig)
///  Interaction between compiled auto and compiled application. 
pub const TrailABI = extern struct {
    ts: [*]const u64, op: [*]const f64, hi: [*]const f64,
    lo: [*]const f64, cl: [*]const f64, vo: [*]const u64,
};

pub const AutoABI = extern struct {
    name: [*:0]const u8,
    desc: [*:0]const u8,
    logic_function: *const fn (iter_index: u64, trail: *const TrailABI) callconv(.c) void,
    deinit: *const fn () callconv(.c) void,
};

pub const GetAutoABIFn = *const fn () callconv(.c) *const AutoABI;
pub const ENTRY_SYMBOL = "getAutoABI";

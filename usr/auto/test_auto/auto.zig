const std = @import("std");
const abi = @import("abi.zig");

/// Auto Export Function
///   Provides ROBERT with an interface to access the compiled AUTO.
///   Update name & description. Do not modify ABI struct insance declaration. 
pub export fn getAutoABI() callconv(.c) *const abi.AutoABI {
  const NAME: [*:0]const u8 = "TEST_AUTO";
  const DESC: [*:0]const u8 = "TEST_AUTO_DESCRIPTION";

  const ABI = abi.AutoABI{
    .name = NAME,
    .desc = DESC,
    .logic_function = autoLogicFunction,
    .deinit = deinit,
  };
  return &ABI;
}

// Custom Auto variables & methods ------------------------
const minimum_required_data_points: u64 = 2;
// --------------------------------------------------------

/// Execution Function
///   Called once per update in data feed.
fn autoLogicFunction(iter_index: u64, trail: *const abi.TrailABI) callconv(.c) void {
  // Basic auto logic
  if (iter_index >= minimum_required_data_points) {
    if (trail.op[0] < trail.op[1] and trail.cl[0] > trail.cl[1] and trail.cl[1] < trail.op[0])
      std.debug.print("  SAMPLE AUTO LOG: {d:03}|{d}: BUY @ {d:.2}\n", .{iter_index, trail.ts[0], trail.cl[0]});
      return;
  }
} 

/// Deinitialization Function
///  Called once by the engine at the end of the process. 
///  Include any allocated variables inside to avoid memory leak errors.
fn deinit() callconv(.c) void {
  //std.debug.print("Auto Deinitialized\n", .{});
  return;
}

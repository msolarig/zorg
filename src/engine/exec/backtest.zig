const std = @import("std");
const Engine = @import("../engine.zig").Engine;
const abi = @import("../../roblang/abi.zig");

/// Perform Backtest
pub fn runBacktest(engine: *Engine) !void {

  // Temporary stub until account system connected
  var account_instance = abi.AccountABI{
    .equity = 0,
    .unrealized_pnl = 0,
    .realized_pnl = 0,
    .margin_used = 0,
  };

  const positions_ptr: ?[*]const abi.PositionABI = null;
  const position_count: u64 = 0;

  // Execution Loop
  for (0..engine.track.size) |i| {

    try engine.trail.load(engine.track, i);
    const trail_abi = engine.trail.toABI();

    var inputs = abi.Inputs{
      .trail = &trail_abi,
      .account = &account_instance,
      .positions = positions_ptr,
      .position_count = position_count,
    };

    const packet = engine.auto.api.logic(i, &inputs);
    _ = packet; // TODO: engine must process returned command packet
  }
}

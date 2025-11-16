const std = @import("std");
const Engine = @import("../engine.zig").Engine;
const abi = @import("../../roblang/abi.zig");
const InstructionPacket = @import("../../roblang/wrappers/command.zig").InstructionPacket;
const OrderManager = @import("../../roblang/core/order/order_manager.zig").OrderManager;
const controller = @import("../../roblang/controller.zig");

/// Perform Backtest
pub fn runBacktest(engine: *Engine) !void {

    var om: OrderManager = OrderManager.init();
    //pm = POSITION MANAGER
    //acc = ACCOUNT

    // Temporary stub until account system connected
    var account_instance = abi.AccountABI{
        .equity = 0,
        .unrealized_pnl = 0,
        .realized_pnl = 0,
        .margin_used = 0,
    };
    
    // Temporary postion stub
    const positions_ptr: ?[*]const abi.PositionABI = null;
    const position_count: u64 = 0;

    // Execution Loop
    // Iterates through track, calling auto and updating the trail repeatedly
    for (0..engine.track.size) |i| {
        try engine.trail.load(engine.track, i);
        const trail_abi = engine.trail.toABI();

        var inputs = abi.Inputs{
            .trail = &trail_abi,
            .account = &account_instance,
            .positions = positions_ptr,
            .position_count = position_count,
        };

        const pkt: InstructionPacket = engine.auto.api.logic(i, &inputs);
        try controller.ExecuteInstructionPacket(engine.alloc, pkt, &om);
    }
}

const std = @import("std");
const Engine = @import("../engine.zig").Engine;
const abi = @import("../../roblang/abi/abi.zig");
const InstructionPacket = @import("../../roblang/abi/command.zig").InstructionPacket;
const Command = @import("../../roblang/abi/command.zig").Command;
const OM = @import("../../roblang/core/order.zig").OrderManager;
const PM = @import("../../roblang/core/position.zig").PositionManager;
const controller = @import("../../roblang/controller.zig");
const writer = @import("../../engine/out/csv_writer.zig");

pub fn runBacktest(engine: *Engine) !void {
    var om: OM = OM.init();
    var pm: PM = PM.init();
    //TODO: INITIALIZE ACCOUNT. Should be an engine field, passed by the map

    defer om.deinit(engine.alloc);
    defer pm.deinit(engine.alloc);

    // Temporary stub until account system connected
    var account_instance = abi.AccountABI{};

    // Temporary postion stub
    const positions_ptr: ?[*]const abi.PositionABI = null;
    const position_count: u64 = 0;

    // Execution Loop
    // Iterate through track, calling auto and updating the trail repeatedly
    for (0..engine.track.size) |i| {
        try engine.trail.load(engine.track, i);
        const trail_abi = engine.trail.toABI();

        // Iterate through working orders.
        // Execute if possible
        try pm.evaluateWorkingOrders(engine.alloc, &om);

        var inputs = abi.Inputs{ // update with new PM implementaion TODO
            .trail = &trail_abi,
            .account = &account_instance,
            .positions = positions_ptr,
            .position_count = position_count,
        };

        const pkt: InstructionPacket = engine.auto.api.logic(i, &inputs);
        try controller.ExecuteInstructionPacket(engine.alloc, pkt, &om);
    }

    // Simple CSV Output with position history
    const out_file_name: []const u8 = "result.csv";
    try writer.writePositionsCSV(&pm, out_file_name);
    std.debug.print("  Saved results to {s}\n", .{out_file_name});
}

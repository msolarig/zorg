const std = @import("std");
const Engine = @import("../engine.zig").Engine;
const abi = @import("../../roblang/abi/abi.zig");
const InstructionPacket = @import("../../roblang/abi/command.zig").InstructionPacket;
const Command = @import("../../roblang/abi/command.zig").Command;
const OM = @import("../../roblang/core/order.zig").OrderManager;
const PM = @import("../../roblang/core/position.zig").PositionManager;
const AM = @import("../../roblang/core/account.zig").AccountManager;
const controller = @import("../../roblang/controller.zig");
const writer = @import("../../engine/out/csv_writer.zig");

pub fn runBacktest(engine: *Engine) !void {
    var om: OM = OM.init();
    var pm: PM = PM.init();

    defer om.deinit(engine.alloc);
    defer pm.deinit(engine.alloc);

    const am: AM = AM.init(engine.acc);

    // Execution Loop
    for (0..engine.track.size, 0..) |row, index| {
        try engine.trail.load(engine.track, row);

        // Iterate through working orders.
        // Execute if possible
        try pm.evaluateWorkingOrders(engine.alloc, &om);

        var inputs = abi.Inputs{
            .iter = index,
            .trail = &engine.trail.toABI(),
            .account = &am.toABI(),
            .positions = &(try pm.toABI(engine.alloc)),
        };

        var command_buffer: [128]Command = undefined;
        var pkt: InstructionPacket = .{
            .count = 0,
            .commands = &command_buffer,
        };

        engine.auto.api.logic(&inputs, &pkt);
        try controller.ExecuteInstructionPacket(engine.alloc, pkt, &om);
    }

    // Simple CSV Output with position history
    const out_file_name: []const u8 = "result.csv";
    try writer.writePositionsCSV(&pm, out_file_name);
    std.debug.print("  Saved results to {s}\n", .{out_file_name});
}

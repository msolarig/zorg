const std = @import("std");
const Engine = @import("../engine.zig").Engine;
const abi = @import("../../roblang/abi/abi.zig");
const InstructionPacket = @import("../../roblang/abi/command.zig").InstructionPacket;
const Command = @import("../../roblang/abi/command.zig").Command;
const OM = @import("../../roblang/core/order.zig").OrderManager;
const FM = @import("../../roblang/core/fill.zig").FillManager;
const AM = @import("../../roblang/core/account.zig").AccountManager;
const controller = @import("../../roblang/controller.zig");
const writer = @import("../../engine/out/csv_writer.zig");

pub fn runBacktest(engine: *Engine) !void {
    var om: OM = OM.init();
    var fm: FM = FM.init();

    defer om.deinit(engine.alloc);
    defer fm.deinit(engine.alloc);

    const am: AM = AM.init(engine.acc);

    // Execution Loop
    for (0..engine.track.size, 1..) |row, index| {
        try engine.trail.load(engine.track, row);

        // Iterate through working orders.
        // Execute if possible
        try fm.evaluateWorkingOrders(engine.alloc, &om);

        var inputs = abi.Inputs{
            .iter = index,
            .trail = &engine.trail.toABI(),
            .account = &am.toABI(),
            .fills = &(try fm.toABI(engine.alloc)),
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
    const out_file_name: []const u8 = "fills.csv";
    try writer.writeFillsCSV(&engine.out, engine.alloc, &fm, out_file_name);
    std.debug.print("  Saved results to {s}\n", .{out_file_name});
}

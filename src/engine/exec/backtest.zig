const std = @import("std");
const Engine = @import("../engine.zig").Engine;
const abi = @import("../../roblang/abi/abi.zig");
const InstructionPacket = @import("../../roblang/abi/command.zig").InstructionPacket;
const Command = @import("../../roblang/abi/command.zig").Command;
const OM = @import("../../roblang/core/order.zig").OrderManager;
const FM = @import("../../roblang/core/fill.zig").FillManager;
const PM = @import("../../roblang/core/position.zig").PositionManager;
const AM = @import("../../roblang/core/account.zig").AccountManager;
const controller = @import("../../roblang/controller.zig");
const csv_writer = @import("../../engine/out/csv_writer.zig");

pub fn runBacktest(engine: *Engine) !void {
    var om: OM = OM.init();
    var fm: FM = FM.init();
    var pm: PM = PM.init();

    defer om.deinit(engine.alloc);
    defer fm.deinit(engine.alloc);
    defer pm.deinit(engine.alloc);

    const am: AM = AM.init(engine.acc);

    // Execution Loop
    for (0..engine.track.size, 1..) |row, index| {
        try engine.trail.load(engine.track, row);

        // Iterate through working orders.
        // Execute if possible
        try fm.evaluateWorkingOrders(engine.alloc, &om, &pm);

        std.debug.print("  Current Exposure: {d}\n", .{pm.exposure});

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
    
    // Output Section
    // For now the program separates order & fills in separate tables and
    // writes them to usr/out/NAME_SELECTED_IN_ENGINE_MAP/
    
    // Simple CSV output with order history
    const order_out_file_name: []const u8 = "orders.csv";
    try csv_writer.writeOrderCSV(&engine.out, &om, order_out_file_name);
    std.debug.print("  Saved Order Log to {s}\n", .{order_out_file_name});

    // Simple CSV output with fill history
    const fill_out_file_name: []const u8 = "fills.csv";
    try csv_writer.writeFillsCSV(&engine.out, &fm, fill_out_file_name);
    std.debug.print("  Saved Fill Log to {s}\n", .{fill_out_file_name});

    // Simple CSV output with position history  
    const position_out_file_name: []const u8 = "positions.csv";
    _ = position_out_file_name;
}

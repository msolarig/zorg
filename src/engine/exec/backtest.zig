const std = @import("std");
const Engine = @import("../engine.zig").Engine;
const abi = @import("../../zdk/abi.zig");
const core = @import("../../zdk/core.zig");
const controller = @import("../../zdk/controller.zig");
const csv_writer = @import("../out/csv_writer.zig");

const OM = core.OrderManager;
const FM = core.FillManager;
const PM = core.PositionManager;
const AM = core.AccountManager;

pub fn runBacktest(engine: *Engine) !void {
    var om: OM = OM.init();
    var fm: FM = FM.init();
    var pm: PM = PM.init();

    defer om.deinit(engine.alloc);
    defer fm.deinit(engine.alloc);
    defer pm.deinit(engine.alloc);

    const am: AM = AM.init(engine.acc);

    for (0..engine.track.size, 1..) |row, index| {
        try engine.trail.load(engine.track, row);
        try fm.evaluateWorkingOrders(engine.alloc, &om, &pm);

        var inputs = abi.Input.Packet{
            .iter = index,
            .trail = &engine.trail.toABI(),
            .account = &am.toABI(),
            .exposure = &pm.exposure,
        };

        var command_buffer: [128]abi.Command = undefined;
        var packet: abi.Output.Packet = .{
            .count = 0,
            .commands = &command_buffer,
        };

        engine.auto.api.logic(&inputs, &packet);
        try controller.executeInstructionPacket(engine.alloc, packet, &om);
    }

    try csv_writer.writeOrderCSV(&engine.out, &om, "orders.csv");
    try csv_writer.writeFillsCSV(&engine.out, &fm, "fills.csv");
    try csv_writer.writePositionCSV(&engine.out, &pm, "positions.csv");
}

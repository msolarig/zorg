const std = @import("std");
const Engine = @import("../engine.zig").Engine;
const abi = @import("../../zdk/abi.zig");
const core = @import("../../zdk/core.zig");
const controller = @import("../../zdk/controller.zig");
const sqlite_writer = @import("../output/sqlite_writer.zig");
const logger = @import("../output/logger.zig");
const html_report = @import("../output/html_report.zig");

const OM = core.OrderManager;
const FM = core.FillManager;
const PM = core.PositionManager;
const AM = core.AccountManager;

pub const BacktestError = error{
    ARFAllocationFailed,
    ARFInitFailed,
    TrailLoadFailed,
    OrderEvaluationFailed,
    AutoExecutionFailed,
    OutputWriteFailed,
    InvalidDataSize,
    NoSpaceLeft,
    InvalidPrice,
    InvalidVolume,
    InvalidBarData,
    InvalidExposure,
    NoActivePosition,
    InvalidFilePath,
    InvalidOrderID,
    OrderNotFound,
    OrderAlreadyFilled,
    InvalidCommand,
    OrderExecutionFailed,
} || std.mem.Allocator.Error;

pub fn runBacktest(engine: *Engine) BacktestError!void {
    // Validate minimum data requirements
    if (engine.track.size < engine.trail.size) {
        std.debug.print("Error: Insufficient data. Track size ({d}) < Trail size ({d})\n", .{engine.track.size, engine.trail.size});
        std.debug.print("Reduce trail size or provide more data\n", .{});
        return BacktestError.InvalidDataSize;
    }
    var om: OM = OM.init(engine.alloc);
    var fm: FM = FM.init();
    var pm: PM = PM.init(engine.alloc);

    defer om.deinit();
    defer fm.deinit(engine.alloc);
    defer pm.deinit(engine.alloc);

    const am: AM = AM.init(engine.acc);

    // Allocate ARF (Auto Runtime Fields) memory if needed
    const arf_size = engine.auto.api.arf_size;
    var arf_memory: ?[]u8 = null;
    defer if (arf_memory) |mem| engine.alloc.free(mem);

    if (arf_size > 0) {
        arf_memory = engine.alloc.alloc(u8, arf_size) catch |err| {
            std.debug.print("Error: Failed to allocate ARF memory ({d} bytes): {s}\n", .{arf_size, @errorName(err)});
            return BacktestError.ARFAllocationFailed;
        };
        // Initialize ARF
        if (engine.auto.api.arf_init) |init_fn| {
            init_fn(arf_memory.?.ptr);
        } else {
            std.debug.print("Warning: ARF size is {d} but no init function provided\n", .{arf_size});
        }
    }

    // Allocate log buffers to collect logs across all iterations
    var buffered_logs: std.ArrayList(abi.LogEntry) = .{};
    defer buffered_logs.deinit(engine.alloc);
    
    var immediate_logs: std.ArrayList(abi.LogEntry) = .{};
    defer immediate_logs.deinit(engine.alloc);

    for (0..engine.track.size, 1..) |row, index| {
        try engine.trail.load(engine.track, row);
        
        // Get current bar OHLC for order evaluation
        const bar_open = engine.trail.op[0];
        const bar_high = engine.trail.hi[0];
        const bar_low = engine.trail.lo[0];
        const bar_close = engine.trail.cl[0];
        
        try fm.evaluateWorkingOrders(engine.alloc, &om, &pm, bar_high, bar_low, bar_open, bar_close);

        // Calculate position metrics
        const avg_price = pm.getAveragePrice();

        var inputs = abi.Input.Packet{
            .iter = index,
            .trail = &engine.trail.toABI(),
            .account = &am.toABI(),
            .exposure = pm.exposure,
            .average_price = avg_price,
        };

        var command_buffer: [128]abi.Command = undefined;
        var order_id_buffer: [128]u64 = undefined;
        
        // Pre-populate order_id_buffer with the next sequential IDs
        // This allows order placement functions to return correct IDs synchronously
        for (0..order_id_buffer.len) |i| {
            order_id_buffer[i] = om.next_id + i;
        }
        
        var log_entry_buffer: [64]abi.LogEntry = undefined;
        var immediate_log_buffer: [64]abi.LogEntry = undefined;
        var packet: abi.Output.Packet = .{
            .count = 0,
            .commands = &command_buffer,
            .returned_order_ids = &order_id_buffer,
            .log_count = 0,
            .log_entries = &log_entry_buffer,
            .immediate_log_count = 0,
            .immediate_log_entries = &immediate_log_buffer,
        };

        const arf_ptr = if (arf_memory) |mem| @as(?*anyopaque, @ptrCast(mem.ptr)) else null;
        engine.auto.api.alf(&inputs, &packet, arf_ptr);
        
        controller.executeInstructionPacket(engine.alloc, packet, &om) catch |err| {
            std.debug.print("Error: Failed to execute commands at iteration {d}: {s}\n", .{index, @errorName(err)});
            return BacktestError.AutoExecutionFailed;
        };

        // Collect logs from this iteration
        for (0..packet.log_count) |i| {
            try buffered_logs.append(engine.alloc, log_entry_buffer[i]);
        }
        for (0..packet.immediate_log_count) |i| {
            try immediate_logs.append(engine.alloc, immediate_log_buffer[i]);
        }
    }

    sqlite_writer.writeBacktestDB(&engine.out, &om, &fm, &pm, "backtest.db") catch |err| {
        std.debug.print("Error: Failed to write database output: {s}\n", .{@errorName(err)});
        return BacktestError.OutputWriteFailed;
    };
    
    logger.writeLogFile(&engine.out, immediate_logs.items, buffered_logs.items, "runtime.log") catch |err| {
        std.debug.print("Error: Failed to write log file: {s}\n", .{@errorName(err)});
        return BacktestError.OutputWriteFailed;
    };
    
    // Get auto name from map
    const auto_name = std.fs.path.stem(engine.map.auto);
    
    // Build path to auto source file
    var auto_source_buf: [512]u8 = undefined;
    const auto_source_path = try std.fmt.bufPrint(&auto_source_buf, "usr/auto/{s}/auto.zig", .{auto_name});
    
    // ZDK version
    const zdk_version = "v1.0.0";
    
    html_report.generateHTMLReport(&engine.out, "backtest.db", "report.html", auto_name, auto_source_path, zdk_version) catch |err| {
        std.debug.print("Error: Failed to generate HTML report: {s}\n", .{@errorName(err)});
        std.debug.print("Note: Database and logs were written successfully\n", .{});
        return BacktestError.OutputWriteFailed;
    };
}

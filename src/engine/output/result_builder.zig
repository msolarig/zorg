const std = @import("std");
const Engine = @import("../engine.zig").Engine;
const ExecutionResult = @import("../../tui/state.zig").ExecutionResult;
const path_util = @import("../../utils/path_utility.zig");

pub fn buildExecutionResult(
    alloc: std.mem.Allocator,
    engine: *Engine,
    map_path: []const u8,
    project_root: []const u8,
    init_time_ms: i64,
    exec_time_ms: i64,
    total_time_ms: i64,
    success: bool,
) !ExecutionResult {
    const auto_name = try alloc.dupe(u8, std.mem.span(engine.auto.api.name));
    errdefer alloc.free(auto_name);
    
    const auto_path = try extractRelPath(alloc, engine.map.auto, project_root);
    errdefer alloc.free(auto_path);
    
    const mode_str = switch (engine.map.exec_mode) {
        .LiveExecution => "LIVE",
        .Backtest => "BACKTEST",
        .Optimization => "OPTIMIZATION",
    };
    const exec_mode = try alloc.dupe(u8, mode_str);
    errdefer alloc.free(exec_mode);
    
    const db_path = try extractRelPath(alloc, engine.map.db, project_root);
    errdefer alloc.free(db_path);
    
    const feed_str = switch (engine.map.feed_mode) {
        .Live => "LIVE",
        .SQLite3 => "SQLite3",
    };
    const feed_mode = try alloc.dupe(u8, feed_str);
    errdefer alloc.free(feed_mode);
    
    const table = try alloc.dupe(u8, engine.map.table);
    errdefer alloc.free(table);
    
    const map_path_dup = try alloc.dupe(u8, map_path);
    errdefer alloc.free(map_path_dup);
    
    const output_dir = try alloc.dupe(u8, engine.out.abs_dir_path);
    errdefer alloc.free(output_dir);
    
    var output_orders_path: []const u8 = "";
    var output_fills_path: []const u8 = "";
    var output_positions_path: []const u8 = "";
    
    if (success) {
        output_orders_path = try engine.out.filePath(alloc, "orders.csv");
        errdefer alloc.free(output_orders_path);
        output_fills_path = try engine.out.filePath(alloc, "fills.csv");
        errdefer alloc.free(output_fills_path);
        output_positions_path = try engine.out.filePath(alloc, "positions.csv");
        errdefer alloc.free(output_positions_path);
    } else {
        output_orders_path = try alloc.dupe(u8, "");
        errdefer alloc.free(output_orders_path);
        output_fills_path = try alloc.dupe(u8, "");
        errdefer alloc.free(output_fills_path);
        output_positions_path = try alloc.dupe(u8, "");
        errdefer alloc.free(output_positions_path);
    }
    
    const data_points = engine.track.size;
    const throughput: f64 = if (exec_time_ms > 0)
        @as(f64, @floatFromInt(data_points)) / (@as(f64, @floatFromInt(exec_time_ms)) / 1000.0)
    else
        0;
    
    return ExecutionResult{
        .map_path = map_path_dup,
        .auto_name = auto_name,
        .auto_path = auto_path,
        .exec_mode = exec_mode,
        .db_path = db_path,
        .feed_mode = feed_mode,
        .table = table,
        .data_points = data_points,
        .trail_size = engine.map.trail_size,
        .balance = engine.acc.balance,
        .output_dir = output_dir,
        .output_orders_path = output_orders_path,
        .output_fills_path = output_fills_path,
        .output_positions_path = output_positions_path,
        .init_time_ms = init_time_ms,
        .exec_time_ms = exec_time_ms,
        .total_time_ms = total_time_ms,
        .throughput = throughput,
        .success = success,
    };
}

fn extractRelPath(alloc: std.mem.Allocator, path: []const u8, project_root: []const u8) ![]const u8 {
    // Try to find project root in path
    if (std.mem.indexOf(u8, path, project_root)) |idx| {
        const rel = path[idx + project_root.len..];
        if (rel.len > 0 and rel[0] == '/') {
            return try alloc.dupe(u8, rel[1..]);
        }
        return try alloc.dupe(u8, rel);
    }
    // Fallback: try to find "usr/" in path
    if (std.mem.indexOf(u8, path, "usr/")) |idx| {
        return try alloc.dupe(u8, path[idx..]);
    }
    return try alloc.dupe(u8, std.fs.path.basename(path));
}


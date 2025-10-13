const std = @import("std");

extern fn sqlite3_open(filename: [*:0]const u8, db: *?*anyopaque) c_int;
extern fn sqlite3_close(db: *anyopaque) c_int;

extern fn sqlite3_prepare_v2(
    db: *anyopaque,
    sql: [*:0]const u8,
    nByte: c_int,
    stmt: *?*anyopaque,
    tail: *?*[*:0]const u8,
) c_int;

extern fn sqlite3_step(stmt: *anyopaque) c_int;
extern fn sqlite3_finalize(stmt: *anyopaque) c_int;
extern fn sqlite3_column_text(stmt: *anyopaque, col: c_int) [*:0]const u8;
extern fn sqlite3_column_double(stmt: *anyopaque, col: c_int) f64;
extern fn sqlite3_errmsg(db: *anyopaque) [*:0]const u8;

// This module wraps SQLite so the rest of the project
// can use clean Zig functions to open, query, close the DB.

pub fn testConnection() void {
    std.debug.print("DB Module connected\n", .{});
}

pub fn openDB(path: []const u8) !*anyopaque {
    var db_handle: ?*anyopaque = null;

    const c_path = try std.heap.c_allocator.dupeZ(u8, path);
    defer std.heap.c_allocator.free(c_path);

    const rc = sqlite3_open(c_path, &db_handle);

    if(rc != 0) {
        std.debug.print("Failed to open DB\n", .{});
        return error.OpenFailed;
    }

    std.debug.print("Opened DB successfully\n", .{});
    return db_handle.?;
}

pub fn closeDB(db_handle: *anyopaque) !void {
    const rc = sqlite3_close(db_handle);
    if (rc != 0) {
        std.debug.print("Failed to close DB\n", .{});
        return error.CloseFailed;
    }
    std.debug.print("Closed DB successfully\nv", .{});
}

pub fn queryOhlcv(db: *anyopaque, debug: bool) !void {
    var timer: ?std.time.Timer = null;
    if (debug) timer = try std.time.Timer.start();

    const sql = "SELECT symbol, close FROM ohlcv;";
    const c_sql = try std.heap.c_allocator.dupeZ(u8, sql);
    defer std.heap.c_allocator.free(c_sql);

    var stmt: ?*anyopaque = null;
    var tail: ?*[*:0]const u8 = null;
    const rc = sqlite3_prepare_v2(db, c_sql, -1, &stmt, &tail);

    if (rc != 0) {
        const errmsg = sqlite3_errmsg(db);
        const msg = std.mem.span(errmsg);
        std.debug.print("SQLite prepare error: {s}\n", .{msg});
        return error.PrepareFailed;
    }
    
    std.debug.print("Prepared statement successfully\n", .{});
    
    // Execute query and fetch rows
    var count: usize = 0;
    while (sqlite3_step(stmt.?) == 100) {
        count += 1;
        const symbol_ptr = sqlite3_column_text(stmt.?, 0); 
        const close_value = sqlite3_column_double(stmt.?, 1);

        const symbol = std.mem.span(symbol_ptr);
        std.debug.print("{s}: {d:.2}\n", .{ symbol, close_value});
    }

    std.debug.print("Total rows read: {}\n", .{count});

    // Clean up statement before returning
    _ = sqlite3_finalize(stmt.?);

    if (debug) {
        const elapsed_ns = timer.?.read();
        const ms = @as(f64, @floatFromInt(elapsed_ns)) / 1_000_000.0;
        std.debug.print("Query time: {d:.3} ms\n", .{ms});
    }
}

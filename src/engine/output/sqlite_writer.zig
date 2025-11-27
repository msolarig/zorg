const std = @import("std");
const c = @cImport({
    @cInclude("sqlite3.h");
});
const OutputManager = @import("output_manager.zig").OutputManager;
const core = @import("../../zdk/core.zig");
const OrderManager = core.OrderManager;
const FillManager = core.FillManager;
const PositionManager = core.PositionManager;

pub const SQLiteError = error{
    DatabaseOpenFailed,
    DatabaseWriteFailed,
    TableCreationFailed,
    PrepareStatementFailed,
    BindParameterFailed,
    ExecutionFailed,
    InsertFailed,
    PathResolutionFailed,
} || std.mem.Allocator.Error;

pub fn writeBacktestDB(
    out: *OutputManager,
    om: *OrderManager,
    fm: *FillManager,
    pm: *PositionManager,
    filename: []const u8,
) SQLiteError!void {
    const full_path = out.filePath(std.heap.page_allocator, filename) catch |err| {
        std.debug.print("Error: Failed to resolve database path: {s}\n", .{@errorName(err)});
        return SQLiteError.PathResolutionFailed;
    };
    defer std.heap.page_allocator.free(full_path);

    // Delete existing database if it exists
    std.fs.cwd().deleteFile(full_path) catch {};

    // Open database
    var db: ?*c.sqlite3 = null;
    const result = c.sqlite3_open(full_path.ptr, &db);
    if (result != c.SQLITE_OK) {
        std.debug.print("Error: Failed to open/create database: {s}\n", .{full_path});
        if (db) |d| {
            const errmsg = c.sqlite3_errmsg(d);
            std.debug.print("SQLite error: {s}\n", .{std.mem.span(errmsg)});
        }
        return SQLiteError.DatabaseOpenFailed;
    }
    defer _ = c.sqlite3_close(db);

    // Create tables
    try createTables(db.?);

    // Write data
    try writeOrders(db.?, om);
    try writeFills(db.?, fm);
    try writePositions(db.?, pm);
}

fn createTables(db: *c.sqlite3) SQLiteError!void {
    const orders_table =
        \\CREATE TABLE orders (
        \\  order_id INTEGER PRIMARY KEY,
        \\  iter INTEGER NOT NULL,
        \\  timestamp INTEGER NOT NULL,
        \\  type TEXT NOT NULL,
        \\  side TEXT NOT NULL,
        \\  price REAL NOT NULL,
        \\  volume REAL NOT NULL,
        \\  status TEXT NOT NULL
        \\);
    ;

    const fills_table =
        \\CREATE TABLE fills (
        \\  fill_id INTEGER PRIMARY KEY AUTOINCREMENT,
        \\  order_id INTEGER NOT NULL,
        \\  iter INTEGER NOT NULL,
        \\  timestamp INTEGER NOT NULL,
        \\  side TEXT NOT NULL,
        \\  price REAL NOT NULL,
        \\  volume REAL NOT NULL,
        \\  FOREIGN KEY (order_id) REFERENCES orders(order_id)
        \\);
    ;

    const positions_table =
        \\CREATE TABLE positions (
        \\  position_id INTEGER PRIMARY KEY AUTOINCREMENT,
        \\  side TEXT NOT NULL,
        \\  open_timestamp INTEGER,
        \\  close_timestamp INTEGER,
        \\  avg_entry_price REAL NOT NULL,
        \\  volume REAL NOT NULL
        \\);
    ;

    var err: [*c]u8 = null;
    
    if (c.sqlite3_exec(db, orders_table.ptr, null, null, &err) != c.SQLITE_OK) {
        return SQLiteError.TableCreationFailed;
    }
    
    if (c.sqlite3_exec(db, fills_table.ptr, null, null, &err) != c.SQLITE_OK) {
        return SQLiteError.TableCreationFailed;
    }
    
    if (c.sqlite3_exec(db, positions_table.ptr, null, null, &err) != c.SQLITE_OK) {
        return SQLiteError.TableCreationFailed;
    }
}

fn writeOrders(db: *c.sqlite3, om: *OrderManager) SQLiteError!void {
    _ = c.sqlite3_exec(db, "BEGIN TRANSACTION;", null, null, null);
    defer _ = c.sqlite3_exec(db, "COMMIT;", null, null, null);

    const insert_sql =
        \\INSERT INTO orders (order_id, iter, timestamp, type, side, price, volume, status)
        \\VALUES (?, ?, ?, ?, ?, ?, ?, ?);
    ;

    var stmt: ?*c.sqlite3_stmt = null;
    if (c.sqlite3_prepare_v2(db, insert_sql.ptr, -1, &stmt, null) != c.SQLITE_OK) {
        return SQLiteError.PrepareStatementFailed;
    }
    defer _ = c.sqlite3_finalize(stmt);

    for (om.orders.items) |order| {
        // Determine order status
        const status: []const u8 = blk: {
            // Check if order is in working orders
            for (om.orders_working.items) |idx| {
                if (om.orders.items[idx].id == order.id) {
                    break :blk "working";
                }
            }
            // Check if order is in canceled orders
            for (om.orders_canceled.items) |idx| {
                if (om.orders.items[idx].id == order.id) {
                    break :blk "canceled";
                }
            }
            // Otherwise it's filled
            break :blk "filled";
        };

        const type_str: []const u8 = switch (order.type) {
            .Market => "Market",
            .Stop => "Stop",
            .Limit => "Limit",
        };

        const side_str: []const u8 = switch (order.side) {
            .Buy => "Buy",
            .Sell => "Sell",
        };

        _ = c.sqlite3_bind_int64(stmt, 1, @intCast(order.id));
        _ = c.sqlite3_bind_int64(stmt, 2, @intCast(order.iter));
        _ = c.sqlite3_bind_int64(stmt, 3, @intCast(order.timestamp));
        _ = c.sqlite3_bind_text(stmt, 4, type_str.ptr, @intCast(type_str.len), null);
        _ = c.sqlite3_bind_text(stmt, 5, side_str.ptr, @intCast(side_str.len), null);
        _ = c.sqlite3_bind_double(stmt, 6, order.price);
        _ = c.sqlite3_bind_double(stmt, 7, order.volume);
        _ = c.sqlite3_bind_text(stmt, 8, status.ptr, @intCast(status.len), null);

        if (c.sqlite3_step(stmt) != c.SQLITE_DONE) {
            return SQLiteError.InsertFailed;
        }

        _ = c.sqlite3_reset(stmt);
    }
}

fn writeFills(db: *c.sqlite3, fm: *FillManager) SQLiteError!void {
    _ = c.sqlite3_exec(db, "BEGIN TRANSACTION;", null, null, null);
    defer _ = c.sqlite3_exec(db, "COMMIT;", null, null, null);

    const insert_sql =
        \\INSERT INTO fills (order_id, iter, timestamp, side, price, volume)
        \\VALUES (?, ?, ?, ?, ?, ?);
    ;

    var stmt: ?*c.sqlite3_stmt = null;
    if (c.sqlite3_prepare_v2(db, insert_sql.ptr, -1, &stmt, null) != c.SQLITE_OK) {
        return SQLiteError.PrepareStatementFailed;
    }
    defer _ = c.sqlite3_finalize(stmt);

    for (fm.fills.items) |fill| {
        const side_str: []const u8 = switch (fill.side) {
            .Buy => "Buy",
            .Sell => "Sell",
        };

        _ = c.sqlite3_bind_int64(stmt, 1, @intCast(fill.order_id));
        _ = c.sqlite3_bind_int64(stmt, 2, @intCast(fill.iter));
        _ = c.sqlite3_bind_int64(stmt, 3, @intCast(fill.timestamp));
        _ = c.sqlite3_bind_text(stmt, 4, side_str.ptr, @intCast(side_str.len), null);
        _ = c.sqlite3_bind_double(stmt, 5, fill.price);
        _ = c.sqlite3_bind_double(stmt, 6, fill.volume);

        if (c.sqlite3_step(stmt) != c.SQLITE_DONE) {
            return SQLiteError.InsertFailed;
        }

        _ = c.sqlite3_reset(stmt);
    }
}

fn writePositions(db: *c.sqlite3, pm: *PositionManager) SQLiteError!void {
    _ = c.sqlite3_exec(db, "BEGIN TRANSACTION;", null, null, null);
    defer _ = c.sqlite3_exec(db, "COMMIT;", null, null, null);

    const insert_sql =
        \\INSERT INTO positions (side, open_timestamp, close_timestamp, avg_entry_price, volume)
        \\VALUES (?, ?, ?, ?, ?);
    ;

    var stmt: ?*c.sqlite3_stmt = null;
    if (c.sqlite3_prepare_v2(db, insert_sql.ptr, -1, &stmt, null) != c.SQLITE_OK) {
        return SQLiteError.PrepareStatementFailed;
    }
    defer _ = c.sqlite3_finalize(stmt);

    for (pm.positions.items) |position| {
        const side_str: []const u8 = switch (position.side) {
            .Buy => "Long",
            .Sell => "Short",
        };

        // Calculate average entry price from in_fills
        var total_value: f64 = 0;
        var total_volume: f64 = 0;
        for (position.in_fills.items) |fill| {
            total_value += fill.price * fill.volume;
            total_volume += fill.volume;
        }
        const avg_price = if (total_volume > 0) total_value / total_volume else 0;

        // Get timestamps from fills
        const open_ts = if (position.in_fills.items.len > 0) 
            position.in_fills.items[0].timestamp 
        else 
            0;
        
        const close_ts = if (position.out_fills.items.len > 0) 
            position.out_fills.items[position.out_fills.items.len - 1].timestamp 
        else 
            null;

        _ = c.sqlite3_bind_text(stmt, 1, side_str.ptr, @intCast(side_str.len), null);
        _ = c.sqlite3_bind_int64(stmt, 2, @intCast(open_ts));
        if (close_ts) |ts| {
            _ = c.sqlite3_bind_int64(stmt, 3, @intCast(ts));
        } else {
            _ = c.sqlite3_bind_null(stmt, 3);
        }
        _ = c.sqlite3_bind_double(stmt, 4, avg_price);
        _ = c.sqlite3_bind_double(stmt, 5, total_volume);

        if (c.sqlite3_step(stmt) != c.SQLITE_DONE) {
            return SQLiteError.InsertFailed;
        }

        _ = c.sqlite3_reset(stmt);
    }
}


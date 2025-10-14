// This module wraps SQLite so the rest of the project
// can use clean Zig functions to open, query, close the DB.

const std = @import("std");
const types = @import("types.zig");

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

pub fn query(db: *anyopaque, com: []const u8, debug: bool) !void {
  var timer: ?std.time.Timer = null;
  if (debug) timer = try std.time.Timer.start();

  const c_sql = try std.heap.c_allocator.dupeZ(u8, com);
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
    
  while (sqlite3_step(stmt.?) == 100) {
    const symbol_ptr = sqlite3_column_text(stmt.?, 0); 
    const close_value = sqlite3_column_double(stmt.?, 1);

    const symbol = std.mem.span(symbol_ptr);
    std.debug.print("{s}: {d:.2}\n", .{ symbol, close_value});
  }

  _ = sqlite3_finalize(stmt.?);

  if (debug) {
    const elapsed_ns = timer.?.read();
    const ms = @as(f64, @floatFromInt(elapsed_ns)) / 1_000_000.0;
    std.debug.print("Query time: {d:.3} ms\n", .{ms});
  }
}

pub fn loadSeries(db: *anyopaque, table_name: []const u8, limit: usize, allocator: std.mem.Allocator) !types.Series {
  var buf: [128]u8 = undefined;
  const sql = try std.fmt.bufPrint(
    &buf,
    "SELECT timestamp, open, high, low, close, volume FROM {s} ORDER BY timestamp DESC LIMIT {d};",
    .{ table_name, limit },
  );
  std.debug.print("Executing SQL: {s}\n", .{sql});
  const c_sql = try std.heap.c_allocator.dupeZ(u8, sql);
  defer std.heap.c_allocator.free(c_sql);
  
  var stmt: ?*anyopaque = null;
  var tail: ?*[*:0]const u8 = null;
  const rc = sqlite3_prepare_v2(db, c_sql, -1, &stmt, &tail);

  if (rc != 0) {
    std.debug.print("Failed to prepare: {s}\n", .{table_name});
    const errmsg = sqlite3_errmsg(db);
    std.debug.print("SQLite error: {s}\n", .{std.mem.span(errmsg)});
    return error.PrepareFailed;
  }

  var points = try allocator.alloc(types.Point, limit);
  var count: usize = 0;

  while (sqlite3_step(stmt.?) == 100) {
    if (count >= limit) break;

    const ts: i64 = @intFromFloat(sqlite3_column_double(stmt.?, 0));
    const op = sqlite3_column_double(stmt.?, 1);
    const hi = sqlite3_column_double(stmt.?, 2);
    const lo = sqlite3_column_double(stmt.?, 3);
    const cl = sqlite3_column_double(stmt.?, 4);
    const vo: i64 = @intFromFloat(sqlite3_column_double(stmt.?, 5));

    points[count] = types.Point{
      .timestamp = ts,
      .op = op,
      .hi = hi,
      .lo = lo,
      .cl = cl,
      .vo = vo,
    };

    count += 1;
  }

  _ = sqlite3_finalize(stmt.?);

  return types.Series{
    .points = points[0..count],
    .count = count,
    .table_name = table_name,
  };
}

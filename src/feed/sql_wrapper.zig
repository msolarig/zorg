const std = @import("std");
const Track = @import("track.zig").Track;

extern fn sqlite3_open(filename: [*:0]const u8, db: *?*anyopaque) c_int;
extern fn sqlite3_close(db: *anyopaque) c_int;
extern fn sqlite3_prepare_v2(db: *anyopaque, sql: [*:0]const u8, nByte: c_int, stmt: *?*anyopaque, tail: *?*[*:0]const u8) c_int;
extern fn sqlite3_step(stmt: *anyopaque) c_int;
extern fn sqlite3_finalize(stmt: *anyopaque) c_int;
extern fn sqlite3_column_text(stmt: *anyopaque, col: c_int) [*:0]const u8;
extern fn sqlite3_column_double(stmt: *anyopaque, col: c_int) f64;
extern fn sqlite3_errmsg(db: *anyopaque) [*:0]const u8;

// ---------------------------------------------------------------------
// Database Interaction File
// Integration and wraping of SQLite funtions (imported from C modules)
// ---------------------------------------------------------------------

pub fn openDB(path: []const u8) !*anyopaque {
  var db_handle: ?*anyopaque = null;

  const c_path = try std.heap.c_allocator.dupeZ(u8, path);
  defer std.heap.c_allocator.free(c_path);
  const open = sqlite3_open(c_path, &db_handle);

  if(open != 0) {
    std.debug.print("Failed to open DB\n", .{});
    return error.OpenFailed;
  }

  std.debug.print("Opened DB successfully\n", .{});
  return db_handle.?;
}

pub fn closeDB(db_handle: *anyopaque) !void {
  const close = sqlite3_close(db_handle);
  
  if (close != 0) {
    std.debug.print("Failed to close DB\n", .{});
    return error.CloseFailed;
  }

  std.debug.print("Closed DB successfully\n", .{});
}

// Executes SQL command in given database (steps per each row)
pub fn query(db: *anyopaque, com: []const u8) !void {
  const c_sql = try std.heap.c_allocator.dupeZ(u8, com);
  defer std.heap.c_allocator.free(c_sql);

  var stmt: ?*anyopaque = null;
  var tail: ?*[*:0]const u8 = null;
  const prepare = sqlite3_prepare_v2(db, c_sql, -1, &stmt, &tail);

  if (prepare != 0) {
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
}

pub fn loadTrack(alloc: std.mem.Allocator, db_handle: *anyopaque, 
                 table_name: []const u8, start_ts: u64, end_ts: u64) !Track {

  const command: []const u8 = try std.fmt.allocPrint(
    alloc,
    "SELECT timestamp, open, high, low, close, volume FROM {s}",
    .{table_name});
  const c_command = try std.heap.c_allocator.dupeZ(u8, command);
  defer std.heap.c_allocator.free(c_command);
  defer alloc.free(command);

  var stmt: ?*anyopaque = null;
  var tail: ?*[*:0]const u8 = null;
  const prepare = sqlite3_prepare_v2(db_handle, c_command, -1, &stmt, &tail);

  if (prepare != 0) {
    const errmsg = sqlite3_errmsg(db_handle);
    const msg = std.mem.span(errmsg);
    std.debug.print("SQLite prepare error: {s}\n", .{msg});
    return error.PrepareFailed;
  }

  var track = Track.init();

  while (sqlite3_step(stmt.?) == 100) {
    const timestamp: u64 = @intFromFloat(sqlite3_column_double(stmt.?, 0));
    // Non-inclusive bounds
    if (timestamp > start_ts and timestamp < end_ts) {
      const open = sqlite3_column_double(stmt.?, 1);
      const high = sqlite3_column_double(stmt.?, 2);
      const low = sqlite3_column_double(stmt.?, 3);
      const close = sqlite3_column_double(stmt.?, 4);
      const volume: u64 = @intFromFloat(sqlite3_column_double(stmt.?, 5));
      try track.addRow(alloc, timestamp, open, high, low, close, volume);
    }
  }
  _ = sqlite3_finalize(stmt.?);
  return track;
}

const std = @import("std");

// Extern SQLite3 function declarations -----------------------------------------------------------
extern fn sqlite3_open(filename: [*:0]const u8, db: *?*anyopaque) c_int;
extern fn sqlite3_close(db: *anyopaque) c_int;
pub extern fn sqlite3_prepare_v2(db: *anyopaque, sql: [*:0]const u8, nByte: c_int, stmt: *?*anyopaque, tail: *?*[*:0]const u8) c_int;
pub extern fn sqlite3_step(stmt: *anyopaque) c_int;
pub extern fn sqlite3_finalize(stmt: *anyopaque) c_int;
pub extern fn sqlite3_column_text(stmt: *anyopaque, col: c_int) [*:0]const u8;
pub extern fn sqlite3_column_double(stmt: *anyopaque, col: c_int) f64;
pub extern fn sqlite3_errmsg(db: *anyopaque) [*:0]const u8;
// ------------------------------------------------------------------------------------------------

const DataBaseError = error{
    FailedToOpen,
    FailedToClose,
};

/// Open Database - SQLite3 Wrapper 
pub fn openDB(path: []const u8) !*anyopaque {
  var db_handle: ?*anyopaque = null;
  const c_path = try std.heap.c_allocator.dupeZ(u8, path);
  defer std.heap.c_allocator.free(c_path);
  const open = sqlite3_open(c_path, &db_handle);

  if(open != 0) {
    return DataBaseError.FailedToOpen;
  }
  return db_handle.?;
}

/// Close Database - SQLite3 Wrapper 
pub fn closeDB(db_handle: *anyopaque) !void {
  const close = sqlite3_close(db_handle);

  if (close != 0) {
    return DataBaseError.FailedToClose;
  }
}

const std = @import("std");
const db = @import("db_wrap.zig");

/// Process Historical Database
///   Engine reads a DB, t0, and tn from its map. Loads a Track with
///   a separate arraylist for each data component from t0 through tn. 
///   Allows for access to desired historical feed in a local data structure.
pub const Track = struct {
  size: u64,
  ts: std.ArrayListUnmanaged(u64),
  op: std.ArrayListUnmanaged(f64),
  hi: std.ArrayListUnmanaged(f64),
  lo: std.ArrayListUnmanaged(f64),
  cl: std.ArrayListUnmanaged(f64),
  vo: std.ArrayListUnmanaged(u64),

  /// Initialize an empty Track instance
  ///   Generate size and six empty arraylist fields for timestamp, OHLCV values.
  pub fn init() Track {
    return Track{
      .size = 0,
      .ts = .{},
      .op = .{},
      .hi = .{},
      .lo = .{},
      .cl = .{},
      .vo = .{},
      };
    }

  /// Load an empty Track with db_handle data form t0 to tn
  ///   Generates a SQLite3 query, iterates through specifies row range, appends each 
  ///   data point to their respecitve arraylist while keeping a common index per data point.
  pub fn load(self: *Track, alloc: std.mem.Allocator, db_handle: *anyopaque, 
              table: []const u8, t0: u64, tn: u64) !void {

    const query: []const u8 = "SELECT timestamp, open, high, low, close, volume FROM {s}";
    const command: []const u8 = try std.fmt.allocPrint(alloc, query, .{table});
    const c_command = try std.heap.c_allocator.dupeZ(u8, command);
    defer std.heap.c_allocator.free(c_command);
    defer alloc.free(command);

    var stmt: ?*anyopaque = null;
    var tail: ?*[*:0]const u8 = null;
    const prepare = db.sqlite3_prepare_v2(db_handle, c_command, -1, &stmt, &tail);

    if (prepare != 0) {
      const errmsg = db.sqlite3_errmsg(db_handle);
      const msg = std.mem.span(errmsg);
      std.debug.print("SQLite prepare error: {s}\n", .{msg});
      return error.PrepareFailed;
    }

    while (db.sqlite3_step(stmt.?) == 100) {
      const ts: u64 = @intFromFloat(db.sqlite3_column_double(stmt.?, 0));
      if (ts > t0 and ts < tn) { // Non-inclusive
        const op = db.sqlite3_column_double(stmt.?, 1);
        const hi = db.sqlite3_column_double(stmt.?, 2);
        const lo = db.sqlite3_column_double(stmt.?, 3);
        const cl = db.sqlite3_column_double(stmt.?, 4);
        const vo: u64 = @intFromFloat(db.sqlite3_column_double(stmt.?, 5));
    
        try self.ts.append(alloc, ts);
        try self.op.append(alloc, op);
        try self.hi.append(alloc, hi);
        try self.lo.append(alloc, lo);
        try self.cl.append(alloc, cl);
        try self.vo.append(alloc, vo);
        self.size += 1;
      }
    }
    _ = db.sqlite3_finalize(stmt.?);
  }

  /// Deinitalize Track Instance
  ///   Frees ts, op, hi, lo, cl, vo arraylists.
  pub fn deinit(self: *Track, alloc: std.mem.Allocator) void {
    self.ts.deinit(alloc);
    self.op.deinit(alloc);
    self.hi.deinit(alloc);
    self.lo.deinit(alloc);
    self.cl.deinit(alloc);
    self.vo.deinit(alloc);
  }
};

const std = @import("std");
const db = @import("sql_wrap.zig");
const abi = @import("../auto/abi.zig");

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
  ///   Generates a SQLite3 query, iterates through specified row range, appends each 
  ///   data point to their respecitve arraylist while keeping a common index per data point.
  ///   The generated query specifies to traverse the db in reverse, assigning the most recent
  ///   value to the lowest index: Track.ts.items[0] = most recent timestamp.
  pub fn load(self: *Track, alloc: std.mem.Allocator, db_handle: *anyopaque, 
              table: []const u8, t0: u64, tn: u64) !void {

    const query: []const u8 = "SELECT timestamp, open, high, low, close, volume FROM {s} ORDER BY timestamp DESC";
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

/// Track Dynamic Window
///   The Trail serves as a shifting view into the loaded Track. Its purpose is to facilitate 
///   "relative-to-its-position" data access to the auto when executing (iterating through Track).
pub const Trail = struct {
  size: usize,
  ts: []u64,
  op: []f64,
  hi: []f64,
  lo: []f64,
  cl: []f64,
  vo: []u64,   

  /// Initialize Trail instance
  ///   Generates empty Trail with size and six empty [size]arrays field for timestamp, OHLCV values.
  pub fn init(alloc: std.mem.Allocator, size: usize) !Trail {
    return Trail {
      .size = size,
      .ts = try alloc.alloc(u64, size),
      .op = try alloc.alloc(f64, size),
      .hi = try alloc.alloc(f64, size),
      .lo = try alloc.alloc(f64, size),
      .cl = try alloc.alloc(f64, size),
      .vo = try alloc.alloc(u64, size),
    };
  } 

  /// Load an empty Trail with the most recent 'size' data points
  ///   Distributed into their respective arrays, these values are designed to shift as the auto 
  ///   iterates throught the Track. Values are accessible as 'trail'.ts[0] = most recent timestamp.
  pub fn load(self: *Trail, track: Track, steps: u64) !void {
    var trail_index: u64 = 0;
    var track_index: u64 = track.ts.items.len - (steps + 1); 
    while (trail_index < self.size) : (track_index -= 1) {
      self.ts[trail_index] = track.ts.items[track_index];
      self.op[trail_index] = track.op.items[track_index];
      self.hi[trail_index] = track.hi.items[track_index];
      self.lo[trail_index] = track.lo.items[track_index];
      self.cl[trail_index] = track.cl.items[track_index];
      self.vo[trail_index] = track.vo.items[track_index];
      trail_index += 1;

      if (track_index == 0)
        break;
    }
  }

  /// Cast a Trail instance into a C ABI readable struct
  pub fn toABI(self: *Trail) abi.TrailABI {
    return abi.TrailABI {
      .ts = self.ts.ptr,
      .op = self.op.ptr,
      .hi = self.hi.ptr,
      .lo = self.lo.ptr,
      .cl = self.cl.ptr,
      .vo = self.vo.ptr,
    };
  }

  /// Deinitialize Trail instance
  ///   Frees ts, op, hi, lo, cl, vo arrays.
  pub fn deinit(self: *Trail, alloc: std.mem.Allocator) void {
    alloc.free(self.ts);
    alloc.free(self.op);
    alloc.free(self.hi);
    alloc.free(self.lo);
    alloc.free(self.cl);
    alloc.free(self.vo);
  }
};

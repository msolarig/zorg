const std = @import("std");
const Track = @import("track.zig").Track;

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
    }
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

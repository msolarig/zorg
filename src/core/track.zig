const std = @import("std");

pub const Track = struct {
  size: usize,
  ts: []i64,
  op: []f64,
  hi: []f64,
  lo: []f64,
  cl: []f64,
  vo: []i64,

  pub fn getClose(self: Track, i: usize) f64 {
    if (i >= self.size) return 0.0;
    return self.cl[i];
  }

  pub fn getOpen(self: Track, i: usize) f64 {
    if (i >= self.size) return 0.0;
    return self.op[i];
  }

  pub fn getHigh(self: Track, i: usize) f64 {
    if (i >= self.size) return 0.0;
    return self.hi[i];
  }

  pub fn getLow(self: Track, i: usize) f64 {
    if (i >= self.size) return 0.0;
    return self.lo[i];
  }

  pub fn getVolume(self: Track, i: usize) i64 {
    if (i >= self.size) return 0;
    return self.vo[i];
  }

  pub fn deinit(self: *Track, allocator: std.mem.Allocator) void {
    allocator.free(self.ts);
    allocator.free(self.op);
    allocator.free(self.hi);
    allocator.free(self.lo);
    allocator.free(self.cl);
    allocator.free(self.vo);
  }
};

const std = @import("std");

pub const Track = struct {
  ts: std.ArrayListUnmanaged(u64),
  op: std.ArrayListUnmanaged(f64),
  hi: std.ArrayListUnmanaged(f64),
  lo: std.ArrayListUnmanaged(f64),
  cl: std.ArrayListUnmanaged(f64),
  vo: std.ArrayListUnmanaged(u64),

  pub fn init() Track {
    return Track{
      .ts = .{},
      .op = .{},
      .hi = .{},
      .lo = .{},
      .cl = .{},
      .vo = .{},
      };
    }

  pub fn addRow(self: *Track, alloc: std.mem.Allocator,
  ts: u64, op: f64, hi: f64, lo: f64, cl: f64, vo: u64) !void {
    try self.ts.append(alloc, ts);
    try self.op.append(alloc, op);
    try self.hi.append(alloc, hi);
    try self.lo.append(alloc, lo);
    try self.cl.append(alloc, cl);
    try self.vo.append(alloc, vo);
  }

  pub fn deinit(self: *Track, alloc: std.mem.Allocator) void {
    self.ts.deinit(alloc);
    self.op.deinit(alloc);
    self.hi.deinit(alloc);
    self.lo.deinit(alloc);
    self.cl.deinit(alloc);
    self.vo.deinit(alloc);
  }
};

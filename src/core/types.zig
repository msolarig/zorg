const std = @import("std");

pub const Point = struct {
  timestamp: i64,
  op: f64,
  hi: f64,
  lo: f64,
  cl: f64,
  vo: i64,

  pub fn debugPrint(self: Point) void {
    std.debug.print(
      "ts: {d}, O: {d}, H: {d}, L: {d}, C: {d}, V: {d}\n",
      .{ self.timestamp, self.op, self.hi, self.lo, self.cl, self.vo },
    );
  }
};

pub const Series = struct {
  points: []Point,
  count: usize,
  table_name: []const u8,

  pub fn debugPrint(self: Series) void {
    std.debug.print("--- Series: {s} ---\n", .{ self.table_name });
    for (self.points, 0..) |p, i| {
      std.debug.print("#{d} ", .{ i });
      p.debugPrint();
    }
  }

  pub fn last(self: Series) ?Point {
    if (self.count == 0) return null;
    return self.points[0];
  }

  pub fn at(self: Series, i: usize) ?Point {
    if (i >= self.count) return null;
    return self.points[i];
  }
};

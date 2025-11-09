const std = @import("std");
const data = @import("feed/sql_wrapper.zig");
const Track = @import("feed/track.zig").Track;

pub fn main() !void {
  // Main program allocator
  var gpa = std.heap.GeneralPurposeAllocator(.{}){};
  defer _ = gpa.deinit();
  const alloc = gpa.allocator();

  const handle: *anyopaque = try data.openDB("data/market.db");

  var test_track: Track = try data.loadTrack(
    alloc, handle, "AJG_1D", 1704153600, 1707350400);
  defer test_track.deinit(alloc);

  if (test_track.op.items.len > 0) {
      std.debug.print("{any}\n", .{ test_track.op.items[0] });
  }

  try data.closeDB(handle);
}


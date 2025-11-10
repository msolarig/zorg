const std    = @import("std");
const db     = @import("feed/sql_wrapper.zig");
const Track  = @import("feed/track.zig").Track;
const Trail  = @import("feed/trail.zig").Trail;
const Engine = @import("engine/engine.zig").Engine;
const Map    = @import("engine/map.zig").Map;

pub fn main() !void {
  // Main program allocator
  var gpa = std.heap.GeneralPurposeAllocator(.{}){};
  defer _ = gpa.deinit();
  const alloc = gpa.allocator();

  // open db
  const handle: *anyopaque = try db.openDB("data/market.db");

  // Track setup code
  var test_track: Track = Track.init();
  defer test_track.deinit(alloc);
  try test_track.load(alloc, handle, "AJG_1D", 1704153600, 1707350400);
  
  std.debug.print("{any}\n", .{ test_track.op.items[0] });

  // close db
  try db.closeDB(handle);

  //
  // TRAIL TESTS
  // A loaded track is required to instanciate any trail
  
  std.debug.print("\n", .{});

  var test_trail: Trail = try Trail.init(alloc, 5);
  try test_trail.load(test_track, 0);
  defer test_trail.deinit(alloc);

  std.debug.print("trail most recent, Close[0]:  {d}\n", .{test_trail.cl[0]});
  std.debug.print("trail length:  {d}\n", .{test_trail.size});

  std.debug.print("track least recent Close[-1]: {d}\n", .{test_track.cl.items[test_track.size - 1]});
  std.debug.print("trail length:  {d}\n", .{test_track.size});

  //
  // ENGINE Tests
  //

  std.debug.print("\n", .{});
  
  var test_engine: Engine = try Engine.init(alloc, "usr/maps/test_map.json");
  defer test_engine.deinit();

  std.debug.print("{s}\n", .{test_engine.map.auto});
  std.debug.print("{s}\n", .{test_engine.map.db});
  std.debug.print("{s}\n", .{test_engine.map.table});
  std.debug.print("{d}\n", .{test_engine.map.t0});
  std.debug.print("{d}\n", .{test_engine.map.tn});
  std.debug.print("{any}\n", .{test_engine.map.mode});
}

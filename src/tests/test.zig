const std    = @import("std");
const db     = @import("../feed/sql_wrapper.zig");
const Track  = @import("../feed/track.zig").Track;
const Trail  = @import("../feed/trail.zig").Trail;
const Engine = @import("../engine/engine.zig").Engine;
const Map    = @import("../engine/map.zig").Map;

test "TRACK_TESTS" {

  var gpa = std.heap.GeneralPurposeAllocator(.{}){};
  defer _ = gpa.deinit();
  const alloc = gpa.allocator();

  const mono_table_test_db_handle = try db.openDB("src/tests/test_feeds/mono_table_test.db");
  const multi_table_test_db_handle = try db.openDB("src/tests/test_feeds/mono_table_test.db");
  const instrument_test_db_handle = try db.openDB("src/tests/test_feeds/mono_table_test.db");

  var mono_table_test_db_track: Track = Track.init();
  defer mono_table_test_db_track.deinit(alloc);
  try mono_table_test_db_track.load(alloc, mono_table_test_db_handle, "AAPL_1D", 0, 2_000_000_000);
  
  var multi_table_test_db_track: Track = Track.init();
  defer multi_table_test_db_track.deinit(alloc);
  try multi_table_test_db_track.load(alloc, multi_table_test_db_handle, "AAPL_1D", 0, 2_000_000_000);

  var instrument_test_db_track: Track = Track.init();
  defer instrument_test_db_track.deinit(alloc);
  try instrument_test_db_track.load(alloc, instrument_test_db_handle, "AAPL_1D", 0, 2_000_000_000);

  //
  // ASSERTIONS
  //
  
  try std.testing.expectEqual(mono_table_test_db_track.size, 6288);
  try std.testing.expectEqual(mono_table_test_db_track.ts.items[0], 946857600);
  try std.testing.expectEqual(mono_table_test_db_track.op.items[0], 0.7870901168329728);
  try std.testing.expectEqual(mono_table_test_db_track.hi.items[0], 0.8443156783566781);
  try std.testing.expectEqual(mono_table_test_db_track.lo.items[0], 0.7631676614192741);
  try std.testing.expectEqual(mono_table_test_db_track.cl.items[0], 0.8400943279266357);
  try std.testing.expectEqual(mono_table_test_db_track.vo.items[0], 535796800);

  //
  // CLOSING DBs
  //

  try db.closeDB(mono_table_test_db_handle);
  try db.closeDB(multi_table_test_db_handle);
  try db.closeDB(instrument_test_db_handle);
}

// TODO: trail, engine setup 

test "TRAIL_TESTS" {

}

test "ENGINE_TESTS" {

}

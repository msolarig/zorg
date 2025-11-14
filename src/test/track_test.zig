const std    = @import("std");
const db     = @import("../engine/data/sql_wrap.zig");
const Track  = @import("../engine/data/local_data.zig").Track;

test "MONO_TABLE_DB_TRACK_TESTS" {

  var gpa = std.heap.GeneralPurposeAllocator(.{}){};
  defer _ = gpa.deinit();
  const alloc = gpa.allocator();

  const mono_table_test_db_handle = try db.openDB("test/test_feeds/mono_table_test.db");

  var mono_table_test_db_track: Track = Track.init();
  defer mono_table_test_db_track.deinit(alloc);
  try mono_table_test_db_track.load(alloc, mono_table_test_db_handle, "AAPL_1D", 0, 1_735_516_801);
  
  const ts = mono_table_test_db_track.ts.items;
  const op = mono_table_test_db_track.op.items;
  const hi = mono_table_test_db_track.hi.items;
  const lo = mono_table_test_db_track.lo.items;
  const cl = mono_table_test_db_track.cl.items;
  const vo = mono_table_test_db_track.vo.items;
  
  try std.testing.expectEqual(mono_table_test_db_track.size, 6288);

  try std.testing.expectEqual(ts[0], 946857600);
  try std.testing.expectEqual(op[0], 0.7870901168329728);
  try std.testing.expectEqual(hi[0], 0.8443156783566781);
  try std.testing.expectEqual(lo[0], 0.7631676614192741);
  try std.testing.expectEqual(cl[0], 0.8400943279266357);
  try std.testing.expectEqual(vo[0], 535796800);

  try std.testing.expectEqual(ts[ts.len - 1], 1735516800);
  try std.testing.expectEqual(op[op.len - 1], 251.33775398934142);
  try std.testing.expectEqual(hi[hi.len - 1], 252.60326573181473);
  try std.testing.expectEqual(lo[lo.len - 1], 249.86299361835324);
  try std.testing.expectEqual(cl[cl.len - 1], 251.307861328125);
  try std.testing.expectEqual(vo[vo.len - 1], 35557500);

  try db.closeDB(mono_table_test_db_handle);
}

test "MULTI_TABLE_DB_TRACK_TESTS" {

  var gpa = std.heap.GeneralPurposeAllocator(.{}){};
  defer _ = gpa.deinit();
  const alloc = gpa.allocator();

  const multi_table_test_db_handle = try db.openDB("test/test_feeds/mono_table_test.db");

  var multi_table_test_db_track: Track = Track.init();
  defer multi_table_test_db_track.deinit(alloc);
  try multi_table_test_db_track.load(alloc, multi_table_test_db_handle, "AAPL_1D", 0, 2_000_000_000);

  //
  // ASSERTIONS
  //

  try db.closeDB(multi_table_test_db_handle);
}

test "INSTRUMENT_TYPE_TRACK_TESTS" {

  var gpa = std.heap.GeneralPurposeAllocator(.{}){};
  defer _ = gpa.deinit();
  const alloc = gpa.allocator();

  const instrument_test_db_handle = try db.openDB("test/test_feeds/mono_table_test.db");

  var instrument_test_db_track: Track = Track.init();
  defer instrument_test_db_track.deinit(alloc);
  try instrument_test_db_track.load(alloc, instrument_test_db_handle, "AAPL_1D", 0, 2_000_000_000);

  //
  // ASSERTIONS
  //

  try db.closeDB(instrument_test_db_handle);
}

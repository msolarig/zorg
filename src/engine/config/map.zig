const std = @import("std");
const db = @import("../data/db_wrap.zig");
const path_util = @import("../../utils/path.zig");

/// Data Feed Mode
///  defines whether the engine works based on historical data or a live
///  feed of real-time data.
const FeedMode = enum {
  DB,
  Live
};

/// Process Execution Mode
///   defines the type of process the engine must run. Changing this will
///   affect how inputs are used and output is provided.
const ExecMode = enum {
  LiveExecution,
  Backtest,
  Optimization,
};

/// Engine Map (Configuration File)
///   provides required information for system to locate and load inputs
///   as well as instructions for process & execution.
pub const Map = struct {
  alloc: std.mem.Allocator,
  auto: []const u8,
  feed_mode: FeedMode,
  db: []const u8,
  table: []const u8,
  t0: u64,
  tn: u64,
  trail_size: u64,
  exec_mode: ExecMode,

  /// Initialize a map instance
  ///   Decode a map.json into a Map struct, usable by an Engine.
  pub fn init(alloc: std.mem.Allocator, map_path: []const u8) !Map {

    const file = try std.fs.cwd().openFile(map_path, .{});
    defer file.close();
    const json_bytes: []const u8 = try file.readToEndAlloc(alloc, std.math.maxInt(usize));
    defer alloc.free(json_bytes);

    const MapPlaceHolder = struct {
      auto: []const u8, feed_mode: FeedMode, db: []const u8, table: []const u8, 
      t0: u64, tn: u64, trail_size: u64, exec_mode: ExecMode,};

    var parsed_map = try std.json.parseFromSlice(MapPlaceHolder, alloc, json_bytes, .{});
    defer parsed_map.deinit();

    return Map{
      .alloc = alloc,
      .auto  = try path_util.autoSrcRelPathToCompiledAbsPath(alloc, parsed_map.value.auto),
      .feed_mode = parsed_map.value.feed_mode,
      .db    = try path_util.dbRelPathToAbsPath(alloc, parsed_map.value.db),
      .table = try alloc.dupe(u8, parsed_map.value.table),
      .t0 = parsed_map.value.t0,
      .tn = parsed_map.value.tn,
      .trail_size = parsed_map.value.trail_size,
      .exec_mode = parsed_map.value.exec_mode,
    };
  }

  /// Deinitialize map instance
  pub fn deinit(self: *Map) void {
    self.alloc.free(self.auto);
    self.alloc.free(self.db);
    self.alloc.free(self.table);
  }
};

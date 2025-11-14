const std = @import("std");
const db = @import("../data/sql_wrap.zig");
const path_util = @import("../../utils/path_converter.zig");

/// Data Feed Mode
///  defines whether an Engine works based on historical data or a live
///  feed of real-time data.
const FeedMode = enum {
  Live, SQLite3
};

/// Process Execution Mode
///   defines the type of process the Engine must run. Changing this will
///   affect how inputs are used and output is provided.
const ExecMode = enum {
  LiveExecution, Backtest, Optimization
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

  // Very minimal and disorganized error implementation so far, need to work further on good,
  // descriptive error.
  const MapError = error{
    MapFileNotFound,
    MapInvalidJson,
    MapInvalidFormat,
    AutoFileNotFound,
    DatabaseFileNotFound,
    TableNotFound,
    IncorrectFeedMode,
    IncorrectExecMode
  };

  /// Initialize a Map instance
  ///   Decodes a map.json into a Map struct, usable by an Engine.
  pub fn init(alloc: std.mem.Allocator, map_path: []const u8) MapError!Map {
    const file = std.fs.cwd().openFile(map_path, .{}) catch |err| switch (err) {
      error.FileNotFound => return error.MapFileNotFound,
      error.IsDir        => return error.MapFileNotFound,
      else               => return error.MapFileNotFound,
    };
    defer file.close();
    const json_bytes: []const u8 = file.readToEndAlloc(alloc, std.math.maxInt(usize))
      catch |err| switch (err) {
      error.FileTooBig    => return error.MapInvalidJson,
      else                => return error.MapInvalidJson,
    };
    defer alloc.free(json_bytes);

    const MapPlaceHolder = struct {
      auto: []const u8, feed_mode: FeedMode, db: []const u8, table: []const u8, 
      t0: u64, tn: u64, trail_size: u64, exec_mode: ExecMode};

    var parsed_map = std.json.parseFromSlice(MapPlaceHolder, alloc, json_bytes, .{})
      catch return error.MapInvalidJson;
    defer parsed_map.deinit();

    return Map{
      .alloc = alloc,
      .auto  = path_util.autoSrcRelPathToCompiledAbsPath(alloc, parsed_map.value.auto)
        catch return error.MapInvalidJson,
      .feed_mode = parsed_map.value.feed_mode,
      .db    = path_util.dbRelPathToAbsPath(alloc, parsed_map.value.db)
        catch return error.MapInvalidJson,
      .table = alloc.dupe(u8, parsed_map.value.table)
        catch return error.MapInvalidJson,
      .t0 = parsed_map.value.t0,
      .tn = parsed_map.value.tn,
      .trail_size = parsed_map.value.trail_size,
      .exec_mode = parsed_map.value.exec_mode,
    };
  }

  /// Deinitialize map instance
  ///   Frees auto path, db path, table name.
  pub fn deinit(self: *Map) void {
    self.alloc.free(self.auto);
    self.alloc.free(self.db);
    self.alloc.free(self.table);
  }
};

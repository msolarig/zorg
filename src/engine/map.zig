const std = @import("std");
const db = @import("../feed/sql_wrapper.zig");

const Mode = enum {
  LiveExecution,
  Backtest,
  Optimization,
};

pub const Map = struct {
  alloc: std.mem.Allocator,
  auto: []const u8,
  db: []const u8,
  table: []const u8,
  t0: u64,
  tn: u64,
  trail_size: u64,
  mode: Mode,

  pub fn init(alloc: std.mem.Allocator, map_path: []const u8) !Map {
    // Decode a map.json into a Map struct, usable by an Engine.
    const file = try std.fs.cwd().openFile(map_path, .{});
    defer file.close();
    const json_bytes: []const u8 = try file.readToEndAlloc(alloc, std.math.maxInt(usize));
    defer alloc.free(json_bytes);

    const MapPlaceHolder = struct {
      auto: []const u8, db: []const u8, table: []const u8, 
      t0: u64, tn: u64, trail_size: u64, mode: Mode,};

    var parsed_map = try std.json.parseFromSlice(
          MapPlaceHolder, alloc, json_bytes, .{});
    defer parsed_map.deinit();

    const decoded_map = parsed_map.value;

    return Map{
      .alloc = alloc,
      .auto  = try alloc.dupe(u8, decoded_map.auto),
      .db    = try alloc.dupe(u8, decoded_map.db),
      .table = try alloc.dupe(u8, decoded_map.table),
      .t0 = decoded_map.t0,
      .tn = decoded_map.tn,
      .trail_size = decoded_map.trail_size,
      .mode = decoded_map.mode,
    };
  }

  pub fn deinit(self: *Map) void {
    self.alloc.free(self.auto);
    self.alloc.free(self.db);
    self.alloc.free(self.table);
  }
};

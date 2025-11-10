const std   = @import("std");
const db    = @import("../feed/sql_wrapper.zig");
const Track = @import("../feed/track.zig").Track;
const Trail = @import("../feed/trail.zig").Trail;
const Map   = @import("map.zig").Map;

pub const Engine = struct {
  alloc: std.mem.Allocator,
  map: Map,
  track: Track,
  trail: Trail,

  pub fn init(alloc: std.mem.Allocator, map_path: []const u8) !Engine {
    
    const decoded_map: Map = try Map.init(alloc, map_path);
    //defer decoded_map.deinit();

    const db_handle: *anyopaque = try db.openDB(decoded_map.db);

    var track: Track = Track.init();
    //defer track.deinit(alloc);
    try track.load(alloc, db_handle, decoded_map.table, decoded_map.t0, decoded_map.tn);

    var trail: Trail = try Trail.init(alloc, decoded_map.trail_size);
    //defer trail.deinit(alloc);
    try trail.load(track, 0);

    try db.closeDB(db_handle);

    return Engine{
      .alloc = alloc,
      .map   = decoded_map,
      .track = track,
      .trail = trail,
    };
  }

  pub fn deinit(self: *Engine) void {
    self.map.deinit();
    self.track.deinit(self.alloc);
    self.trail.deinit(self.alloc);
  }
};

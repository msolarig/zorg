const std = @import("std");
const db = @import("db.zig");
const trackmod = @import("track.zig");
const algomod = @import("algo.zig");
const mapmod = @import("map.zig");

pub const Engine = struct {
  allocator: std.mem.Allocator,
  db_handle: ?*anyopaque,
  track: ?trackmod.Track,
  algo: ?algomod.Algo,
  map: mapmod.Map,

  pub fn init(allocator: std.mem.Allocator, map: mapmod.Map) !Engine {
    var e = Engine{.allocator = allocator, .map = map,};
    return e;
  }

  pub fn loadData(self: *Engine) !void {
    self.db_handle = try db.openDB(self.map.db_path);
    self.track = try db.loadTrack(self.handle, self.map.db_table, self.map.track_size, self.allocator);
    std.debug.print("Loaded {d} bars into track from table {s}\n", .{self.map.track_size, self.map.db_table});
  }



};

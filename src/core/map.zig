const std = @import("std");

pub const Map = struct {
  algo_name: []const u8,
  db_path: []const u8,
  db_table: []const u8,
  track_size: usize,

  pub fn print(self: Map) void {
    std.debug.print("Engine Map:\n Algo: {s}\n DBase: {s}\n Table: {s}\n Track: {}\n", 
        .{self.algo_name, self.db_path, self.db_table, self.track_size});
  }

};

// Temporarily hardcoded for testing
pub fn load() !Map {
  return Map{.algo_name = "TestAlgo", .db_path = "data/market.db", .db_table = "AJG_D1", .track_size = 25};
}


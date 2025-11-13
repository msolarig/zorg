const std    = @import("std");
const Engine = @import("engine/engine.zig").Engine;

pub fn main() !void {
  
  // Main Program Allocator
  var gpa = std.heap.GeneralPurposeAllocator(.{}){};
  defer _ = gpa.deinit();
  const alloc = gpa.allocator();

  var engine: Engine = try Engine.init(alloc, "test_map.json");
  defer engine.deinit();
  try engine.ExecuteProcess();
}

test {
    _ = @import("test/track_test.zig");
}

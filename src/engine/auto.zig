const std = @import("std");

/// ----------------------------------------------------------------
/// Base structure of all ROBERT systems.
/// Submit this struct along a JSON map to the engine to run a test.
/// ----------------------------------------------------------------

pub const Auto = struct {
  name: []const u8,
  description: []const u8 = " ",

  pub fn exec(self: *Auto) void {
    _ = self;
    return;
  }
};

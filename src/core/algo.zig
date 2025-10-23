const std = @import("std");
const trackmod = @import("track.zig");

pub const ExecTrigger = enum {
  bar,
  tick,
};

/// Base structure of all ROBERT systems.
/// Lifecycle: init -> exec -> deinit.
pub const Algo = struct {
  name: []const u8,
  exec_trigger: ExecTrigger = .bar,

  /// Function pointers for lifecycle callbacks.
  initFn: ?fn(self: *Algo, allocator: std.mem.Allocator) anyerror!void = null,
  execFn: ?fn(self: *Algo, track: *trackmod.Track, index: usize) anyerror!void = null,
  deinitFn: ?fn(self: *Algo) anyerror!void = null,

  pub fn init(self: *Algo, allocator: std.mem.Allocator) !void {
    if (self.initFn) |func| {
      try func(self, allocator);
    } else {
      std.debug.print("Init skipped for {s}\n", .{self.name});
      }
  }

  pub fn exec(self: *Algo, track: *trackmod.Track, index: usize) !void {
    if (self.execFn) |func| {
      try func(self, track, index);
    } else {
        std.debug.print("Exec skipped for {s}\n", .{self.name});
      }
  }

  pub fn deinit(self: *Algo) !void {
    if (self.deinitFn) |func| {
      try func(self);
    } else {
        std.debug.print("Deinit skipped for {s}\n", .{self.name});
      }
  }
};

const std   = @import("std");
const Track = @import("../feed/track.zig").Track;
const Trail = @import("../feed/trail.zig").Trail;
const Map   = @import("map.zig").Map;

pub const Engine = struct {
    alloc: std.mem.Allocator,
    map: Map,
    track: ?Track,
    trail: ?Trail,

    pub fn init(alloc: std.mem.Allocator, map_path: []const u8) !Engine {
        return Engine{
            .alloc = alloc,
            .map   = try Map.init(alloc, map_path),
            .track = null,
            .trail = null,
        };
    }

    pub fn deinit(self: *Engine) void {
        self.map.deinit();
        // deinit track/trail here if/when they are owned by Engine
    }
};

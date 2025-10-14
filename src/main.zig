const std = @import("std");
const db = @import("core/db.zig");
const types = @import("core/types.zig");

pub fn main() !void {
    const handle = try db.openDB("data/market.db");
    defer db.closeDB(handle) catch {};

    const allocator = std.heap.page_allocator;

    var s = try db.loadSeries(handle, "AJG_1D", 20, allocator);
    defer allocator.free(s.points);

    s.debugPrint();
}

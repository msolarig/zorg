const std = @import("std");
const db = @import("core/db.zig");
const Track = @import("core/track.zig").Track;

pub fn main() !void {
    const allocator = std.heap.page_allocator;

    // 1️⃣ Open the database
    const handle = try db.openDB("../data/market.db");
    defer db.closeDB(handle) catch {};

    // 2️⃣ Start a timer to measure query performance
    var timer = try std.time.Timer.start();

    // 3️⃣ Load a track from your chosen table (AJG_1D, last 250 rows)
    var track = try db.loadTrack(handle, "AJG_1D", 250, allocator);
    defer track.deinit(allocator);

    const elapsed_ns = timer.read();
    const elapsed_ms = @as(f64, @floatFromInt(elapsed_ns)) / 1_000_000.0;

    std.debug.print("Loaded {d} rows from DB in {d:.3} ms\n", .{track.size, elapsed_ms});

    // 4️⃣ Print a few recent values for verification
    std.debug.print("\n=== Latest 3 Candles ===\n", .{});
    const limit = if (track.size < 3) track.size else 3;

    var i: usize = 0;
    while (i < limit) : (i += 1) {
        std.debug.print(
            "idx {d}: ts={d}, O={d:.2}, H={d:.2}, L={d:.2}, C={d:.2}, V={d}\n",
            .{
                i,
                track.ts[i],
                track.op[i],
                track.hi[i],
                track.lo[i],
                track.cl[i],
                track.vo[i],
            },
        );
    }

    // 5️⃣ Example of your future indexed access system
    std.debug.print("\nLatest close = {d:.2}\nPrevious close = {d:.2}\n", .{
        track.getClose(0),
        track.getClose(1),
    });

    std.debug.print("\nDone.\n", .{});
}

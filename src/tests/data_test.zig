const std = @import("std");
const data = @import("../engine/data.zig");
const Track = data.Track;
const Trail = data.Trail;
const db = data.sql_wrap;

const TEST_DB = "testdata/db/mono_table_test.db";
const TEST_TABLE = "AAPL_1D";

test "Track.init creates empty track" {
    const track = Track.init();

    try std.testing.expectEqual(track.size, 0);
    try std.testing.expectEqual(track.ts.items.len, 0);
    try std.testing.expectEqual(track.op.items.len, 0);
    try std.testing.expectEqual(track.hi.items.len, 0);
    try std.testing.expectEqual(track.lo.items.len, 0);
    try std.testing.expectEqual(track.cl.items.len, 0);
    try std.testing.expectEqual(track.vo.items.len, 0);
}

test "Track.load populates data from database" {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const alloc = gpa.allocator();

    const db_handle = try db.openDB(TEST_DB);
    defer db.closeDB(db_handle) catch {};

    var track = Track.init();
    defer track.deinit(alloc);

    try track.load(alloc, db_handle, TEST_TABLE, 0, 2000000000);

    try std.testing.expectEqual(track.size, 6288);
    try std.testing.expectEqual(track.ts.items.len, 6288);
}

test "Track arrays have consistent lengths after load" {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const alloc = gpa.allocator();

    const db_handle = try db.openDB(TEST_DB);
    defer db.closeDB(db_handle) catch {};

    var track = Track.init();
    defer track.deinit(alloc);

    try track.load(alloc, db_handle, TEST_TABLE, 0, 2000000000);

    try std.testing.expectEqual(track.ts.items.len, track.op.items.len);
    try std.testing.expectEqual(track.ts.items.len, track.hi.items.len);
    try std.testing.expectEqual(track.ts.items.len, track.lo.items.len);
    try std.testing.expectEqual(track.ts.items.len, track.cl.items.len);
    try std.testing.expectEqual(track.ts.items.len, track.vo.items.len);
}

test "Track.load respects timestamp bounds" {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const alloc = gpa.allocator();

    const db_handle = try db.openDB(TEST_DB);
    defer db.closeDB(db_handle) catch {};

    var track = Track.init();
    defer track.deinit(alloc);

    try track.load(alloc, db_handle, TEST_TABLE, 1000000000, 1500000000);

    for (track.ts.items) |ts| {
        try std.testing.expect(ts > 1000000000);
        try std.testing.expect(ts < 1500000000);
    }
}

test "Track first and last values match expected" {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const alloc = gpa.allocator();

    const db_handle = try db.openDB(TEST_DB);
    defer db.closeDB(db_handle) catch {};

    var track = Track.init();
    defer track.deinit(alloc);

    try track.load(alloc, db_handle, TEST_TABLE, 0, 2000000000);

    try std.testing.expectEqual(track.ts.items[0], 1735516800);
    try std.testing.expectEqual(track.ts.items[track.ts.items.len - 1], 946857600);
}

test "Trail.init allocates correct size" {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const alloc = gpa.allocator();

    var trail = try Trail.init(alloc, 10);
    defer trail.deinit(alloc);

    try std.testing.expectEqual(trail.size, 10);
    try std.testing.expectEqual(trail.ts.len, 10);
    try std.testing.expectEqual(trail.op.len, 10);
    try std.testing.expectEqual(trail.hi.len, 10);
    try std.testing.expectEqual(trail.lo.len, 10);
    try std.testing.expectEqual(trail.cl.len, 10);
    try std.testing.expectEqual(trail.vo.len, 10);
}

test "Trail.load fills from track data" {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const alloc = gpa.allocator();

    const db_handle = try db.openDB(TEST_DB);
    defer db.closeDB(db_handle) catch {};

    var track = Track.init();
    defer track.deinit(alloc);
    try track.load(alloc, db_handle, TEST_TABLE, 0, 2000000000);

    var trail = try Trail.init(alloc, 10);
    defer trail.deinit(alloc);
    try trail.load(track, 0);

    try std.testing.expectEqual(trail.ts[0], track.ts.items[track.ts.items.len - 1]);
}

test "Trail.toABI returns valid ABI struct" {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const alloc = gpa.allocator();

    var trail = try Trail.init(alloc, 5);
    defer trail.deinit(alloc);

    const abi_trail = trail.toABI();

    try std.testing.expectEqual(@TypeOf(abi_trail.ts), [*]const u64);
    try std.testing.expectEqual(@TypeOf(abi_trail.op), [*]const f64);
}

test "Track.deinit frees all memory" {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    const alloc = gpa.allocator();

    const db_handle = try db.openDB(TEST_DB);

    var track = Track.init();
    try track.load(alloc, db_handle, TEST_TABLE, 0, 2000000000);

    track.deinit(alloc);
    db.closeDB(db_handle) catch {};

    const leak_status = gpa.deinit();
    try std.testing.expect(leak_status == .ok);
}

test "Trail.deinit frees all memory" {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    const alloc = gpa.allocator();

    var trail = try Trail.init(alloc, 10);
    trail.deinit(alloc);

    const leak_status = gpa.deinit();
    try std.testing.expect(leak_status == .ok);
}

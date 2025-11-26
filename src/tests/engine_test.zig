const std = @import("std");
const data = @import("../engine/data.zig");
const core = @import("../zdk/core.zig");
const Track = data.Track;
const Trail = data.Trail;
const Account = core.Account;
const AccountManager = core.AccountManager;
const db = data.sql_wrap;

const TEST_DB = "testdata/db/mono_table_test.db";
const TEST_TABLE = "AAPL_1D";
const TEST_TRAIL_SIZE: usize = 10;
const TEST_BALANCE: f64 = 10000.0;

test "Engine components assemble correctly" {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const alloc = gpa.allocator();

    const db_handle = try db.openDB(TEST_DB);
    defer db.closeDB(db_handle) catch {};

    var track = Track.init();
    defer track.deinit(alloc);
    try track.load(alloc, db_handle, TEST_TABLE, 0, 2000000000);

    var trail = try Trail.init(alloc, TEST_TRAIL_SIZE);
    defer trail.deinit(alloc);
    try trail.load(track, 0);

    const acc = Account.init(TEST_BALANCE);

    try std.testing.expectEqual(track.size, 6288);
    try std.testing.expectEqual(trail.size, TEST_TRAIL_SIZE);
    try std.testing.expectEqual(acc.balance, TEST_BALANCE);
}

test "Engine track loads correct data count" {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const alloc = gpa.allocator();

    const db_handle = try db.openDB(TEST_DB);
    defer db.closeDB(db_handle) catch {};

    var track = Track.init();
    defer track.deinit(alloc);
    try track.load(alloc, db_handle, TEST_TABLE, 0, 2000000000);

    try std.testing.expectEqual(track.size, 6288);
}

test "Engine trail loads with configured size" {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const alloc = gpa.allocator();

    var trail = try Trail.init(alloc, TEST_TRAIL_SIZE);
    defer trail.deinit(alloc);

    try std.testing.expectEqual(trail.size, TEST_TRAIL_SIZE);
}

test "Engine account initializes with balance" {
    const acc = Account.init(TEST_BALANCE);

    try std.testing.expectEqual(acc.balance, TEST_BALANCE);
}

test "Engine track data matches expected first values" {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const alloc = gpa.allocator();

    const db_handle = try db.openDB(TEST_DB);
    defer db.closeDB(db_handle) catch {};

    var track = Track.init();
    defer track.deinit(alloc);
    try track.load(alloc, db_handle, TEST_TABLE, 0, 2000000000);

    try std.testing.expectEqual(track.ts.items[0], 1735516800);
    try std.testing.expectEqual(track.op.items[0], 251.33775398934142);
    try std.testing.expectEqual(track.hi.items[0], 252.60326573181473);
    try std.testing.expectEqual(track.lo.items[0], 249.86299361835324);
    try std.testing.expectEqual(track.cl.items[0], 251.307861328125);
    try std.testing.expectEqual(track.vo.items[0], 35557500);
}

test "Engine track data matches expected last values" {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const alloc = gpa.allocator();

    const db_handle = try db.openDB(TEST_DB);
    defer db.closeDB(db_handle) catch {};

    var track = Track.init();
    defer track.deinit(alloc);
    try track.load(alloc, db_handle, TEST_TABLE, 0, 2000000000);

    const last = track.ts.items.len - 1;

    try std.testing.expectEqual(track.ts.items[last], 946857600);
    try std.testing.expectEqual(track.op.items[last], 0.7870901168329728);
    try std.testing.expectEqual(track.hi.items[last], 0.8443156783566781);
    try std.testing.expectEqual(track.lo.items[last], 0.7631676614192741);
    try std.testing.expectEqual(track.cl.items[last], 0.8400943279266357);
    try std.testing.expectEqual(track.vo.items[last], 535796800);
}

test "Engine trail contains oldest track data at index 0" {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const alloc = gpa.allocator();

    const db_handle = try db.openDB(TEST_DB);
    defer db.closeDB(db_handle) catch {};

    var track = Track.init();
    defer track.deinit(alloc);
    try track.load(alloc, db_handle, TEST_TABLE, 0, 2000000000);

    var trail = try Trail.init(alloc, TEST_TRAIL_SIZE);
    defer trail.deinit(alloc);
    try trail.load(track, 0);

    try std.testing.expectEqual(trail.ts[0], track.ts.items[track.ts.items.len - 1]);
}

test "Engine trail loads sequential data from track" {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const alloc = gpa.allocator();

    const db_handle = try db.openDB(TEST_DB);
    defer db.closeDB(db_handle) catch {};

    var track = Track.init();
    defer track.deinit(alloc);
    try track.load(alloc, db_handle, TEST_TABLE, 0, 2000000000);

    var trail = try Trail.init(alloc, TEST_TRAIL_SIZE);
    defer trail.deinit(alloc);
    try trail.load(track, 0);

    const track_len = track.ts.items.len;
    const trail_len = trail.ts.len;

    try std.testing.expectEqual(trail.ts[trail_len - 1], track.ts.items[track_len - trail_len]);
}

test "Engine components deinit frees all memory" {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    const alloc = gpa.allocator();

    const db_handle = try db.openDB(TEST_DB);

    var track = Track.init();
    try track.load(alloc, db_handle, TEST_TABLE, 0, 2000000000);

    var trail = try Trail.init(alloc, TEST_TRAIL_SIZE);
    try trail.load(track, 0);

    trail.deinit(alloc);
    track.deinit(alloc);
    db.closeDB(db_handle) catch {};

    const leak_status = gpa.deinit();
    try std.testing.expect(leak_status == .ok);
}

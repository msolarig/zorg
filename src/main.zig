const std = @import("std");
const robotik = @import("robotik");
const db = @import("core/db.zig");

pub fn main() !void {
    db.testConnection();
    const handle = try db.openDB("data/market.db");

    try db.queryOhlcv(handle, true);
    
    try db.closeDB(handle);
}

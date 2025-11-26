pub const local_data = @import("data/local_data.zig");
pub const sql_wrap = @import("data/sql_wrap.zig");

pub const Track = local_data.Track;
pub const Trail = local_data.Trail;

pub const openDB = sql_wrap.openDB;
pub const closeDB = sql_wrap.closeDB;


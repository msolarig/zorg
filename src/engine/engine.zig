const std = @import("std");
const db = @import("data/sql_wrap.zig");
const Track = @import("data/local_data.zig").Track;
const Trail = @import("data/local_data.zig").Trail;
const Map = @import("config/map.zig").Map;
const loader = @import("auto/loader.zig");
const Auto = loader.LoadedAuto;
const Account = @import("../zdk/core/account.zig").Account;
const OutputManager = @import("out/output.zig").OutputManager;
const path_util = @import("../utils/path_utility.zig");
const backtest = @import("exec/backtest.zig");

pub const Engine = struct {
    alloc: std.mem.Allocator,
    map: Map,
    auto: Auto,
    acc: Account,
    track: Track,
    trail: Trail,
    out: OutputManager,

    pub fn init(alloc: std.mem.Allocator, map_path: []const u8) !Engine {
        const map_abs_path = try path_util.mapRelPathToAbsPath(alloc, map_path);
        defer alloc.free(map_abs_path);

        var decoded_map: Map = try Map.init(alloc, map_abs_path);
        errdefer {
            decoded_map.deinit();
        }

        const db_handle: *anyopaque = try db.openDB(decoded_map.db);
        var track: Track = Track.init();
        try track.load(alloc, db_handle, decoded_map.table, decoded_map.t0, decoded_map.tn);
        var trail: Trail = try Trail.init(alloc, decoded_map.trail_size);
        try trail.load(track, 0);
        try db.closeDB(db_handle);

        errdefer {
            track.deinit(alloc);
            trail.deinit(alloc);
        }

        const auto: Auto = try loader.load_from_file(alloc, decoded_map.auto);
        const account: Account = decoded_map.account;
        const out: OutputManager = try OutputManager.init(alloc, decoded_map.output.OUTPUT_DIR_NAME);

        return Engine{
            .alloc = alloc,
            .map = decoded_map,
            .auto = auto,
            .acc = account,
            .track = track,
            .trail = trail,
            .out = out,
        };
    }

    pub fn ExecuteProcess(self: *Engine) !void {
        var foo: u8 = undefined; // placeholder

        switch (self.map.exec_mode) {
            .LiveExecution => foo = 0,
            .Backtest => try backtest.runBacktest(self),
            .Optimization => foo = 0,
        }
    }

    pub fn deinit(self: *Engine) void {
        self.map.deinit();
        self.auto.deinit();
        self.track.deinit(self.alloc);
        self.trail.deinit(self.alloc);
        self.out.deinit(self.alloc);
    }
};

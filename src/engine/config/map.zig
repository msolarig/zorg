const std = @import("std");
const db = @import("../data/sql_wrap.zig");
const json_util = @import("../../utils/clean_json.zig").cleanJSON;
const path_util = @import("../../utils/path_converter.zig");
const Account = @import("../../roblang/core/account.zig").Account;

/// Data Feed Mode
const FeedMode = enum { Live, SQLite3 };

/// Process Execution Mode
const ExecMode = enum { LiveExecution, Backtest, Optimization };

/// Engine Map (Configuration File)
///   provides required information for system to locate and load inputs
///   as well as instructions for process & execution.
pub const Map = struct {
    alloc: std.mem.Allocator,
    auto: []const u8,
    feed_mode: FeedMode,
    db: []const u8,
    table: []const u8,
    t0: u64,
    tn: u64,
    trail_size: u64,
    exec_mode: ExecMode,
    account: Account,

    pub fn init(alloc: std.mem.Allocator, map_path: []const u8) !Map {
        var file = try std.fs.cwd().openFile(map_path, .{});
        defer file.close();

        const file_bytes = try file.readToEndAlloc(alloc, std.math.maxInt(usize));
        defer alloc.free(file_bytes);

        const json_bytes = try json_util.stripComments(alloc, file_bytes);
        defer alloc.free(json_bytes);

        const MapPlaceholder = struct { auto: []const u8, feed_mode: FeedMode, db: []const u8, table: []const u8, t0: u64, tn: u64, trail_size: u64, exec_mode: ExecMode, account: struct { balance: f64 } };

        var parsed = try std.json.parseFromSlice(MapPlaceholder, alloc, json_bytes, .{});
        defer parsed.deinit();

        var map = Map{
            .alloc = alloc,
            .auto = undefined,
            .feed_mode = parsed.value.feed_mode,
            .db = undefined,
            .table = undefined,
            .t0 = parsed.value.t0,
            .tn = parsed.value.tn,
            .trail_size = parsed.value.trail_size,
            .exec_mode = parsed.value.exec_mode,
            .account = Account{ .balance = parsed.value.account.balance },
        };
        errdefer map.deinit();

        map.auto = try path_util.autoSrcRelPathToCompiledAbsPath(alloc, parsed.value.auto);
        map.db = try path_util.dbRelPathToAbsPath(alloc, parsed.value.db);
        map.table = try alloc.dupe(u8, parsed.value.table);

        return map;
    }

    pub fn deinit(self: *Map) void {
        self.alloc.free(self.auto);
        self.alloc.free(self.db);
        self.alloc.free(self.table);
    }
};

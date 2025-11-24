const std = @import("std");
const db = @import("../data/sql_wrap.zig");
const json_util = @import("../../utils/json_utility.zig").cleanJSON;
const path_util = @import("../../utils/path_utility.zig");
const Account = @import("../../zdk/core/account.zig").Account;
const OutputConfig = @import("../out/output.zig").OutputConfig;

const FeedMode = enum { Live, SQLite3 };
const ExecMode = enum { LiveExecution, Backtest, Optimization };

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
    output: OutputConfig,

    pub fn init(alloc: std.mem.Allocator, map_path: []const u8) !Map {
        var file = try std.fs.cwd().openFile(map_path, .{});
        defer file.close();

        const file_bytes = try file.readToEndAlloc(alloc, std.math.maxInt(usize));
        defer alloc.free(file_bytes);

        const json_bytes = try json_util.stripComments(alloc, file_bytes);
        defer alloc.free(json_bytes);

        const MapPlaceholder = struct {
            ENGINE_EXECUTION_MODE: ExecMode,
            ENGINE_AUTO_TO_ATTACH: []const u8,
            ENGINE_DATA_FEED_MODE: FeedMode,
            ENGINE_DB_FILE_NAME: []const u8,
            ENGINE_DB_TABLE_NAME: []const u8,
            ENGINE_TIMESTAMP_0: u64,
            ENGINE_TIMESTAMP_n: u64,
            ENGINE_TRAIL_LENGTH: u64,
            ENGINE_ACCOUNT_CONFIG: Account,
            ENGINE_OUTPUT_CONFIG: OutputConfig,
        };

        var parsed = try std.json.parseFromSlice(MapPlaceholder, alloc, json_bytes, .{});
        defer parsed.deinit();

        var map = Map{
            .alloc = alloc,
            .auto = undefined,
            .feed_mode = parsed.value.ENGINE_DATA_FEED_MODE,
            .db = undefined,
            .table = undefined,
            .t0 = parsed.value.ENGINE_TIMESTAMP_0,
            .tn = parsed.value.ENGINE_TIMESTAMP_n,
            .trail_size = parsed.value.ENGINE_TRAIL_LENGTH,
            .exec_mode = parsed.value.ENGINE_EXECUTION_MODE,
            .account = undefined,
            .output = undefined,
        };
        errdefer map.deinit();

        map.auto = try path_util.autoSrcRelPathToCompiledAbsPath(alloc, parsed.value.ENGINE_AUTO_TO_ATTACH);
        map.db = try path_util.dbRelPathToAbsPath(alloc, parsed.value.ENGINE_DB_FILE_NAME);
        map.table = try alloc.dupe(u8, parsed.value.ENGINE_DB_TABLE_NAME);
        map.account = Account{ .ACCOUNT_BALANCE = parsed.value.ENGINE_ACCOUNT_CONFIG.ACCOUNT_BALANCE };
        map.output = OutputConfig{ .OUTPUT_DIR_NAME = try alloc.dupe(u8, parsed.value.ENGINE_OUTPUT_CONFIG.OUTPUT_DIR_NAME) };

        return map;
    }

    pub fn deinit(self: *Map) void {
        self.alloc.free(self.auto);
        self.alloc.free(self.db);
        self.alloc.free(self.table);
        self.alloc.free(self.output.OUTPUT_DIR_NAME);
    }
};

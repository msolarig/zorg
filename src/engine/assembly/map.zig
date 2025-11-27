const std = @import("std");
const path_util = @import("../../utils/path_utility.zig");
const Account = @import("../../zdk/core.zig").Account;
const OutputConfig = @import("../output/output_manager.zig").OutputConfig;

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

        const json_bytes = try stripJsonComments(alloc, file_bytes);
        defer alloc.free(json_bytes);

        const MapSchema = struct {
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

        var parsed = try std.json.parseFromSlice(MapSchema, alloc, json_bytes, .{});
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
        map.account = Account{ .balance = parsed.value.ENGINE_ACCOUNT_CONFIG.balance };
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

fn stripJsonComments(alloc: std.mem.Allocator, input: []const u8) ![]u8 {
    var out: std.ArrayList(u8) = .{};
    errdefer out.deinit(alloc);

    var i: usize = 0;
    var in_string = false;
    var escaped = false;

    while (i < input.len) {
        const c = input[i];

        if (in_string) {
            try out.append(alloc, c);
            if (escaped) {
                escaped = false;
            } else if (c == '\\') {
                escaped = true;
            } else if (c == '"') {
                in_string = false;
            }
            i += 1;
            continue;
        }

        if (c == '"') {
            in_string = true;
            try out.append(alloc, c);
            i += 1;
            continue;
        }

        if (c == '/' and i + 1 < input.len and input[i + 1] == '/') {
            i += 2;
            while (i < input.len and input[i] != '\n') : (i += 1) {}
            continue;
        }

        if (c == '/' and i + 1 < input.len and input[i + 1] == '*') {
            i += 2;
            while (i + 1 < input.len) : (i += 1) {
                if (input[i] == '*' and input[i + 1] == '/') {
                    i += 2;
                    break;
                }
            }
            continue;
        }

        try out.append(alloc, c);
        i += 1;
    }

    return out.toOwnedSlice(alloc);
}

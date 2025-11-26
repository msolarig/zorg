const std = @import("std");
const vaxis = @import("vaxis");
const panes = @import("../../panes.zig");
const border = panes.border;
const types = @import("../../types.zig");
const State = types.State;
const Map = @import("../../../engine/config/map.zig").Map;
const path_util = @import("../../../utils/path_utility.zig");

const Theme = struct {
    const fg_label = vaxis.Color{ .index = 137 }; // brown-gray
    const fg_value = vaxis.Color{ .index = 187 }; // warm beige
    const fg_accent = vaxis.Color{ .index = 66 }; // muted blue
    const fg_highlight = vaxis.Color{ .index = 66 }; // muted blue
    const fg_section = vaxis.Color{ .index = 66 }; // muted blue
    const fg_dim = vaxis.Color{ .index = 137 }; // brown-gray
    const bg = vaxis.Color{ .index = 235 }; // dark steel
};

pub fn render(win: vaxis.Window, state: *State) void {
    border.draw(win, "cfg");

    const result = state.execution_result orelse {
        printLine(win, 0, 0, "No execution yet", .{ .fg = Theme.fg_dim, .dim = true });
        return;
    };

    // Try to load and parse the map
    var map = loadMap(state, result.map_path) catch |err| {
        const err_msg = state.frameFmt("Error: {s}", .{@errorName(err)}) catch return;
        printLine(win, 0, 0, err_msg, .{ .fg = Theme.fg_accent, .dim = true });
        return;
    };
    defer map.deinit();

    var row: usize = 1; // Start after top border
    const max_w = if (win.width > 2) win.width - 2 else 1;
    const max_h = if (win.height > 2) win.height - 2 else 0;

    // Map path
    const map_path_line = if (result.map_path.len > max_w - 6)
        (state.frameAlloc(result.map_path[0..@min(max_w - 6, result.map_path.len)]) catch return) else result.map_path;
    printLine(win, row, 1, "path: ", .{ .fg = Theme.fg_label });
    printLine(win, row, 7, map_path_line, .{ .fg = Theme.fg_value });
    row += 2;
    if (row >= max_h) return;

    // AUTO (highlighted)
    printLine(win, row, 1, "AUTO", .{ .fg = Theme.fg_section, .bold = true });
    row += 1;
    if (row >= max_h) return;

    const auto_basename = std.fs.path.basename(map.auto);
    const auto_display_len = @min(max_w - 9, auto_basename.len);
    const auto_display = state.frameAlloc(auto_basename[0..auto_display_len]) catch return;
    printLine(win, row, 1, "name: ", .{ .fg = Theme.fg_label });
    printLine(win, row, 7, auto_display, .{ .fg = Theme.fg_highlight, .bold = true });
    row += 1;
    if (row >= max_h) return;

    // EXECUTION (highlighted)
    printLine(win, row, 1, "EXECUTION", .{ .fg = Theme.fg_section, .bold = true });
    row += 1;
    if (row >= max_h) return;

    const mode_str = switch (map.exec_mode) {
        .LiveExecution => "LIVE",
        .Backtest => "BACKTEST",
        .Optimization => "OPTIMIZATION",
    };
    const mode_color = switch (map.exec_mode) {
        .LiveExecution => vaxis.Color{ .index = 95 }, // muted red
        .Backtest => vaxis.Color{ .index = 137 }, // muted brown
        .Optimization => vaxis.Color{ .index = 65 }, // muted green
    };
    printLine(win, row, 1, "mode: ", .{ .fg = Theme.fg_label });
    printLine(win, row, 7, mode_str, .{ .fg = mode_color, .bold = true });
    row += 1;
    if (row >= max_h) return;

    // DATA FEED (highlighted)
    printLine(win, row, 1, "DATA FEED", .{ .fg = Theme.fg_section, .bold = true });
    row += 1;
    if (row >= max_h) return;

    const feed_str = switch (map.feed_mode) {
        .Live => "LIVE",
        .SQLite3 => "SQLite3",
    };
    printLine(win, row, 1, "type: ", .{ .fg = Theme.fg_label });
    printLine(win, row, 7, feed_str, .{ .fg = Theme.fg_highlight, .bold = true });
    row += 1;
    if (row >= max_h) return;

    const db_rel = extractRelPath(map.db);
    const db_line_len = @min(max_w - 6, db_rel.len);
    const db_line = state.frameAlloc(db_rel[0..db_line_len]) catch return;
    printLine(win, row, 1, "db: ", .{ .fg = Theme.fg_label });
    printLine(win, row, 5, db_line, .{ .fg = Theme.fg_highlight, .bold = true });
    row += 1;
    if (row >= max_h) return;

    const table_line_len = @min(max_w - 9, map.table.len);
    const table_line = state.frameAlloc(map.table[0..table_line_len]) catch return;
    printLine(win, row, 1, "table: ", .{ .fg = Theme.fg_label });
    printLine(win, row, 8, table_line, .{ .fg = Theme.fg_highlight, .bold = true });
    row += 1;
    if (row >= max_h) return;

    // ACCOUNT (highlighted)
    printLine(win, row, 1, "ACCOUNT", .{ .fg = Theme.fg_section, .bold = true });
    row += 1;
    if (row >= max_h) return;

    if (state.frameFmt("balance: ${d:.2}", .{map.account.balance})) |balance_str| {
        printLine(win, row, 1, balance_str, .{ .fg = Theme.fg_highlight, .bold = true });
    } else |_| {}
    row += 1;
    if (row >= max_h) return;

    // OUTPUT (highlighted)
    printLine(win, row, 1, "OUTPUT", .{ .fg = Theme.fg_section, .bold = true });
    row += 1;
    if (row >= max_h) return;

    const output_line_len = @min(max_w - 7, map.output.OUTPUT_DIR_NAME.len);
    const output_line = state.frameAlloc(map.output.OUTPUT_DIR_NAME[0..output_line_len]) catch return;
    printLine(win, row, 1, "dir: ", .{ .fg = Theme.fg_label });
    printLine(win, row, 6, output_line, .{ .fg = Theme.fg_highlight, .bold = true });
}

fn loadMap(state: *State, map_path: []const u8) !Map {
    const map_abs_path = try path_util.mapRelPathToAbsPath(state.alloc, map_path);
    defer state.alloc.free(map_abs_path);

    return try Map.init(state.alloc, map_abs_path);
}

fn extractRelPath(path: []const u8) []const u8 {
    if (std.mem.indexOf(u8, path, "zorg/")) |idx| {
        const rel = path[idx..];
        if (rel.len > 0 and rel[0] == '/') {
            return rel[1..];
        }
        return rel;
    }
    return std.fs.path.basename(path);
}

fn printLine(win: vaxis.Window, row: usize, col: usize, text: []const u8, style: vaxis.Style) void {
    const seg = vaxis.Cell.Segment{ .text = text, .style = style };
    _ = win.print(&[_]vaxis.Cell.Segment{seg}, .{
        .row_offset = @intCast(row),
        .col_offset = @intCast(col),
    });
}


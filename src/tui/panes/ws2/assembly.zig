const std = @import("std");
const vaxis = @import("vaxis");
const panes = @import("../../panes.zig");
const border = panes.border;
const types = @import("../../types.zig");
const State = types.State;

const Theme = struct {
    const fg_label = vaxis.Color{ .index = 137 }; // brown-gray
    const fg_value = vaxis.Color{ .index = 187 }; // warm beige
    const fg_accent = vaxis.Color{ .index = 66 }; // muted blue
    const fg_section = vaxis.Color{ .index = 66 }; // muted blue
    const bg = vaxis.Color{ .index = 235 }; // dark steel
};

pub fn render(win: vaxis.Window, state: *State) void {
    border.draw(win, "asm");

    const result = state.execution_result orelse {
        printLine(win, 1, 1, "No execution yet", .{ .fg = Theme.fg_label, .dim = true });
        return;
    };

    var row: usize = 1; // Start after top border
    const max_w = if (win.width > 2) win.width - 2 else 1;
    const max_h = if (win.height > 2) win.height - 2 else 0;

    // AUTO
    printLine(win, row, 1, "AUTO", .{ .fg = Theme.fg_section, .bold = true });
    row += 1;
    if (row >= max_h) return;

    const name_line = if (result.auto_name.len > max_w - 9)
        (state.frameAlloc(result.auto_name[0..@min(max_w - 9, result.auto_name.len)]) catch return) else result.auto_name;
    printLine(win, row, 1, "name: ", .{ .fg = Theme.fg_label });
    printLine(win, row, 7, name_line, .{ .fg = Theme.fg_value });
    row += 1;
    if (row >= max_h) return;

    const desc_line = if (result.auto_desc.len > max_w - 9)
        (state.frameAlloc(result.auto_desc[0..@min(max_w - 9, result.auto_desc.len)]) catch return) else result.auto_desc;
    printLine(win, row, 1, "desc: ", .{ .fg = Theme.fg_label });
    printLine(win, row, 7, desc_line, .{ .fg = Theme.fg_value });
    row += 1;
    if (row >= max_h) return;

    const auto_path_line = if (result.auto_path.len > max_w - 9)
        (state.frameAlloc(result.auto_path[0..@min(max_w - 9, result.auto_path.len)]) catch return) else result.auto_path;
    printLine(win, row, 1, "path: ", .{ .fg = Theme.fg_label });
    printLine(win, row, 7, auto_path_line, .{ .fg = Theme.fg_value });
    row += 2;
    if (row >= max_h) return;

    // DATA LOADED
    printLine(win, row, 1, "DATA LOADED", .{ .fg = Theme.fg_section, .bold = true });
    row += 1;
    if (row >= max_h) return;

    if (state.frameFmt("rows: {d} candles", .{result.data_points})) |rows_str| {
        printLine(win, row, 1, rows_str, .{ .fg = Theme.fg_value });
    } else |_| {}
    row += 1;
    if (row >= max_h) return;

    if (state.frameFmt("trail: {d} lookback", .{result.trail_size})) |trail_str| {
        printLine(win, row, 1, trail_str, .{ .fg = Theme.fg_value });
    } else |_| {}
    row += 1;
    if (row >= max_h) return;

    // ACCOUNT
    printLine(win, row, 1, "ACCOUNT", .{ .fg = Theme.fg_section, .bold = true });
    row += 1;
    if (row >= max_h) return;

    if (state.frameFmt("balance: ${d:.2}", .{result.balance})) |balance_str| {
        printLine(win, row, 1, balance_str, .{ .fg = Theme.fg_value });
    } else |_| {}
}

fn printLine(win: vaxis.Window, row: usize, col: usize, text: []const u8, style: vaxis.Style) void {
    const seg = vaxis.Cell.Segment{ .text = text, .style = style };
    _ = win.print(&[_]vaxis.Cell.Segment{seg}, .{
        .row_offset = @intCast(row),
        .col_offset = @intCast(col),
    });
}


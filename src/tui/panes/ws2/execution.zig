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
    const fg_success = vaxis.Color{ .index = 65 }; // muted green
    const fg_error = vaxis.Color{ .index = 95 }; // muted red
    const bg = vaxis.Color{ .index = 235 }; // dark steel
};

pub fn render(win: vaxis.Window, state: *State) void {
    border.draw(win, "exec");

    const result = state.execution_result orelse {
        printLine(win, 0, 0, "No execution yet", .{ .fg = Theme.fg_label, .dim = true });
        return;
    };

    var row: usize = 1; // Start after top border
    const max_h = if (win.height > 2) win.height - 2 else 0;

    // Status
    const status_text = if (result.success) "✓ COMPLETE" else "✗ FAILED";
    const status_color = if (result.success) Theme.fg_success else Theme.fg_error;
    printLine(win, row, 1, status_text, .{ .fg = status_color, .bold = true });
    row += 2;
    if (row >= max_h) return;

    // Execution mode
    const mode_color = if (std.mem.eql(u8, result.exec_mode, "BACKTEST"))
        vaxis.Color{ .index = 137 } // muted brown
    else if (std.mem.eql(u8, result.exec_mode, "LIVE"))
        vaxis.Color{ .index = 95 } // muted red
    else
        vaxis.Color{ .index = 65 }; // muted green
    printLine(win, row, 1, "mode: ", .{ .fg = Theme.fg_label });
    printLine(win, row, 7, result.exec_mode, .{ .fg = mode_color, .bold = true });
    row += 2;
    if (row >= max_h) return;

    // PERFORMANCE
    printLine(win, row, 1, "PERFORMANCE", .{ .fg = Theme.fg_accent, .bold = true });
    row += 1;
    if (row >= max_h) return;

    if (state.frameFmt("init: {d} ms", .{result.init_time_ms})) |init_str| {
        printLine(win, row, 1, init_str, .{ .fg = Theme.fg_value });
    } else |_| {}
    row += 1;
    if (row >= max_h) return;

    if (state.frameFmt("exec: {d} ms", .{result.exec_time_ms})) |exec_str| {
        printLine(win, row, 1, exec_str, .{ .fg = Theme.fg_value });
    } else |_| {}
    row += 1;
    if (row >= max_h) return;

    if (state.frameFmt("total: {d} ms", .{result.total_time_ms})) |total_str| {
        printLine(win, row, 1, total_str, .{ .fg = Theme.fg_value });
    } else |_| {}
    row += 1;
    if (row >= max_h) return;

    if (state.frameFmt("throughput: {d:.0} candles/sec", .{result.throughput})) |thru_str| {
        printLine(win, row, 1, thru_str, .{ .fg = Theme.fg_value });
    } else |_| {}
}

fn printLine(win: vaxis.Window, row: usize, col: usize, text: []const u8, style: vaxis.Style) void {
    const seg = vaxis.Cell.Segment{ .text = text, .style = style };
    _ = win.print(&[_]vaxis.Cell.Segment{seg}, .{
        .row_offset = @intCast(row),
        .col_offset = @intCast(col),
    });
}


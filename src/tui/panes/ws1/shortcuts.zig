const std = @import("std");
const vaxis = @import("vaxis");
const panes = @import("../../panes.zig");
const border = panes.border;
const types = @import("../../types.zig");
const State = types.State;
const EntryKind = types.EntryKind;

const Theme = struct {
    const fg_label = vaxis.Color{ .index = 245 }; // light gray
    const fg_key = vaxis.Color{ .index = 109 }; // muted cyan
    const fg_desc = vaxis.Color{ .index = 250 }; // muted white
    const fg_dim = vaxis.Color{ .index = 240 }; // gray
};

pub fn render(win: vaxis.Window, state: *State) void {
    border.draw(win, "cmds");

    var row: usize = 1; // Start after top border
    const max_h = if (win.height > 2) win.height - 2 else 0;
    if (max_h == 0) return;

    const entry = state.currentEntry();

    // Navigation
    printLine(win, row, 1, "↑/k", .{ .fg = Theme.fg_key, .bold = true });
    printLine(win, row, 6, "up", .{ .fg = Theme.fg_desc });
    row += 1;
    if (row >= max_h) return;

    printLine(win, row, 1, "↓/j", .{ .fg = Theme.fg_key, .bold = true });
    printLine(win, row, 6, "down", .{ .fg = Theme.fg_desc });
    row += 1;
    if (row >= max_h) return;

    printLine(win, row, 1, "←/h", .{ .fg = Theme.fg_key, .bold = true });
    printLine(win, row, 6, "back", .{ .fg = Theme.fg_desc });
    row += 1;
    if (row >= max_h) return;

    printLine(win, row, 1, "Enter", .{ .fg = Theme.fg_key, .bold = true });
    printLine(win, row, 8, "open", .{ .fg = Theme.fg_desc });
    row += 1;
    if (row >= max_h) return;

    row += 1;
    if (row >= max_h) return;

    // Context-specific actions
    if (entry) |e| {

        if (e.kind == .map) {
            printLine(win, row, 1, "r", .{ .fg = Theme.fg_key, .bold = true });
            printLine(win, row, 4, "run", .{ .fg = Theme.fg_desc });
            row += 1;
            if (row >= max_h) return;
        }
    }

    row += 1;
    if (row >= max_h) return;

    // Workspace switching
    printLine(win, row, 1, "1", .{ .fg = Theme.fg_key, .bold = true });
    printLine(win, row, 4, "Main", .{ .fg = Theme.fg_desc });
    row += 1;
    if (row >= max_h) return;

    printLine(win, row, 1, "2", .{ .fg = Theme.fg_key, .bold = true });
    printLine(win, row, 4, "Backtester", .{ .fg = Theme.fg_desc });
    row += 1;
    if (row >= max_h) return;

    row += 1;
    if (row >= max_h) return;

    // Quit
    printLine(win, row, 1, "q", .{ .fg = Theme.fg_key, .bold = true });
    printLine(win, row, 4, "quit", .{ .fg = Theme.fg_desc });
}

fn printLine(win: vaxis.Window, row: usize, col: usize, text: []const u8, style: vaxis.Style) void {
    const seg = vaxis.Cell.Segment{ .text = text, .style = style };
    _ = win.print(&[_]vaxis.Cell.Segment{seg}, .{
        .row_offset = @intCast(row),
        .col_offset = @intCast(col),
    });
}

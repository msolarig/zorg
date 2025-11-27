const dep = @import("../../dep.zig");

const std = dep.Stdlib.std;

const vaxis = dep.External.vaxis;

const State = dep.Types.State;

const border = dep.Panes.Shared.border;

const render_util = dep.TUIUtils.render_util;

const Theme = struct {
    const fg_label = vaxis.Color{ .index = 244 }; // gray (matching #888)
    const fg_value = vaxis.Color{ .index = 252 }; // light gray (matching #e0e0e0)
    const fg_header = vaxis.Color{ .index = 160 }; // red (matching #dc2626)
    const fg_dim = vaxis.Color{ .index = 244 }; // gray (matching #888)
};

pub fn render(win: vaxis.Window, state: *State) void {
    border.draw(win, "dataset");

    const engine = state.assembled_engine orelse {
        render_util.printLine(win, 1, 1, "No engine assembled", .{ .fg = Theme.fg_dim, .dim = true });
        return;
    };

    if (engine.track.size == 0) {
        render_util.printLine(win, 1, 1, "No data loaded", .{ .fg = Theme.fg_dim, .dim = true });
        return;
    }

    var row: usize = 1; // Start after top border
    const max_w = if (win.width > 2) win.width - 2 else 1;
    const max_h = if (win.height > 2) win.height - 2 else 0;

    // Header
    const header = "ts         op       hi       lo       cl       vo";
    const header_display = if (header.len > max_w - 1)
        (state.frameAlloc(header[0..@min(max_w - 1, header.len)]) catch return)
        else header;
    render_util.printLine(win, row, 1, header_display, .{ .fg = Theme.fg_header, .bold = true });
    row += 1;
    if (row >= max_h) return;

    const total_rows = engine.track.ts.items.len;
    const show_first = 5;
    const show_last = 5;
    const needs_separator = total_rows > show_first + show_last;

    // Show first 5 rows (newest first)
    var i: usize = 0;
    while (i < show_first and row < max_h) : (i += 1) {
        const idx = total_rows - 1 - i; // Show from newest to oldest
        if (idx >= total_rows) break;

        const ts = engine.track.ts.items[idx];
        const op = engine.track.op.items[idx];
        const hi = engine.track.hi.items[idx];
        const lo = engine.track.lo.items[idx];
        const cl = engine.track.cl.items[idx];
        const vo = engine.track.vo.items[idx];

        const ts_str = state.frameFmt("{d}", .{ts}) catch continue;
        const op_str = state.frameFmt("{d:.2}", .{op}) catch continue;
        const hi_str = state.frameFmt("{d:.2}", .{hi}) catch continue;
        const lo_str = state.frameFmt("{d:.2}", .{lo}) catch continue;
        const cl_str = state.frameFmt("{d:.2}", .{cl}) catch continue;
        const vo_str = state.frameFmt("{d}", .{vo}) catch continue;

        const line = state.frameFmt("{s:>10} {s:>8} {s:>8} {s:>8} {s:>8} {s:>10}", .{ ts_str, op_str, hi_str, lo_str, cl_str, vo_str }) catch continue;
        const line_display = if (line.len > max_w - 1)
            (state.frameAlloc(line[0..@min(max_w - 1, line.len)]) catch continue)
            else line;
        
        render_util.printLine(win, row, 1, line_display, .{ .fg = Theme.fg_value });
        row += 1;
    }

    // Show separator if we have both first and last
    if (needs_separator and row < max_h) {
        const sep_str = state.frameFmt("... ({d} rows) ...", .{total_rows - show_first - show_last}) catch return;
        // Truncate separator to fit within window
        const sep_display = if (sep_str.len > max_w - 2) sep_str[0..@min(sep_str.len, max_w - 2)] else sep_str;
        // Center the separator
        const sep_col = if (max_w > sep_display.len) (max_w - sep_display.len) / 2 + 1 else 1;
        render_util.printLine(win, row, @intCast(sep_col), sep_display, .{ .fg = Theme.fg_dim, .dim = true });
        row += 1;
    }

    // Show last 5 rows (oldest)
    i = 0;
    while (i < show_last and row < max_h) : (i += 1) {
        const idx = i; // Show oldest first (indices 0, 1, 2, 3, 4)
        if (idx >= total_rows) break;

        const ts = engine.track.ts.items[idx];
        const op = engine.track.op.items[idx];
        const hi = engine.track.hi.items[idx];
        const lo = engine.track.lo.items[idx];
        const cl = engine.track.cl.items[idx];
        const vo = engine.track.vo.items[idx];

        const ts_str = state.frameFmt("{d}", .{ts}) catch continue;
        const op_str = state.frameFmt("{d:.2}", .{op}) catch continue;
        const hi_str = state.frameFmt("{d:.2}", .{hi}) catch continue;
        const lo_str = state.frameFmt("{d:.2}", .{lo}) catch continue;
        const cl_str = state.frameFmt("{d:.2}", .{cl}) catch continue;
        const vo_str = state.frameFmt("{d}", .{vo}) catch continue;

        const line = state.frameFmt("{s:>10} {s:>8} {s:>8} {s:>8} {s:>8} {s:>10}", .{ ts_str, op_str, hi_str, lo_str, cl_str, vo_str }) catch continue;
        const line_display = if (line.len > max_w - 1)
            (state.frameAlloc(line[0..@min(max_w - 1, line.len)]) catch continue)
            else line;
        
        render_util.printLine(win, row, 1, line_display, .{ .fg = Theme.fg_value });
        row += 1;
    }

    // Show total data points counter after all rows
    if (row < max_h) {
        const total_str = state.frameFmt("Total: {d} data points", .{total_rows}) catch return;
        const total_col = if (max_w > total_str.len) (max_w - total_str.len) / 2 + 1 else 1;
        render_util.printLine(win, row, @intCast(total_col), total_str, .{ .fg = Theme.fg_dim, .dim = true });
    }
}



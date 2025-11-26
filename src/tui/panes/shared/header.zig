const std = @import("std");
const vaxis = @import("vaxis");
const types = @import("../../types.zig");
const State = types.State;

const Theme = struct {
    const bg = vaxis.Color{ .index = 236 }; // gunmetal
    const fg = vaxis.Color{ .index = 15 }; // bright white
    const accent = vaxis.Color{ .index = 208 }; // warning orange
    const fg_dim = vaxis.Color{ .index = 246 }; // steel gray
};

pub fn render(win: vaxis.Window, state: *State) void {
    // Single colored line on top
    const line_style = vaxis.Style{ .fg = Theme.accent, .bg = Theme.bg };
    for (0..win.width) |col| {
        const seg = vaxis.Cell.Segment{ .text = "─", .style = line_style };
        _ = win.print(&[_]vaxis.Cell.Segment{seg}, .{
            .row_offset = 0,
            .col_offset = @intCast(col),
        });
    }
    
    const rel_path = if (std.mem.startsWith(u8, state.cwd, state.root))
        state.cwd[state.root.len..]
    else
        state.relativePath(state.cwd);
    const clean_path = if (rel_path.len > 0 and rel_path[0] == '/') rel_path[1..] else rel_path;
    
    // Always prepend "usr/" to path
    const full_path = if (clean_path.len == 0) "usr/" else state.frameFmt("usr/{s}", .{clean_path}) catch "usr/";
    
    const ws_label = if (state.current_workspace == 2) "Backtester" else "Main";
    
    // Title and path on the line
    const title = "ZORG";
    const padding: usize = 2;
    const title_x = padding;
    
    const title_end = title_x + title.len;
    const ws_start = if (win.width > ws_label.len + padding) win.width - ws_label.len - padding else win.width;
    const path_max_len = if (ws_start > title_end + padding * 2) ws_start - title_end - padding * 2 else 10;
    
    const path_display = if (full_path.len > path_max_len)
        full_path[full_path.len - path_max_len..]
    else
        full_path;
    
    // Overlay title and path on the line
    printLine(win, 0, title_x, title, .{ .fg = Theme.accent, .bg = Theme.bg, .bold = true });
    const path_x = title_end + padding;
    printLine(win, 0, path_x, path_display, .{ .fg = Theme.fg, .bg = Theme.bg });
    printLine(win, 0, ws_start, ws_label, .{ .fg = Theme.accent, .bg = Theme.bg, .bold = true });
}

fn printLine(win: vaxis.Window, row: usize, col: usize, text: []const u8, style: vaxis.Style) void {
    const seg = vaxis.Cell.Segment{ .text = text, .style = style };
    _ = win.print(&[_]vaxis.Cell.Segment{seg}, .{
        .row_offset = @intCast(row),
        .col_offset = @intCast(col),
    });
}

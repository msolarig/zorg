const dep = @import("../../dep.zig");

const std = dep.Stdlib.std;

const vaxis = dep.External.vaxis;

const State = dep.Types.State;

const border = dep.Panes.Shared.border;

const render_util = dep.TUIUtils.render_util;
const tree_util = dep.TUIUtils.tree_util;

const Theme = struct {
    const fg_text = vaxis.Color{ .index = 255 }; // white
    const fg_dir = vaxis.Color{ .index = 24 }; // very dark blue (directories)
    const fg_file = vaxis.Color{ .index = 22 }; // very dark green (binaries)
    const fg_dim = vaxis.Color{ .index = 240 }; // very dark gray
};

pub fn render(win: vaxis.Window, state: *State) void {
    border.draw(win, "bin/");

    const content_h = if (win.height > 2) win.height - 2 else 0;
    const content_w = if (win.width > 2) win.width - 2 else 1;
    if (content_h == 0) return;

    const alloc = state.frame_arena.allocator();

    const bin_path = std.fmt.allocPrint(alloc, "{s}/zig-out/bin", .{state.project_root}) catch {
        render_util.printLine(win, 1, 1, "(cannot access bin)", .{ .fg = Theme.fg_dim, .dim = true });
        return;
    };

    const root = tree_util.buildTreeAlloc(alloc, bin_path) catch {
        render_util.printLine(win, 1, 1, "(cannot read bin)", .{ .fg = Theme.fg_dim, .dim = true });
        return;
    };

    var branch_stack: std.ArrayList(bool) = .{};
    var lines: std.ArrayList([]const u8) = .{};

    tree_util.flattenTreeSkipRoot(alloc, root, &branch_stack, &lines) catch {
        render_util.printLine(win, 1, 1, "(error building tree)", .{ .fg = Theme.fg_dim, .dim = true });
        return;
    };

    // Display tree lines (truncate if too long, show most recent if too many)
    const start = if (lines.items.len > content_h) lines.items.len - content_h else 0;
    var row: usize = 0;

    for (lines.items[start..]) |line| {
        if (row >= content_h) break;

        // Truncate line to fit window width
        const display_line = if (line.len > content_w) line[0..content_w] else line;

        const style: vaxis.Style = if (std.mem.endsWith(u8, line, ".dylib") or std.mem.endsWith(u8, line, ".so") or std.mem.endsWith(u8, line, ".dll")) .{
            .fg = Theme.fg_file,
        } else if (std.mem.indexOf(u8, line, "──") != null) .{
            .fg = Theme.fg_dir,
        } else .{
            .fg = Theme.fg_text,
        };

        render_util.printLine(win, row + 1, 1, display_line, style);
        row += 1;
    }
    
    // Show "... more" if content was truncated
    if (lines.items.len > start + content_h and content_h > 0) {
        const hidden = lines.items.len - (start + content_h);
        if (state.frameFmt("... +{d} more", .{hidden})) |more| {
            const more_display = if (more.len > content_w) more[0..content_w] else more;
            const more_row = @min(content_h, row);
            if (more_row > 0 and more_row <= content_h) {
                render_util.printLine(win, more_row, 1, more_display, .{ .fg = Theme.fg_dim, .dim = true });
            }
        } else |_| {}
    }
}



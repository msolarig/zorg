const std = @import("std");
const vaxis = @import("vaxis");

const Theme = struct {
    const border = vaxis.Color{ .index = 137 }; // brown-gray
    const label = vaxis.Color{ .index = 187 }; // warm beige
};

fn print(win: vaxis.Window, row: u16, col: u16, text: []const u8, style: vaxis.Style) void {
    const seg = vaxis.Cell.Segment{ .text = text, .style = style };
    _ = win.print(&[_]vaxis.Cell.Segment{seg}, .{
        .row_offset = row,
        .col_offset = col,
    });
}

pub fn draw(win: vaxis.Window, label: []const u8) void {
    const w = win.width;
    const h = win.height;

    if (w < 2 or h < 2) return;

    const border_style = vaxis.Style{ .fg = Theme.border, .bold = true };
    const label_style = vaxis.Style{ .fg = Theme.label, .italic = true };

    // Top border with label (rounded)
    if (label.len > 0 and w > label.len + 3) {
        print(win, 0, 0, "╭", border_style);
        print(win, 0, 1, label, label_style);
        print(win, 0, @intCast(1 + label.len), "─", border_style);
        // Fill rest of top border
        for (2 + label.len..w - 1) |col| {
            print(win, 0, @intCast(col), "─", border_style);
        }
        print(win, 0, @intCast(w - 1), "╮", border_style);
    } else {
        // Just corners if no label or too small (for prompt pane)
        print(win, 0, 0, "╭", border_style);
        for (1..w - 1) |col| {
            print(win, 0, @intCast(col), "─", border_style);
        }
        print(win, 0, @intCast(w - 1), "╮", border_style);
    }

    // Side borders
    for (1..h - 1) |row_usize| {
        const row: u16 = @intCast(row_usize);
        print(win, row, 0, "│", border_style);
        print(win, row, @intCast(w - 1), "│", border_style);
    }

    // Bottom border (rounded)
    print(win, @intCast(h - 1), 0, "╰", border_style);
    for (1..w - 1) |col| {
        print(win, @intCast(h - 1), @intCast(col), "─", border_style);
    }
    print(win, @intCast(h - 1), @intCast(w - 1), "╯", border_style);
}

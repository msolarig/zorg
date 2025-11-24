const std = @import("std");
const vaxis = @import("vaxis");

inline fn print(win: vaxis.Window, row: u16, col: u16, text: []const u8) void {
    const seg = vaxis.Cell.Segment{ .text = text, .style = .{} };
    _ = win.print(&[_]vaxis.Cell.Segment{seg}, .{
        .row_offset = row,
        .col_offset = col,
    });
}

pub fn draw(win: vaxis.Window, label: []const u8) void {
    const w = win.width;
    const h = win.height;

    if (w < 2 or h < 2) return;

    // ───────────────────────────────────────
    // TOP BORDER
    // ───────────────────────────────────────
    {
        print(win, 0, 0, "┌");
        var x: usize = 1;
        while (x < w - 1) : (x += 1) {
            print(win, 0, @intCast(x), "─");
        }
        print(win, 0, @intCast(w - 1), "┐");

        // optional centered label
        if (label.len > 0 and w > label.len + 4) {
            const col = (w / 2) - (label.len / 2);
            if (col < w - 1)
                print(win, 0, @intCast(col), label);
        }
    }

    // ───────────────────────────────────────
    // SIDE BORDERS
    // ───────────────────────────────────────
    for (1..h - 1) |row_usize| {
        const row = @as(u16, @intCast(row_usize));
        print(win, row, 0, "│");
        print(win, row, @intCast(w - 1), "│");
    }

    // ───────────────────────────────────────
    // BOTTOM BORDER
    // ───────────────────────────────────────
    const last = @as(u16, @intCast(h - 1));
    print(win, last, 0, "└");
    var x: usize = 1;
    while (x < w - 1) : (x += 1) {
        print(win, last, @intCast(x), "─");
    }
    print(win, last, @intCast(w - 1), "┘");
}

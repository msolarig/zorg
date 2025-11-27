const dep = @import("../dep.zig");

const vaxis = dep.External.vaxis;

pub fn printLine(win: vaxis.Window, row: usize, col: usize, text: []const u8, style: vaxis.Style) void {
    const seg = vaxis.Cell.Segment{ .text = text, .style = style };
    _ = win.print(&[_]vaxis.Cell.Segment{seg}, .{
        .row_offset = @intCast(row),
        .col_offset = @intCast(col),
    });
}


const std = @import("std");
const vaxis = @import("vaxis");
const border = @import("border.zig");
const path_util = @import("../../../utils/path_converter.zig");
const tree = @import("../fs/tree.zig");

pub fn render(win: vaxis.Window) !void {
    border.draw(win, "BROWSER");

    const alloc = std.heap.page_allocator;

    const project_root = try path_util.getProjectRootPath(alloc);
    const usr_path = try std.fs.path.join(alloc, &.{ project_root, "usr" });

    const root_node = tree.buildTreeAlloc(alloc, usr_path) catch |err| {
        printLine(win, 1, "ERROR: could not read usr/ directory", .{});
        std.debug.print("buildTreeAlloc error: {any}\n", .{err});
        return;
    };

    var rows: std.ArrayList([]const u8) = .{};

    try tree.flattenTree(alloc, root_node, &.{}, 0, &rows);

    var row: usize = 1;
    for (rows.items) |line| {
        if (row >= win.height) break;

        const max_len = win.width - 3;
        const clipped = line[0..@min(max_len, line.len)];

        printLine(win, row, clipped, .{});
        row += 1;
    }
}

fn printLine(win: vaxis.Window, row: usize, text: []const u8, style: vaxis.Style) void {
    const seg = vaxis.Cell.Segment{
        .text = text,
        .style = style,
    };

    _ = win.print(
        &[_]vaxis.Cell.Segment{seg},
        .{
            .row_offset = @intCast(row),
            .col_offset = 2,
        },
    );
}

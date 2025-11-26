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
    const fg_file = vaxis.Color{ .index = 66 }; // muted blue
    const bg = vaxis.Color{ .index = 235 }; // dark steel
};

pub fn render(win: vaxis.Window, state: *State) void {
    border.draw(win, "output");

    const result = state.execution_result orelse {
        printLine(win, 1, 1, "No execution yet", .{ .fg = Theme.fg_label, .dim = true });
        return;
    };

    var row: usize = 1; // Start after top border
    const max_w = if (win.width > 2) win.width - 2 else 1;
    const max_h = if (win.height > 2) win.height - 2 else 0;

    // Statistics section
    printLine(win, row, 1, "Statistics", .{ .fg = Theme.fg_accent, .bold = true });
    row += 1;
    if (row >= max_h) return;

    // Execution time
    if (state.frameFmt("Execution time: {d} ms", .{result.exec_time_ms})) |time_str| {
        printLine(win, row, 1, time_str, .{ .fg = Theme.fg_value });
    } else |_| {}
    row += 1;
    if (row >= max_h) return;

    // Data points
    if (state.frameFmt("Data points: {d}", .{result.data_points})) |points_str| {
        printLine(win, row, 1, points_str, .{ .fg = Theme.fg_value });
    } else |_| {}
    row += 1;
    if (row >= max_h) return;

    // Throughput (only if > 0)
    if (result.throughput > 0.0) {
        if (state.frameFmt("Throughput: {d:.1} pts/s", .{result.throughput})) |throughput_str| {
            printLine(win, row, 1, throughput_str, .{ .fg = Theme.fg_value });
        } else |_| {}
        row += 1;
    }
    if (row >= max_h) return;

    row += 1; // Spacing
    if (row >= max_h) return;

    // Output directory
    printLine(win, row, 1, "DIRECTORY", .{ .fg = Theme.fg_accent, .bold = true });
    row += 1;
    if (row >= max_h) return;

    const output_dir_rel = extractRelPathFromUsr(state, result.output_dir);
    const output_dir_display = if (output_dir_rel.len > max_w - 1) 
        (state.frameAlloc(output_dir_rel[0..@min(max_w - 1, output_dir_rel.len)]) catch return) 
        else output_dir_rel;
    printLine(win, row, 1, output_dir_display, .{ .fg = Theme.fg_value });
    row += 2;
    if (row >= max_h) return;

    // Files
    printLine(win, row, 1, "FILES", .{ .fg = Theme.fg_accent, .bold = true });
    row += 1;
    if (row >= max_h) return;

    if (result.success) {
        // Orders CSV
        const orders_rel = extractRelPathFromUsr(state, result.output_orders_path);
        const orders_display = if (orders_rel.len > max_w - 3)
            (state.frameAlloc(orders_rel[0..@min(max_w - 3, orders_rel.len)]) catch return)
            else orders_rel;
        printLine(win, row, 1, "f ", .{ .fg = Theme.fg_file });
        printLine(win, row, 3, orders_display, .{ .fg = Theme.fg_file });
        row += 1;
        if (row >= max_h) return;

        // Fills CSV
        const fills_rel = extractRelPathFromUsr(state, result.output_fills_path);
        const fills_display = if (fills_rel.len > max_w - 3)
            (state.frameAlloc(fills_rel[0..@min(max_w - 3, fills_rel.len)]) catch return)
            else fills_rel;
        printLine(win, row, 1, "f ", .{ .fg = Theme.fg_file });
        printLine(win, row, 3, fills_display, .{ .fg = Theme.fg_file });
        row += 1;
        if (row >= max_h) return;

        // Positions CSV
        const positions_rel = extractRelPathFromUsr(state, result.output_positions_path);
        const positions_display = if (positions_rel.len > max_w - 3)
            (state.frameAlloc(positions_rel[0..@min(max_w - 3, positions_rel.len)]) catch return)
            else positions_rel;
        printLine(win, row, 1, "f ", .{ .fg = Theme.fg_file });
        printLine(win, row, 3, positions_display, .{ .fg = Theme.fg_file });
    } else {
        printLine(win, row, 1, "(no files - execution failed)", .{ .fg = Theme.fg_label, .dim = true });
    }
}

fn extractRelPathFromUsr(state: *State, path: []const u8) []const u8 {
    // Look for "usr/" in the path
    if (std.mem.indexOf(u8, path, "usr/")) |idx| {
        const rel = path[idx..];
        if (std.mem.startsWith(u8, rel, "usr/")) {
            return rel;
        }
        if (idx > 0 and path[idx - 1] == '/') {
            return path[idx - 4..]; // Go back to include "usr/"
        }
        return rel;
    }
    // Fallback: try to find it relative to project root
    if (std.mem.startsWith(u8, path, state.project_root)) {
        const idx = state.project_root.len;
        if (path.len > idx) {
            const slice = path[idx..];
            if (slice.len > 0 and slice[0] == '/') {
                const full_slice = slice[1..];
                if (std.mem.indexOf(u8, full_slice, "usr/")) |usr_idx| {
                    return full_slice[usr_idx..];
                }
                return full_slice;
            }
            if (std.mem.indexOf(u8, slice, "usr/")) |usr_idx| {
                return slice[usr_idx..];
            }
            return slice;
        }
    }
    return std.fs.path.basename(path);
}

fn printLine(win: vaxis.Window, row: usize, col: usize, text: []const u8, style: vaxis.Style) void {
    const seg = vaxis.Cell.Segment{ .text = text, .style = style };
    _ = win.print(&[_]vaxis.Cell.Segment{seg}, .{
        .row_offset = @intCast(row),
        .col_offset = @intCast(col),
    });
}


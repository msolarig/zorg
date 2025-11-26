const std = @import("std");
const vaxis = @import("vaxis");
const panes = @import("../../panes.zig");
const border = panes.border;
const types = @import("../../types.zig");
const State = types.State;
const path_util = @import("../../../utils/path_utility.zig");

const Theme = struct {
    const fg_label = vaxis.Color{ .index = 137 }; // brown-gray
    const fg_value = vaxis.Color{ .index = 187 }; // warm beige
    const fg_accent = vaxis.Color{ .index = 66 }; // muted blue
    const fg_section = vaxis.Color{ .index = 66 }; // muted blue
    const fg_dim = vaxis.Color{ .index = 137 }; // brown-gray
};

pub fn render(win: vaxis.Window, state: *State) void {
    border.draw(win, "specs");

    const engine = state.assembled_engine orelse {
        printLine(win, 1, 1, "No engine assembled", .{ .fg = Theme.fg_dim, .dim = true });
        return;
    };

    var row: usize = 1; // Start after top border
    const max_w = if (win.width > 2) win.width - 2 else 1;
    const max_h = if (win.height > 2) win.height - 2 else 0;
    const col1_w = (max_w * 45) / 100; // 45% for labels
    const col2_w = max_w - col1_w - 2; // Remaining for values, minus spacing

    // Helper to print a label-value pair in 2 columns
    const printPair = struct {
        fn print(state_inner: *State, win_inner: vaxis.Window, row_inner: *usize, max_h_inner: usize, col1_w_inner: usize, col2_w_inner: usize, label: []const u8, value: []const u8, value_style: vaxis.Style) bool {
            if (row_inner.* >= max_h_inner) return false;
            const label_display = if (label.len > col1_w_inner - 1)
                (state_inner.frameAlloc(label[0..@min(col1_w_inner - 1, label.len)]) catch return false)
                else label;
            const value_display = if (value.len > col2_w_inner - 1)
                (state_inner.frameAlloc(value[0..@min(col2_w_inner - 1, value.len)]) catch return false)
                else value;
            printLine(win_inner, row_inner.*, 1, label_display, .{ .fg = Theme.fg_label });
            printLine(win_inner, row_inner.*, @intCast(col1_w_inner + 1), value_display, value_style);
            row_inner.* += 1;
            return true;
        }
    }.print;

    // Algorithm Configuration
    printLine(win, row, 1, "Algorithm", .{ .fg = Theme.fg_section, .bold = true });
    row += 1;
    if (row >= max_h) return;

    const auto_name = std.mem.span(engine.auto.api.name);
    const name_display = if (auto_name.len > col2_w - 1)
        (state.frameAlloc(auto_name[0..@min(col2_w - 1, auto_name.len)]) catch return)
        else auto_name;
    _ = printPair(state, win, &row, max_h, col1_w, col2_w, "  Name:", name_display, .{ .fg = Theme.fg_value });
    if (row >= max_h) return;

    const auto_desc = std.mem.span(engine.auto.api.desc);
    const desc_display = if (auto_desc.len > col2_w - 1)
        (state.frameAlloc(auto_desc[0..@min(col2_w - 1, auto_desc.len)]) catch return)
        else auto_desc;
    _ = printPair(state, win, &row, max_h, col1_w, col2_w, "  Description:", desc_display, .{ .fg = Theme.fg_value });
    if (row >= max_h) return;

    const auto_basename = std.fs.path.basename(engine.map.auto);
    const auto_path_display = if (auto_basename.len > col2_w - 1)
        (state.frameAlloc(auto_basename[0..@min(col2_w - 1, auto_basename.len)]) catch return)
        else auto_basename;
    _ = printPair(state, win, &row, max_h, col1_w, col2_w, "  Path:", auto_path_display, .{ .fg = Theme.fg_value });
    row += 1;
    if (row >= max_h) return;

    // Execution Configuration
    printLine(win, row, 1, "Execution", .{ .fg = Theme.fg_section, .bold = true });
    row += 1;
    if (row >= max_h) return;

    const mode_str = switch (engine.map.exec_mode) {
        .LiveExecution => "LIVE",
        .Backtest => "BACKTEST",
        .Optimization => "OPTIMIZATION",
    };
    const mode_color = switch (engine.map.exec_mode) {
        .LiveExecution => vaxis.Color{ .index = 95 }, // muted red
        .Backtest => vaxis.Color{ .index = 137 }, // muted brown
        .Optimization => vaxis.Color{ .index = 65 }, // muted green
    };
    _ = printPair(state, win, &row, max_h, col1_w, col2_w, "  Mode:", mode_str, .{ .fg = mode_color, .bold = true });
    row += 1;
    if (row >= max_h) return;

    // Data Source Configuration
    printLine(win, row, 1, "Data Source", .{ .fg = Theme.fg_section, .bold = true });
    row += 1;
    if (row >= max_h) return;

    const feed_str = switch (engine.map.feed_mode) {
        .Live => "LIVE",
        .SQLite3 => "SQLite3",
    };
    _ = printPair(state, win, &row, max_h, col1_w, col2_w, "  Feed Type:", feed_str, .{ .fg = Theme.fg_value });
    if (row >= max_h) return;

    const db_basename = std.fs.path.basename(engine.map.db);
    const db_display = if (db_basename.len > col2_w - 1)
        (state.frameAlloc(db_basename[0..@min(col2_w - 1, db_basename.len)]) catch return)
        else db_basename;
    _ = printPair(state, win, &row, max_h, col1_w, col2_w, "  Database:", db_display, .{ .fg = Theme.fg_value });
    if (row >= max_h) return;

    const table_display = if (engine.map.table.len > col2_w - 1)
        (state.frameAlloc(engine.map.table[0..@min(col2_w - 1, engine.map.table.len)]) catch return)
        else engine.map.table;
    _ = printPair(state, win, &row, max_h, col1_w, col2_w, "  Table:", table_display, .{ .fg = Theme.fg_value });
    row += 1;
    if (row >= max_h) return;

    // Data Statistics
    printLine(win, row, 1, "Data Statistics", .{ .fg = Theme.fg_section, .bold = true });
    row += 1;
    if (row >= max_h) return;

    const points_str = state.frameFmt("{d}", .{engine.track.size}) catch return;
    _ = printPair(state, win, &row, max_h, col1_w, col2_w, "  Data Points:", points_str, .{ .fg = Theme.fg_value });
    if (row >= max_h) return;

    const trail_str = state.frameFmt("{d}", .{engine.map.trail_size}) catch return;
    _ = printPair(state, win, &row, max_h, col1_w, col2_w, "  Trail Size:", trail_str, .{ .fg = Theme.fg_value });
    row += 1;
    if (row >= max_h) return;

    // Account Configuration
    printLine(win, row, 1, "Account", .{ .fg = Theme.fg_section, .bold = true });
    row += 1;
    if (row >= max_h) return;

    const balance_str = state.frameFmt("${d:.2}", .{engine.acc.balance}) catch return;
    _ = printPair(state, win, &row, max_h, col1_w, col2_w, "  Initial Balance:", balance_str, .{ .fg = Theme.fg_value });
    row += 1;
    if (row >= max_h) return;

    // Output Configuration
    printLine(win, row, 1, "Output", .{ .fg = Theme.fg_section, .bold = true });
    row += 1;
    if (row >= max_h) return;

    const output_display = if (engine.map.output.OUTPUT_DIR_NAME.len > col2_w - 1)
        (state.frameAlloc(engine.map.output.OUTPUT_DIR_NAME[0..@min(col2_w - 1, engine.map.output.OUTPUT_DIR_NAME.len)]) catch return)
        else engine.map.output.OUTPUT_DIR_NAME;
    _ = printPair(state, win, &row, max_h, col1_w, col2_w, "  Directory:", output_display, .{ .fg = Theme.fg_value });
}

fn printLine(win: vaxis.Window, row: usize, col: usize, text: []const u8, style: vaxis.Style) void {
    const seg = vaxis.Cell.Segment{ .text = text, .style = style };
    _ = win.print(&[_]vaxis.Cell.Segment{seg}, .{
        .row_offset = @intCast(row),
        .col_offset = @intCast(col),
    });
}


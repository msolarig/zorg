const dep = @import("../../dep.zig");

const std = dep.Stdlib.std;

const vaxis = dep.External.vaxis;

const State = dep.Types.State;

const border = dep.Panes.Shared.border;

const render_util = dep.TUIUtils.render_util;
const path_util = dep.TUIUtils.path_util;

const Theme = struct {
    const fg_label = vaxis.Color{ .index = 240 }; // very dark gray
    const fg_value = vaxis.Color{ .index = 255 }; // white
    const fg_accent = vaxis.Color{ .index = 240 }; // very dark gray
    const fg_file = vaxis.Color{ .index = 22 }; // very dark green
    const bg = vaxis.Color{ .index = 0 }; // black
};

pub fn render(win: vaxis.Window, state: *State) void {
    border.draw(win, "Execution Results");

    var row: usize = 1; // Start after top border
    const max_w = if (win.width > 2) win.width - 2 else 1;
    const max_h = if (win.height > 2) win.height - 2 else 0;

    const result = state.execution_result orelse {
        render_util.printLine(win, row, 1, "Not run yet", .{ .fg = Theme.fg_label, .dim = true });
        return;
    };

    // Status
    const status_text = if (result.success) "✓ SUCCESS" else "✗ FAILED";
    const status_color = if (result.success) vaxis.Color{ .index = 22 } else vaxis.Color{ .index = 52 }; // very dark green/red
    render_util.printLine(win, row, 1, status_text, .{ .fg = status_color, .bold = true });
    row += 2;
    if (row >= max_h) return;

    // Performance Metrics
    render_util.printLine(win, row, 1, "Performance", .{ .fg = Theme.fg_accent, .bold = true });
    row += 1;
    if (row >= max_h) return;

    // Total time
    if (state.frameFmt("Total: {d} ms", .{result.total_time_ms})) |time_str| {
        render_util.printLine(win, row, 1, time_str, .{ .fg = Theme.fg_value });
    } else |_| {}
    row += 1;
    if (row >= max_h) return;

    // Time breakdown
    const init_pct: f64 = if (result.total_time_ms > 0) 
        (@as(f64, @floatFromInt(result.init_time_ms)) / @as(f64, @floatFromInt(result.total_time_ms)) * 100.0) 
        else 0.0;
    const exec_pct: f64 = if (result.total_time_ms > 0) 
        (@as(f64, @floatFromInt(result.exec_time_ms)) / @as(f64, @floatFromInt(result.total_time_ms)) * 100.0) 
        else 0.0;
    
    if (state.frameFmt("Init: {d} ms ({d:.1}%)", .{ result.init_time_ms, init_pct })) |init_str| {
        render_util.printLine(win, row, 1, init_str, .{ .fg = Theme.fg_value });
    } else |_| {}
    row += 1;
    if (row >= max_h) return;

    if (state.frameFmt("Exec: {d} ms ({d:.1}%)", .{ result.exec_time_ms, exec_pct })) |exec_str| {
        render_util.printLine(win, row, 1, exec_str, .{ .fg = Theme.fg_value });
    } else |_| {}
    row += 1;
    if (row >= max_h) return;

    // Throughput
    if (result.throughput > 0.0) {
        if (state.frameFmt("Throughput: {d:.1} pts/s", .{result.throughput})) |throughput_str| {
            render_util.printLine(win, row, 1, throughput_str, .{ .fg = Theme.fg_value });
        } else |_| {}
        row += 1;
        if (row >= max_h) return;
    }

    // Average time per point
    const avg_time_per_point: f64 = if (result.data_points > 0)
        (@as(f64, @floatFromInt(result.exec_time_ms)) / @as(f64, @floatFromInt(result.data_points)))
        else 0.0;
    if (avg_time_per_point > 0.0) {
        if (state.frameFmt("Avg: {d:.3} ms/pt", .{avg_time_per_point})) |avg_str| {
            render_util.printLine(win, row, 1, avg_str, .{ .fg = Theme.fg_value });
        } else |_| {}
        row += 1;
        if (row >= max_h) return;
    }

    row += 1; // Spacing
    if (row >= max_h) return;

    // Data Processing
    render_util.printLine(win, row, 1, "Data Processing", .{ .fg = Theme.fg_accent, .bold = true });
    row += 1;
    if (row >= max_h) return;

    if (state.frameFmt("Points: {d}", .{result.data_points})) |points_str| {
        render_util.printLine(win, row, 1, points_str, .{ .fg = Theme.fg_value });
    } else |_| {}
    row += 1;
    if (row >= max_h) return;

    if (state.frameFmt("Trail: {d}", .{result.trail_size})) |trail_str| {
        render_util.printLine(win, row, 1, trail_str, .{ .fg = Theme.fg_value });
    } else |_| {}
    row += 1;
    if (row >= max_h) return;

    // Efficiency (points per second)
    const efficiency: f64 = if (result.exec_time_ms > 0)
        (@as(f64, @floatFromInt(result.data_points)) / (@as(f64, @floatFromInt(result.exec_time_ms)) / 1000.0))
        else 0.0;
    if (efficiency > 0.0) {
        if (state.frameFmt("Efficiency: {d:.0} pts/s", .{efficiency})) |eff_str| {
            render_util.printLine(win, row, 1, eff_str, .{ .fg = Theme.fg_value });
        } else |_| {}
        row += 1;
        if (row >= max_h) return;
    }

    row += 1; // Spacing
    if (row >= max_h) return;

    // Output directory
    render_util.printLine(win, row, 1, "Output", .{ .fg = Theme.fg_accent, .bold = true });
    row += 1;
    if (row >= max_h) return;

    const output_dir_rel = path_util.extractRelPathFromUsr(result.output_dir);
    const output_dir_display = if (output_dir_rel.len > max_w - 1) 
        (state.frameAlloc(output_dir_rel[0..@min(max_w - 1, output_dir_rel.len)]) catch return) 
        else output_dir_rel;
    render_util.printLine(win, row, 1, output_dir_display, .{ .fg = Theme.fg_value });
    row += 1;
    if (row >= max_h) return;

    // Files
    if (result.success) {
        const orders_rel = path_util.extractRelPathFromUsr(result.output_orders_path);
        const orders_display = if (orders_rel.len > max_w - 3)
            (state.frameAlloc(orders_rel[0..@min(max_w - 3, orders_rel.len)]) catch return)
            else orders_rel;
        render_util.printLine(win, row, 1, "f ", .{ .fg = Theme.fg_file });
        render_util.printLine(win, row, 3, orders_display, .{ .fg = Theme.fg_file });
        row += 1;
        if (row >= max_h) return;

        const fills_rel = path_util.extractRelPathFromUsr(result.output_fills_path);
        const fills_display = if (fills_rel.len > max_w - 3)
            (state.frameAlloc(fills_rel[0..@min(max_w - 3, fills_rel.len)]) catch return)
            else fills_rel;
        render_util.printLine(win, row, 1, "f ", .{ .fg = Theme.fg_file });
        render_util.printLine(win, row, 3, fills_display, .{ .fg = Theme.fg_file });
        row += 1;
        if (row >= max_h) return;

        const positions_rel = path_util.extractRelPathFromUsr(result.output_positions_path);
        const positions_display = if (positions_rel.len > max_w - 3)
            (state.frameAlloc(positions_rel[0..@min(max_w - 3, positions_rel.len)]) catch return)
            else positions_rel;
        render_util.printLine(win, row, 1, "f ", .{ .fg = Theme.fg_file });
        render_util.printLine(win, row, 3, positions_display, .{ .fg = Theme.fg_file });
    } else {
        render_util.printLine(win, row, 1, "(no files - execution failed)", .{ .fg = Theme.fg_label, .dim = true });
    }
}



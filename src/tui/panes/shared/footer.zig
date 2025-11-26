const std = @import("std");
const vaxis = @import("vaxis");
const types = @import("../../types.zig");
const State = types.State;
const Engine = @import("../../../engine/engine.zig").Engine;

const Theme = struct {
    const bg = vaxis.Color{ .index = 233 }; // deep charcoal
    const fg = vaxis.Color{ .index = 187 }; // warm beige
    const fg_accent = vaxis.Color{ .index = 66 }; // muted blue
    const fg_count = vaxis.Color{ .index = 137 }; // muted brown
};

pub fn render(win: vaxis.Window, state: *State) void {
    // Single colored line on top
    const line_style = vaxis.Style{ .fg = Theme.fg_accent, .bg = Theme.bg };
    for (0..win.width) |col| {
        const seg = vaxis.Cell.Segment{ .text = "─", .style = line_style };
        _ = win.print(&[_]vaxis.Cell.Segment{seg}, .{
            .row_offset = 0,
            .col_offset = @intCast(col),
        });
    }

    if (state.current_workspace == 2) {
        // Backtester workspace footer
        renderBacktesterFooter(win, state);
    } else {
        // Main workspace footer
        renderMainFooter(win, state);
    }
}

fn renderBacktesterFooter(win: vaxis.Window, state: *State) void {
    var col: usize = 0;

    // Engine status
    const engine_status = if (state.assembled_engine) |_| "Engine: Ready" else "Engine: Not assembled";
    const engine_color = if (state.assembled_engine) |_| Theme.fg_accent else Theme.fg_count;
    printLine(win, 0, col, engine_status, .{ .fg = engine_color, .bold = true });
    col += engine_status.len + 2;

    // Execution status
    const exec_status = if (state.execution_result) |_| "Exec: Complete" else "Exec: Not run";
    const exec_color = if (state.execution_result) |result| 
        (if (result.success) vaxis.Color{ .index = 65 } else vaxis.Color{ .index = 95 })
        else Theme.fg_count;
    printLine(win, 0, col, exec_status, .{ .fg = exec_color, .bold = true });
    col += exec_status.len + 2;

    // Data points if engine is assembled
    if (state.assembled_engine) |engine| {
        const data_text = state.frameFmt("Data: {d} pts", .{engine.track.size}) catch "Data: ?";
        printLine(win, 0, col, data_text, .{ .fg = Theme.fg_count, .bold = true });
        col += data_text.len + 2;
    }

    // Auto name if engine is assembled
    if (state.assembled_engine) |engine| {
        const auto_name = std.mem.span(engine.auto.api.name);
        const name_display = if (auto_name.len > 20) 
            (state.frameAlloc(auto_name[0..20]) catch return)
            else auto_name;
        const auto_text = state.frameFmt("Auto: {s}", .{name_display}) catch return;
        printLine(win, 0, col, auto_text, .{ .fg = Theme.fg, .dim = true });
        col += auto_text.len + 2;
    }

    // Right: help
    const help = "1:Main q:quit";
    const help_col = if (win.width > help.len) win.width - help.len else 0;
    printLine(win, 0, help_col, help, .{ .fg = Theme.fg, .dim = true });

    // Message (if any)
    if (state.message) |msg| {
        const msg_col = col + 2;
        if (msg_col < help_col - msg.len - 2) {
            printLine(win, 0, msg_col, msg, .{ .fg = Theme.fg_accent, .bold = true });
        }
    }
}

fn renderMainFooter(win: vaxis.Window, state: *State) void {
    // Technical status line - overlay on the line
    const entry = state.currentEntry();

    // Left: path and workspace
    const rel_path = if (std.mem.startsWith(u8, state.cwd, state.root))
        state.cwd[state.root.len..]
    else
        state.relativePath(state.cwd);
    const clean_path = if (rel_path.len > 0 and rel_path[0] == '/') rel_path[1..] else rel_path;
    
    // Always prepend "usr/" to path
    const full_path = if (clean_path.len == 0) "usr/" else state.frameFmt("usr/{s}", .{clean_path}) catch "usr/";
    const ws_label = "Main";
    
    // Truncate path if too long
    const path_max_len = 30;
    const path_display = if (full_path.len > path_max_len)
        full_path[full_path.len - path_max_len..]
    else
        full_path;
    
    const path_ws_text = state.frameFmt("{s} | {s}", .{ path_display, ws_label }) catch "usr/ | Main";
    printLine(win, 0, 0, path_ws_text, .{ .fg = Theme.fg_accent, .bold = true });
    var col: usize = path_ws_text.len + 2;

    // Position and stats
    var stats_text: []const u8 = "[0/0]";
    if (state.entries.items.len > 0) {
        // Count files and dirs
        var file_count: usize = 0;
        var dir_count: usize = 0;
        var total_size: u64 = 0;
        for (state.entries.items) |e| {
            if (e.is_dir) {
                dir_count += 1;
            } else {
                file_count += 1;
                total_size += e.size;
            }
        }
        
        const size_mb = @as(f64, @floatFromInt(total_size)) / (1024.0 * 1024.0);
        stats_text = state.frameFmt("[{d}/{d}] [{d}f {d}d {d:.1}MB]", .{ state.cursor + 1, state.entries.items.len, file_count, dir_count, size_mb }) catch "[?/?]";
    }
    printLine(win, 0, col, stats_text, .{ .fg = Theme.fg_count, .bold = true });
    col += stats_text.len + 2;

    // Current item with technical details
    if (entry) |e| {
        const type_str = switch (e.kind) {
            .directory => "DIR",
            .auto => "AUTO",
            .map => "MAP",
            .database => "DB",
            .file => "FILE",
            .unknown => "?",
        };
        printLine(win, 0, col, type_str, .{ .fg = Theme.fg_accent, .bold = true });
        col += type_str.len + 1;
        
        // Show size if file
        if (!e.is_dir) {
            const size_info = formatSize(e.size);
            if (state.frameFmt("{d:.0}{s}", .{ size_info.value, size_info.unit })) |size_str| {
                printLine(win, 0, col, size_str, .{ .fg = Theme.fg, .dim = true });
                col += size_str.len + 1;
            } else |_| {}
        }
    }

    // Right: help with context-specific commands
    var help: []const u8 = undefined;
    // Check for special file types that have commands
    if (entry) |e| {
        if (e.is_dir and isAutoDir(e.path)) {
            help = "2:Backtester q:quit";
        } else if (e.kind == .map) {
            help = "r:run 2:Backtester q:quit";
        } else {
            help = "2:Backtester q:quit";
        }
    } else {
        help = "2:Backtester q:quit";
    }
    const help_col = if (win.width > help.len) win.width - help.len else 0;
    printLine(win, 0, help_col, help, .{ .fg = Theme.fg, .dim = true });

    // Message (if any) - more prominent
    if (state.message) |msg| {
        const msg_col = col + 2;
        if (msg_col < help_col - msg.len - 2) {
            printLine(win, 0, msg_col, msg, .{ .fg = Theme.fg_accent, .bold = true });
        }
    }
}

fn isAutoDir(path: []const u8) bool {
    return std.mem.indexOf(u8, path, "/usr/auto/") != null or std.mem.indexOf(u8, path, "usr/auto/") != null;
}

fn formatSize(bytes: u64) struct { value: f64, unit: []const u8 } {
    if (bytes >= 1024 * 1024 * 1024) return .{ .value = @as(f64, @floatFromInt(bytes)) / (1024.0 * 1024.0 * 1024.0), .unit = "G" };
    if (bytes >= 1024 * 1024) return .{ .value = @as(f64, @floatFromInt(bytes)) / (1024.0 * 1024.0), .unit = "M" };
    if (bytes >= 1024) return .{ .value = @as(f64, @floatFromInt(bytes)) / 1024.0, .unit = "K" };
    return .{ .value = @floatFromInt(bytes), .unit = "B" };
}

fn printLine(win: vaxis.Window, row: usize, col: usize, text: []const u8, style: vaxis.Style) void {
    const seg = vaxis.Cell.Segment{ .text = text, .style = style };
    _ = win.print(&[_]vaxis.Cell.Segment{seg}, .{
        .row_offset = @intCast(row),
        .col_offset = @intCast(col),
    });
}

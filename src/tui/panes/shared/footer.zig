const dep = @import("../../dep.zig");

const std = dep.Stdlib.std;

const vaxis = dep.External.vaxis;

const State = dep.Types.State;

const Engine = dep.Engine.Engine;

const render_util = dep.TUIUtils.render_util;
const format_util = dep.TUIUtils.format_util;
const path_util = dep.TUIUtils.path_util;

// Version info from entrypoint (via root module)
const zorg = @import("root");
const zdk_abi = @import("zdk");

const Theme = struct {
    const bg = vaxis.Color{ .index = 0 }; // black
    const fg = vaxis.Color{ .index = 252 }; // light gray (matching #e0e0e0)
    const fg_accent = vaxis.Color{ .index = 160 }; // red (matching #dc2626)
    const fg_count = vaxis.Color{ .index = 244 }; // gray (matching #888)
};

pub fn render(win: vaxis.Window, state: *State) void {
    // Clear the entire footer row
    win.clear();

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

    // Version info on far left - use comptime constant
    const version_info = comptime blk: {
        const ver = std.fmt.comptimePrint("Zorg {s} ZDK {d}.0.0", .{zorg.ZORG_VERSION, zdk_abi.ZDK_VERSION / 1_000_000});
        break :blk ver;
    };
    render_util.printLine(win, 0, col, version_info, .{ .fg = Theme.fg_count });
    col += version_info.len + 2;

    // Engine status
    const engine_status = if (state.assembled_engine) |_| "Engine: Ready" else "Engine: Not assembled";
    const engine_color = if (state.assembled_engine) |_| Theme.fg_accent else Theme.fg_count;
    render_util.printLine(win, 0, col, engine_status, .{ .fg = engine_color });
    col += engine_status.len + 2;

    // Execution status
    const exec_status = if (state.execution_result) |_| "Exec: Complete" else "Exec: Not run";
    const exec_color = if (state.execution_result) |_| 
        vaxis.Color{ .index = 35 } // bright green (matching #22c55e)
        else vaxis.Color{ .index = 160 }; // red (matching #dc2626)
    render_util.printLine(win, 0, col, exec_status, .{ .fg = exec_color });
    col += exec_status.len + 2;

    // Data points if engine is assembled
    if (state.assembled_engine) |engine| {
        const data_text = state.frameFmt("Data: {d} pts", .{engine.track.size}) catch "Data: ?";
        render_util.printLine(win, 0, col, data_text, .{ .fg = Theme.fg_count });
        col += data_text.len + 2;
    }

    // Auto name if engine is assembled
    if (state.assembled_engine) |engine| {
        const auto_name = std.mem.span(engine.auto.api.name);
        const name_display = if (auto_name.len > 20) 
            (state.frameAlloc(auto_name[0..20]) catch return)
            else auto_name;
        const auto_text = state.frameFmt("Auto: {s}", .{name_display}) catch return;
        render_util.printLine(win, 0, col, auto_text, .{ .fg = Theme.fg, .dim = true });
        col += auto_text.len + 2;
    }

    // Right side: action hints only
    const help = "1:Main q:quit";
    const help_col = if (win.width > help.len) win.width - help.len else 0;
    render_util.printLine(win, 0, help_col, help, .{ .fg = Theme.fg, .dim = true });

    // Message (if any)
    if (state.message) |msg| {
        const msg_col = col + 2;
        if (msg_col < help_col - msg.len - 2) {
            render_util.printLine(win, 0, msg_col, msg, .{ .fg = Theme.fg_accent });
        }
    }
}

fn renderMainFooter(win: vaxis.Window, state: *State) void {
    const entry = state.currentEntry();

    // Format: VERSION Main [position/total] path TYPE
    var col: usize = 0;
    
    // Version info on far left - use comptime constant
    const version_info = comptime blk: {
        const ver = std.fmt.comptimePrint("Zorg {s} ZDK {d}.0.0", .{zorg.ZORG_VERSION, zdk_abi.ZDK_VERSION / 1_000_000});
        break :blk ver;
    };
    render_util.printLine(win, 0, col, version_info, .{ .fg = Theme.fg_count });
    col += version_info.len + 2;
    
    // Workspace label
    render_util.printLine(win, 0, col, "Main", .{ .fg = Theme.fg });
    col += 5; // "Main "

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
    render_util.printLine(win, 0, col, stats_text, .{ .fg = Theme.fg_count });
    col += stats_text.len + 1;

    // Path
    const rel_path = if (std.mem.startsWith(u8, state.cwd, state.root))
        state.cwd[state.root.len..]
    else
        state.relativePath(state.cwd);
    const clean_path = if (rel_path.len > 0 and rel_path[0] == '/') rel_path[1..] else rel_path;
    const full_path = if (clean_path.len == 0) "usr/" else state.frameFmt("usr/{s}", .{clean_path}) catch "usr/";
    
    const path_max_len = 40;
    const path_display = if (full_path.len > path_max_len)
        full_path[full_path.len - path_max_len..]
    else
        full_path;
    
    render_util.printLine(win, 0, col, path_display, .{ .fg = Theme.fg, .dim = true });
    col += path_display.len + 1;

    // Current item type
    if (entry) |e| {
        const type_str = switch (e.kind) {
            .directory => "DIR",
            .auto => "AUTO",
            .map => "MAP",
            .database => "DB",
            .file => "FILE",
            .unknown => "?",
        };
        render_util.printLine(win, 0, col, type_str, .{ .fg = Theme.fg_accent });
        col += type_str.len + 2;
    }

    // Right side: action hints only
    const help = "2:Backtester q:quit";
    const help_col = if (win.width > help.len) win.width - help.len else 0;
    render_util.printLine(win, 0, help_col, help, .{ .fg = Theme.fg, .dim = true });

    // Message (if any) - in the middle space, won't overlap type
    if (state.message) |msg| {
        const msg_col = col + 2;
        if (msg_col < help_col - msg.len - 2) {
            render_util.printLine(win, 0, msg_col, msg, .{ .fg = Theme.fg_accent });
        }
    }
}

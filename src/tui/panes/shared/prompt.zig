const dep = @import("../../dep.zig");

const std = dep.Stdlib.std;
const vaxis = dep.External.vaxis;

const State = dep.Types.State;

const border = dep.Panes.Shared.border;
const format_util = dep.TUIUtils.format_util;

const Theme = struct {
    const fg_active = vaxis.Color{ .index = 252 }; // light gray (matching #e0e0e0)
    const fg_inactive = vaxis.Color{ .index = 244 }; // gray (matching #888)
};

pub fn render(win: vaxis.Window, state: *State) void {
    border.draw(win, "");
    
    const content_w = if (win.width > 3) win.width - 3 else 1; // Account for left border, right border, right space
    
    if (state.prompt_mode) {
        // Active: show only > and command in white
        const prompt_style = vaxis.Style{ .fg = Theme.fg_active };
        const prompt_text_slice = state.prompt_text.items;
        const prompt_display = if (prompt_text_slice.len > 0)
            state.frameFmt("> {s}", .{prompt_text_slice}) catch ">"
        else
            ">";
        // Truncate prompt to fit window
        const prompt_truncated = if (prompt_display.len > content_w) prompt_display[0..content_w] else prompt_display;
        const seg = vaxis.Cell.Segment{ .text = prompt_truncated, .style = prompt_style };
        _ = win.print(&[_]vaxis.Cell.Segment{seg}, .{ .row_offset = 1, .col_offset = 2 });
    } else {
        // Inactive: show stats in dark gray
        const stats = getQuickStats(state) catch "Loading stats...";
        // Truncate stats to fit window
        const stats_truncated = if (stats.len > content_w) stats[0..content_w] else stats;
        const inactive_style = vaxis.Style{ .fg = Theme.fg_inactive };
        const seg = vaxis.Cell.Segment{ .text = stats_truncated, .style = inactive_style };
        _ = win.print(&[_]vaxis.Cell.Segment{seg}, .{ .row_offset = 1, .col_offset = 2 });
    }
}

fn getQuickStats(state: *State) ![]const u8 {
    const alloc = state.frame_arena.allocator();
    
    // Count map files in usr/map/
    const map_count = countMaps(alloc, state.project_root) catch 0;
    const map_text = if (map_count == 1) "Map" else "Maps";
    
    // Count compiled autos in zig-out/bin/auto/
    const auto_count = countCompiledAutos(alloc, state.project_root) catch 0;
    
    // Count database files in usr/data/
    const db_count = countDatabases(alloc, state.project_root) catch 0;
    const db_text = if (db_count == 1) "DB" else "DBs";
    
    // Get total data size in usr/data/
    const data_size = getDataSize(alloc, state.project_root) catch 0;
    const size_info = format_util.formatSize(data_size);
    
    return state.frameFmt("> ~  │  {d} {s}  │  {d} {s}  │  {d} Compiled Autos  │  {d:.1}{s} Bin", .{
        map_count,
        map_text,
        db_count,
        db_text,
        auto_count,
        size_info.value,
        size_info.unit,
    });
}

fn countMaps(alloc: std.mem.Allocator, project_root: []const u8) !usize {
    const map_dir_path = try std.fmt.allocPrint(alloc, "{s}/usr/map", .{project_root});
    defer alloc.free(map_dir_path);
    
    var dir = std.fs.cwd().openDir(map_dir_path, .{ .iterate = true }) catch return 0;
    defer dir.close();
    
    var count: usize = 0;
    var iter = dir.iterate();
    while (try iter.next()) |entry| {
        if (entry.kind == .file and (std.mem.endsWith(u8, entry.name, ".jsonc") or 
                                      std.mem.endsWith(u8, entry.name, ".json"))) {
            count += 1;
        }
    }
    return count;
}

fn countCompiledAutos(alloc: std.mem.Allocator, project_root: []const u8) !usize {
    const auto_dir_path = try std.fmt.allocPrint(alloc, "{s}/zig-out/bin/auto", .{project_root});
    defer alloc.free(auto_dir_path);
    
    var dir = std.fs.cwd().openDir(auto_dir_path, .{ .iterate = true }) catch return 0;
    defer dir.close();
    
    var count: usize = 0;
    var iter = dir.iterate();
    while (try iter.next()) |entry| {
        if (entry.kind == .file and (std.mem.endsWith(u8, entry.name, ".dylib") or 
                                      std.mem.endsWith(u8, entry.name, ".so") or 
                                      std.mem.endsWith(u8, entry.name, ".dll"))) {
            count += 1;
        }
    }
    return count;
}

fn countDatabases(alloc: std.mem.Allocator, project_root: []const u8) !usize {
    const data_dir_path = try std.fmt.allocPrint(alloc, "{s}/usr/data", .{project_root});
    defer alloc.free(data_dir_path);
    
    var dir = std.fs.cwd().openDir(data_dir_path, .{ .iterate = true }) catch return 0;
    defer dir.close();
    
    var count: usize = 0;
    var iter = dir.iterate();
    while (try iter.next()) |entry| {
        if (entry.kind == .file and std.mem.endsWith(u8, entry.name, ".db")) {
            count += 1;
        }
    }
    return count;
}

fn getDataSize(alloc: std.mem.Allocator, project_root: []const u8) !u64 {
    const data_dir_path = try std.fmt.allocPrint(alloc, "{s}/usr/data", .{project_root});
    defer alloc.free(data_dir_path);
    
    var dir = std.fs.cwd().openDir(data_dir_path, .{ .iterate = true }) catch return 0;
    defer dir.close();
    
    var total_size: u64 = 0;
    var iter = dir.iterate();
    while (try iter.next()) |entry| {
        if (entry.kind == .file) {
            const file_path = try std.fmt.allocPrint(alloc, "{s}/{s}", .{ data_dir_path, entry.name });
            defer alloc.free(file_path);
            
            const file = std.fs.cwd().openFile(file_path, .{}) catch continue;
            defer file.close();
            
            const size = file.getEndPos() catch 0;
            total_size += size;
        }
    }
    return total_size;
}


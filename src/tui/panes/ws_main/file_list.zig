const dep = @import("../../dep.zig");

const std = dep.Stdlib.std;

const vaxis = dep.External.vaxis;

const State = dep.Types.State;
const EntryKind = dep.Types.EntryKind;

const border = dep.Panes.Shared.border;

const render_util = dep.TUIUtils.render_util;
const format_util = dep.TUIUtils.format_util;
const path_util = dep.TUIUtils.path_util;

const Theme = struct {
    const bg_normal = vaxis.Color{ .index = 0 }; // black
    const bg_cursor = vaxis.Color{ .index = 0 }; // black (no highlight)
    const fg_normal = vaxis.Color{ .index = 255 }; // white
    const fg_dir = vaxis.Color{ .index = 24 }; // very dark blue (directories)
    const fg_auto = vaxis.Color{ .index = 22 }; // very dark green (autos)
    const fg_map = vaxis.Color{ .index = 58 }; // very dark orange (config)
    const fg_db = vaxis.Color{ .index = 24 }; // very dark blue (database)
    const fg_cursor = vaxis.Color{ .index = 255 }; // white
    const fg_badge = vaxis.Color{ .index = 240 }; // very dark gray
    const fg_meta = vaxis.Color{ .index = 240 }; // very dark gray (subtle)
};

// Icon function removed - using badges instead

fn getColor(kind: EntryKind) vaxis.Color {
    return switch (kind) {
        .directory => Theme.fg_dir,
        .auto => Theme.fg_auto,
        .map => Theme.fg_map,
        .database => Theme.fg_db,
        .file, .unknown => Theme.fg_normal,
    };
}

fn getTypeBadge(kind: EntryKind, name: []const u8) []const u8 {
    // For .zig files, show ZIG instead of AUTO
    if (kind == .auto and std.mem.endsWith(u8, name, ".zig")) {
        return "ZIG";
    }
    return switch (kind) {
        .directory => "DIR",
        .auto => "AUTO",
        .map => "MAP",
        .database => "DB",
        .file => getFileExtensionBadge(name),
        .unknown => "?",
    };
}

fn getTypeBadgeColor(kind: EntryKind, name: []const u8) vaxis.Color {
    // Color code based on type - muted for long sessions
    if (kind == .directory) {
        return vaxis.Color{ .index = 24 }; // very dark blue
    }
    if (kind == .database) {
        return vaxis.Color{ .index = 24 }; // very dark blue
    }
    // Check for .zig files (even if classified as .auto)
    if (std.mem.endsWith(u8, name, ".zig")) {
        return vaxis.Color{ .index = 22 }; // very dark green
    }
    // Check for .json/.jsonc files
    if (kind == .map or std.mem.endsWith(u8, name, ".json") or std.mem.endsWith(u8, name, ".jsonc")) {
        return vaxis.Color{ .index = 58 }; // very dark orange
    }
    // Default color for other files
    return vaxis.Color{ .index = 255 }; // white
}

fn getFileExtensionBadge(name: []const u8) []const u8 {
    if (std.mem.lastIndexOfScalar(u8, name, '.')) |dot_idx| {
        if (dot_idx + 1 < name.len) {
            const ext = name[dot_idx + 1..];
            // Return static strings for common extensions (uppercase)
            if (std.mem.eql(u8, ext, "zig")) return "ZIG";
            if (std.mem.eql(u8, ext, "db")) return "DB";
            if (std.mem.eql(u8, ext, "sqlite")) return "DB";
            if (std.mem.eql(u8, ext, "json")) return "JSON";
            if (std.mem.eql(u8, ext, "jsonc")) return "JSON";
            if (std.mem.eql(u8, ext, "md")) return "MD";
            if (std.mem.eql(u8, ext, "txt")) return "TXT";
            if (std.mem.eql(u8, ext, "py")) return "PY";
            if (std.mem.eql(u8, ext, "sh")) return "SH";
            if (std.mem.eql(u8, ext, "zsh")) return "SH";
            if (std.mem.eql(u8, ext, "dylib")) return "DYLIB";
            if (std.mem.eql(u8, ext, "so")) return "SO";
            if (std.mem.eql(u8, ext, "dll")) return "DLL";
            if (std.mem.eql(u8, ext, "exe")) return "EXE";
            if (std.mem.eql(u8, ext, "csv")) return "CSV";
            if (std.mem.eql(u8, ext, "toml")) return "TOML";
            if (std.mem.eql(u8, ext, "yaml") or std.mem.eql(u8, ext, "yml")) return "YAML";
            // For unknown extensions, try to show first 4 chars uppercase
            if (ext.len <= 4) {
                // We can't dynamically uppercase here, so return FILE for unknown
                return "FILE";
            }
        }
    }
    return "FILE";
}

fn getAutoStatus(state: *State, path: []const u8) []const u8 {
    // Check if .dylib exists for this auto
    const auto_name = std.fs.path.basename(path);
    const dylib_path = state.frameFmt("{s}/zig-out/bin/auto/{s}.dylib", .{ state.project_root, auto_name }) catch return "";
    
    if (std.fs.cwd().access(dylib_path, .{})) |_| {
        return "[OK]";
    } else |_| {
        return "[BUILD]";
    }
}


fn getModifiedTime(path: []const u8) ![]const u8 {
    const stat = if (std.fs.cwd().openFile(path, .{})) |file| blk: {
        defer file.close();
        break :blk try file.stat();
    } else |err| if (err == error.IsDir) blk: {
        var dir = try std.fs.cwd().openDir(path, .{});
        defer dir.close();
        break :blk try dir.stat();
    } else {
        return err;
    };
    
    return formatTimestamp(@intCast(stat.mtime));
}

fn formatTimestamp(mtime: i64) []const u8 {
    // More detailed relative time
    const now = std.time.timestamp();
    const diff = now - mtime;
    
    if (diff < 60) return "now";
    if (diff < 3600) {
        const mins = @divTrunc(diff, 60);
        if (mins == 1) return "1m";
        return "m";
    }
    if (diff < 86400) {
        const hrs = @divTrunc(diff, 3600);
        if (hrs == 1) return "1h";
        return "h";
    }
    if (diff < 604800) {
        const days = @divTrunc(diff, 86400);
        if (days == 1) return "1d";
        return "d";
    }
    if (diff < 2592000) {
        const weeks = @divTrunc(diff, 604800);
        if (weeks == 1) return "1w";
        return "w";
    }
    return "old";
}


const DirStats = struct {
    total: usize,
    files: usize,
    dirs: usize,
    total_size: u64,
};

fn getDirectoryStats(path: []const u8) !DirStats {
    var dir = std.fs.cwd().openDir(path, .{ .iterate = true }) catch return error.CannotOpen;
    defer dir.close();

    var stats = DirStats{
        .total = 0,
        .files = 0,
        .dirs = 0,
        .total_size = 0,
    };

    var iter = dir.iterate();
    while (iter.next() catch null) |entry| {
        if (entry.name.len > 0 and entry.name[0] == '.') continue;

        stats.total += 1;
        if (entry.kind == .directory) {
            stats.dirs += 1;
        } else {
            stats.files += 1;
            const file_size = getFileSize(dir, entry.name) catch 0;
            stats.total_size += file_size;
        }
    }

    return stats;
}

fn getFileSize(dir: std.fs.Dir, name: []const u8) !u64 {
    const file = dir.openFile(name, .{}) catch return 0;
    defer file.close();
    const stat = try file.stat();
    return stat.size;
}

fn getPermissions(path: []const u8) ![]const u8 {
    const stat = if (std.fs.cwd().openFile(path, .{})) |file| blk: {
        defer file.close();
        break :blk try file.stat();
    } else |err| if (err == error.IsDir) blk: {
        var dir = try std.fs.cwd().openDir(path, .{});
        defer dir.close();
        break :blk try dir.stat();
    } else {
        return err;
    };
    
    return formatPerms(stat.mode);
}

fn formatPerms(mode: std.fs.File.Mode) []const u8 {
    // Only show user (owner) permissions, not group/other
    const r = (mode & 0o400) != 0; // user read
    const w = (mode & 0o200) != 0; // user write
    const x = (mode & 0o100) != 0; // user execute
    
    if (r and w and x) return "rwx";
    if (r and w) return "rw-";
    if (r and x) return "r-x";
    if (r) return "r--";
    if (w) return "-w-";
    if (x) return "--x";
    return "---";
}

fn calculateDepth(state: *State, path: []const u8) usize {
    // Get relative path from root
    const rel_path = if (std.mem.startsWith(u8, path, state.root))
        path[state.root.len..]
    else
        state.relativePath(path);
    
    // Count path separators to determine depth
    var depth: usize = 0;
    for (rel_path) |char| {
        if (char == '/') {
            depth += 1;
        }
    }
    return depth;
}

pub fn render(win: vaxis.Window, state: *State) void {
    // Calculate current path relative to usr/
    var path_label: []const u8 = "usr/";
    if (!std.mem.eql(u8, state.cwd, state.root)) {
        // Get relative path from root
        if (std.mem.startsWith(u8, state.cwd, state.root)) {
            const rel_path = state.cwd[state.root.len..];
            // Remove leading slash if present
            const clean_path = if (rel_path.len > 0 and rel_path[0] == '/') rel_path[1..] else rel_path;
            if (clean_path.len > 0) {
                // Format as "usr/path" using frame allocator
                path_label = state.frameFmt("usr/{s}", .{clean_path}) catch "usr/";
            }
        }
    }
    border.draw(win, path_label);

    // Content area (inside borders)
    const content_h = if (win.height > 2) win.height - 2 else 0;
    const content_w = if (win.width > 2) win.width - 2 else 1;

    // Adjust scroll offset to keep cursor visible
    if (state.cursor < state.scroll_offset) {
        state.scroll_offset = state.cursor;
    } else if (state.cursor >= state.scroll_offset + content_h) {
        state.scroll_offset = state.cursor - content_h + 1;
    }

    if (state.entries.items.len == 0) {
        render_util.printLine(win, 1, 1, "(empty)", .{
            .fg = Theme.fg_normal,
            .dim = true,
        });
        return;
    }

    var row: usize = 0;
    const start = state.scroll_offset;
    const end = @min(start + content_h, state.entries.items.len);

    for (state.entries.items[start..end], start..) |entry, idx| {
        const is_cursor = idx == state.cursor;

        // Remove color mask - use uniform color for all files/directories
        const style = vaxis.Style{
            .fg = Theme.fg_normal,
        };

        // Index display (absolute and relative, XPLR-style)
        var col: usize = 1; // Start after left border
        
        // Calculate relative index (distance from cursor)
        const relative_idx: i64 = @as(i64, @intCast(idx)) - @as(i64, @intCast(state.cursor));
        
        // Format indexes: "abs:rel" or just "abs" if at cursor
        const abs_idx_str = state.frameFmt("{d}", .{idx + 1}) catch "?";
        var index_str: []const u8 = undefined;
        if (relative_idx == 0) {
            // At cursor, show only absolute index
            index_str = abs_idx_str;
        } else {
            // Show absolute:relative
            const rel_idx_str = state.frameFmt("{d}", .{relative_idx}) catch "?";
            index_str = state.frameFmt("{s}:{s}", .{ abs_idx_str, rel_idx_str }) catch abs_idx_str;
        }
        
        // Print index (muted, right-aligned in a fixed-width column)
        const index_width = 8; // Fixed width for index column
        const index_col = col;
        if (index_str.len < index_width) {
            // Right-align the index
            const padding = index_width - index_str.len;
            for (0..padding) |_| {
                render_util.printLine(win, row + 1, col, " ", .{ .fg = Theme.fg_meta, .dim = true });
                col += 1;
            }
        }
        render_util.printLine(win, row + 1, col, index_str, .{ .fg = if (is_cursor) Theme.fg_cursor else Theme.fg_meta, .dim = !is_cursor });
        col = index_col + index_width + 1; // Move past index column with spacing

        // Selection indicator: '>' for cursor
        if (is_cursor) {
            render_util.printLine(win, row + 1, col, ">", .{ .fg = Theme.fg_cursor });
            col += 1;
        } else {
            col += 1; // Keep alignment
        }

        // Type badge with color coding - brackets turn red if selected
        const is_selected = state.selected_paths.contains(entry.path);
        const type_badge = getTypeBadge(entry.kind, entry.name);
        const badge_color = getTypeBadgeColor(entry.kind, entry.name);
        const bracket_color = if (is_selected)
            vaxis.Color{ .index = 255 } // white for selected
        else
            Theme.fg_meta; // Normal color
        const bracket_style = vaxis.Style{ .fg = bracket_color, .dim = true };
        
        render_util.printLine(win, row + 1, col, "[", bracket_style);
        render_util.printLine(win, row + 1, col + 1, type_badge, .{ .fg = badge_color });
        render_util.printLine(win, row + 1, col + 1 + type_badge.len, "]", bracket_style);
        col += type_badge.len + 3;

        // Name (with '/' suffix for directories)
        var display_name = entry.name;
        if (entry.is_dir) {
            // Append '/' to directory names
            const name_with_slash = state.frameFmt("{s}/", .{entry.name}) catch entry.name;
            display_name = name_with_slash;
        } else {
            display_name = state.frameAlloc(entry.name) catch break;
        }
        render_util.printLine(win, row + 1, col, display_name, style);
        const name_end_col = col + display_name.len;

        // Right-aligned metadata: collect all metadata first
        var meta_parts: [8][]const u8 = undefined;
        var meta_styles: [8]vaxis.Style = undefined;
        var meta_count: usize = 0;

        // File extension (for files)
        if (!entry.is_dir) {
            const ext = path_util.getFileExtension(entry.name);
            if (ext.len > 0) {
                meta_parts[meta_count] = ext;
                meta_styles[meta_count] = .{ .fg = Theme.fg_dir, .dim = false }; // Muted cyan, not dim
                meta_count += 1;
            }
        }

        // Size (always show, more detailed)
        if (entry.is_dir) {
            // For directories, show depth
            const depth = calculateDepth(state, entry.path);
            if (state.frameFmt("~{d}", .{depth})) |depth_str| {
                meta_parts[meta_count] = depth_str;
                meta_styles[meta_count] = .{ .fg = Theme.fg_dir, .dim = false };
                meta_count += 1;
            } else |_| {}
            
            // Also show item count if available
            const dir_stats = getDirectoryStats(entry.path) catch null;
            if (dir_stats) |stats| {
                if (state.frameFmt("{d}i", .{stats.total})) |items_str| {
                    meta_parts[meta_count] = items_str;
                    meta_styles[meta_count] = .{ .fg = Theme.fg_meta, .dim = true };
                    meta_count += 1;
                } else |_| {}
            }
        } else {
            const size_info = format_util.formatSize(entry.size);
            if (state.frameFmt("{d:.1}{s}", .{ size_info.value, size_info.unit })) |size_str| {
                meta_parts[meta_count] = size_str;
                meta_styles[meta_count] = .{ .fg = Theme.fg_meta, .dim = true };
                meta_count += 1;
            } else |_| {}
        }

        // Modified time (more detailed)
        const mtime = getModifiedTime(entry.path) catch null;
        if (mtime) |mt| {
            meta_parts[meta_count] = mt;
            meta_styles[meta_count] = .{ .fg = Theme.fg_meta, .dim = true };
            meta_count += 1;
        }

        // Calculate total metadata width
        var meta_width: usize = 0;
        for (meta_parts[0..meta_count]) |part| {
            meta_width += part.len + 1; // +1 for space
        }
        if (meta_count > 0) meta_width -= 1; // Remove last space

        // Right-align metadata (with padding from name) - ensure it doesn't overlap border
        const min_padding: usize = 2;
        const max_col = if (content_w > 1) content_w - 1 else 0; // Stay inside border
        const right_start = if (name_end_col + min_padding + meta_width < max_col)
            max_col - meta_width
        else
            name_end_col + min_padding;

        var meta_col = right_start;
        
        // Render metadata
        for (meta_parts[0..meta_count], 0..) |part, i| {
            render_util.printLine(win, row + 1, meta_col, part, meta_styles[i]);
            meta_col += part.len;
            if (i < meta_count - 1) {
                render_util.printLine(win, row + 1, meta_col, " ", .{ .fg = Theme.fg_meta, .dim = true });
                meta_col += 1;
            }
        }

        row += 1;
    }

    // Minimal scroll indicator - just a dot
    if (state.entries.items.len > content_h) {
        const total = state.entries.items.len;
        const ratio = @as(f32, @floatFromInt(state.cursor)) / @as(f32, @floatFromInt(total));
        const indicator_pos = @as(usize, @intFromFloat(ratio * @as(f32, @floatFromInt(content_h - 1))));

        for (0..content_h) |y| {
            const char: []const u8 = if (y == indicator_pos) ":" else " ";
            render_util.printLine(win, y + 1, win.width - 2, char, .{ // Inside border
                .fg = Theme.fg_dir,
            });
        }
    }
}


const dep = @import("../../dep.zig");

const std = dep.Stdlib.std;

const vaxis = dep.External.vaxis;

const State = dep.Types.State;
const EntryKind = dep.Types.EntryKind;

const border = dep.Panes.Shared.border;

const sql_wrap = dep.Engine.sql_wrap;

const syntax_util = dep.TUIUtils.syntax_util;
const render_util = dep.TUIUtils.render_util;
const format_util = dep.TUIUtils.format_util;
const tree_util = dep.TUIUtils.tree_util;

const Theme = struct {
    const fg_label = vaxis.Color{ .index = 244 }; // gray (matching #888)
    const fg_value = vaxis.Color{ .index = 252 }; // light gray (matching #e0e0e0)
    const fg_accent = vaxis.Color{ .index = 160 }; // red (tree lines - matching #dc2626)
    const fg_code = vaxis.Color{ .index = 252 }; // light gray (matching #e0e0e0)
    const fg_line_num = vaxis.Color{ .index = 244 }; // gray (matching #888)
};

const PreviewError = error{ CommandFailed };

var bat_available = true;
var bat_warning_emitted = false;

pub fn render(win: vaxis.Window, state: *State) void {
    const entry = state.currentEntry() orelse {
        border.draw(win, "view");
        render_util.printLine(win, 1, 1, "No selection", .{ .fg = Theme.fg_label, .dim = true });
        return;
    };

    // Use the entry name (just basename, not full path) as the pane title
    // Add trailing '/' for directories
    const title = if (entry.is_dir)
        state.frameFmt("{s}/", .{entry.name}) catch "view"
    else
        state.frameAlloc(entry.name) catch "view";
    border.draw(win, title);

    var row: usize = 1; // Start after top border

    // Show file metadata for files
    if (!entry.is_dir) {
        const file_meta = getFileMetadata(state, entry.path, entry.size) catch null;
        if (file_meta) |meta| {
            render_util.printLine(win, row, 1, meta, .{ .fg = Theme.fg_label, .dim = true });
            row += 1;
        }
    }

    // Preview content for specific file types
    const content_h = if (win.height > row + 1) win.height - row - 1 else 0;
    if (content_h > 0 and !entry.is_dir) {
        // Reset scroll when file changes
        const current_path = entry.path;
        if (state.last_previewed_path) |last_path| {
            if (!std.mem.eql(u8, last_path, current_path)) {
                state.preview_scroll_offset = 0;
                state.alloc.free(state.last_previewed_path.?);
                state.last_previewed_path = state.alloc.dupe(u8, current_path) catch null;
            }
        } else {
            state.last_previewed_path = state.alloc.dupe(u8, current_path) catch null;
        }
        previewFile(win, state, entry.path, row, content_h);
    } else if (entry.is_dir) {
        previewDirectory(win, state, entry.path, row, content_h);
    }
}

fn getFileMetadata(state: *State, path: []const u8, file_size: u64) ![]const u8 {
    const file = std.fs.cwd().openFile(path, .{}) catch return error.CannotRead;
    defer file.close();

    // Count lines
    const max_read = 512 * 1024; // 512KB max for line counting
    const read_size = @min(file_size, max_read);
    
    const alloc = state.frame_arena.allocator();
    const buf = alloc.alloc(u8, read_size) catch return error.MemoryError;
    const bytes_read = file.readAll(buf) catch return error.ReadError;
    const content = buf[0..bytes_read];
    
    var line_count: usize = 1; // At least 1 line if not empty
    for (content) |byte| {
        if (byte == '\n') line_count += 1;
    }
    
    // Detect encoding (simple: UTF-8 vs binary)
    var is_text = true;
    for (content) |byte| {
        if (byte == 0 or (byte < 32 and byte != '\n' and byte != '\r' and byte != '\t')) {
            is_text = false;
            break;
        }
    }
    
    const encoding = if (is_text) "UTF-8" else "binary";
    const size_info = format_util.formatSize(file_size);
    
    return state.frameFmt("{d} lines  {d:.1}{s}  {s}", .{ line_count, size_info.value, size_info.unit, encoding });
}

fn previewFile(win: vaxis.Window, state: *State, path: []const u8, start_row: usize, max_lines: usize) void {
    // Check if it's a database file
    if (std.mem.endsWith(u8, path, ".db") or std.mem.endsWith(u8, path, ".sqlite")) {
        previewDatabase(win, state, path, start_row, max_lines);
        return;
    }
    
    // Use new preview with line numbers and syntax highlighting
    previewFileWithSyntax(win, state, path, start_row, max_lines);
}

fn previewWithBat(win: vaxis.Window, state: *State, path: []const u8, start_row: usize, max_lines: usize) bool {
    if (!bat_available) return false;

    const alloc = std.heap.page_allocator;
    const output = runBatPreview(path, alloc) catch {
        disableBat("bat preview unavailable, falling back to plain text");
        return false;
    };
    defer alloc.free(output);
    const stored = state.frameAlloc(output) catch return false;

    const max_w = if (win.width > 2) win.width - 2 else 1;
    var lines = std.mem.splitScalar(u8, stored, '\n');
    var row = start_row;
    var line_num: usize = 0;

    while (lines.next()) |line_raw| {
        if (line_num >= max_lines) break;

        const line_src = if (line_raw.len > max_w)
            line_raw[0..max_w]
        else
            line_raw;
        const line = state.frameAlloc(line_src) catch break;

        render_util.printLine(win, row, 1, line, .{ .fg = Theme.fg_code }); // Inside border
        row += 1;
        line_num += 1;
    }

    return true;
}

fn runBatPreview(path: []const u8, alloc: std.mem.Allocator) PreviewError![]u8 {
    const result = std.process.Child.run(.{
        .allocator = alloc,
        .argv = &.{ "bat", "--style=plain", "--color=never", "--line-range=1:200", path },
        .max_output_bytes = 128 * 1024,
    }) catch return error.CommandFailed;
    defer alloc.free(result.stderr);

    switch (result.term) {
        .Exited => |code| {
            if (code == 0) {
                return result.stdout;
            }
            disableBat("bat exited with an error; disabling syntax preview");
        },
        .Signal => {
            disableBat("bat crashed; disabling syntax preview");
        },
        else => {
            disableBat("bat exited unexpectedly; disabling syntax preview");
        },
    }

    alloc.free(result.stdout);
    return error.CommandFailed;
}

fn disableBat(message: []const u8) void {
    bat_available = false;
    if (!bat_warning_emitted) {
        bat_warning_emitted = true;
        std.debug.print("preview: {s}\n", .{message});
    }
}

fn previewFileWithSyntax(win: vaxis.Window, state: *State, path: []const u8, start_row: usize, max_lines: usize) void {
    const file = std.fs.cwd().openFile(path, .{}) catch {
        render_util.printLine(win, start_row, 1, "(cannot read)", .{ .fg = Theme.fg_label, .dim = true });
        return;
    };
    defer file.close();

    // Read file content (limit to reasonable size for preview)
    const max_file_size = 512 * 1024; // 512KB max
    const file_size = file.getEndPos() catch max_file_size;
    const read_size = @min(file_size, max_file_size);
    
    if (read_size == 0) {
        render_util.printLine(win, start_row, 1, "(empty file)", .{ .fg = Theme.fg_label, .dim = true });
        return;
    }

    // Allocate buffer for file content
    const alloc = state.frame_arena.allocator();
    const content_buf = alloc.alloc(u8, read_size) catch {
        render_util.printLine(win, start_row, 1, "(memory error)", .{ .fg = Theme.fg_label, .dim = true });
        return;
    };
    const bytes_read = file.readAll(content_buf) catch 0;
    const content = content_buf[0..bytes_read];

    // Split into lines - count first, then allocate
    var line_count: usize = 0;
    var line_iter_count = std.mem.splitScalar(u8, content, '\n');
    while (line_iter_count.next()) |_| {
        line_count += 1;
    }
    
    // Allocate array for line pointers
    const all_lines = alloc.alloc([]const u8, line_count) catch {
        render_util.printLine(win, start_row, 1, "(memory error)", .{ .fg = Theme.fg_label, .dim = true });
        return;
    };
    
    var line_iter = std.mem.splitScalar(u8, content, '\n');
    var line_idx: usize = 0;
    while (line_iter.next()) |line| {
        all_lines[line_idx] = line;
        line_idx += 1;
    }
    const total_lines = all_lines.len;
    
    // Calculate line number width (e.g., "1234" = 4 chars)
    const line_num_width = if (total_lines > 0) blk: {
        var width: usize = 1;
        var n = total_lines;
        while (n >= 10) {
            width += 1;
            n /= 10;
        }
        break :blk width;
    } else 1;
    
    const line_num_col_width = line_num_width + 1; // +1 for space after number
    const max_w = if (win.width > line_num_col_width + 2) win.width - line_num_col_width - 2 else 1;
    
    // Determine if we should use syntax highlighting
    const use_syntax = std.mem.endsWith(u8, path, ".zig") or 
                       std.mem.endsWith(u8, path, ".json") or 
                       std.mem.endsWith(u8, path, ".jsonc");
    const is_zig = std.mem.endsWith(u8, path, ".zig");
    const is_json = std.mem.endsWith(u8, path, ".json") or std.mem.endsWith(u8, path, ".jsonc");

    // Apply scroll offset
    const scroll_offset = state.preview_scroll_offset;
    const start_line = scroll_offset;
    const end_line = @min(start_line + max_lines, total_lines);

    var row = start_row;
    var display_line_num = start_line;

    while (display_line_num < end_line) {
        const line = all_lines[display_line_num];
        const line_number = display_line_num + 1; // 1-indexed line numbers
        
        // Print line number (right-aligned, manually padded)
        const line_num_str = state.frameFmt("{d}", .{line_number}) catch break;
        const padding_needed = if (line_num_width > line_num_str.len) line_num_width - line_num_str.len else 0;
        const total_padding = padding_needed + line_num_str.len + 1; // +1 for space
        var line_num_buf = alloc.alloc(u8, total_padding) catch break;
        @memset(line_num_buf[0..padding_needed], ' ');
        @memcpy(line_num_buf[padding_needed..padding_needed + line_num_str.len], line_num_str);
        line_num_buf[padding_needed + line_num_str.len] = ' ';
        const line_num_final = state.frameAlloc(line_num_buf) catch break;
        render_util.printLine(win, row, 1, line_num_final, .{ .fg = Theme.fg_line_num, .dim = true });
        
        // Truncate line if needed
        const display_line = if (line.len > max_w)
            line[0..max_w]
        else
            line;
        
        // Apply syntax highlighting if supported
        if (use_syntax) {
            const tokens = if (is_zig)
                syntax_util.highlightZig(alloc, display_line) catch {
                    // Fallback to plain text on error
                    const plain = state.frameAlloc(display_line) catch break;
                    render_util.printLine(win, row, 1 + line_num_col_width, plain, .{ .fg = Theme.fg_code });
                    row += 1;
                    display_line_num += 1;
                    continue;
                }
            else if (is_json)
                syntax_util.highlightJson(alloc, display_line) catch {
                    const plain = state.frameAlloc(display_line) catch break;
                    render_util.printLine(win, row, 1 + line_num_col_width, plain, .{ .fg = Theme.fg_code });
                    row += 1;
                    display_line_num += 1;
                    continue;
                }
            else
                null;
            
            if (tokens) |tokens_list| {
                defer alloc.free(tokens_list);
                var col: usize = 1 + line_num_col_width;
                var segments = std.ArrayListUnmanaged(vaxis.Cell.Segment){};
                defer segments.deinit(alloc);
                
                for (tokens_list) |token| {
                    const token_text = state.frameAlloc(token.text) catch break;
                    segments.append(alloc, vaxis.Cell.Segment{
                        .text = token_text,
                        .style = token.style,
                    }) catch break;
                    col += token.text.len;
                    if (col >= win.width - 1) break;
                }
                
                if (segments.items.len > 0) {
                    _ = win.print(segments.items, .{
                        .row_offset = @intCast(row),
                        .col_offset = @intCast(1 + line_num_col_width),
                    });
                }
            } else {
                const plain = state.frameAlloc(display_line) catch break;
                render_util.printLine(win, row, 1 + line_num_col_width, plain, .{ .fg = Theme.fg_code });
            }
        } else {
            // Plain text for non-code files
            const plain = state.frameAlloc(display_line) catch break;
            render_util.printLine(win, row, 1 + line_num_col_width, plain, .{ .fg = Theme.fg_code });
        }
        
        row += 1;
        display_line_num += 1;
    }
}

fn previewDatabase(win: vaxis.Window, state: *State, path: []const u8, start_row: usize, max_lines: usize) void {
    const db_handle = sql_wrap.openDB(path) catch {
        render_util.printLine(win, start_row, 1, "(cannot open database)", .{ .fg = Theme.fg_label, .dim = true });
        return;
    };
    defer sql_wrap.closeDB(db_handle) catch {};

    // Query for table names
    const query = "SELECT name FROM sqlite_master WHERE type='table' ORDER BY name";
    const c_query = std.heap.c_allocator.dupeZ(u8, query) catch {
        render_util.printLine(win, start_row, 1, "(memory error)", .{ .fg = Theme.fg_label, .dim = true });
        return;
    };
    defer std.heap.c_allocator.free(c_query);

    var stmt: ?*anyopaque = null;
    var tail: ?*[*:0]const u8 = null;
    const prepare = sql_wrap.sqlite3_prepare_v2(db_handle, c_query, -1, &stmt, &tail);

    if (prepare != 0) {
        render_util.printLine(win, start_row, 1, "(query failed)", .{ .fg = Theme.fg_label, .dim = true });
        return;
    }
    defer _ = sql_wrap.sqlite3_finalize(stmt.?);

    var row = start_row;
    var table_count: usize = 0;

    // Get table names and row counts
    while (sql_wrap.sqlite3_step(stmt.?) == 100) {
        if (row >= start_row + max_lines - 1) break;

        const table_name = std.mem.span(sql_wrap.sqlite3_column_text(stmt.?, 0));
        
        // Get row count for this table
        const count_query = state.frameFmt("SELECT COUNT(*) FROM \"{s}\"", .{table_name}) catch break;
        const c_count_query = std.heap.c_allocator.dupeZ(u8, count_query) catch break;
        defer std.heap.c_allocator.free(c_count_query);

        var count_stmt: ?*anyopaque = null;
        var count_tail: ?*[*:0]const u8 = null;
        const count_prepare = sql_wrap.sqlite3_prepare_v2(db_handle, c_count_query, -1, &count_stmt, &count_tail);
        
        var row_count: usize = 0;
        if (count_prepare == 0) {
            if (sql_wrap.sqlite3_step(count_stmt.?) == 100) {
                row_count = @intFromFloat(sql_wrap.sqlite3_column_double(count_stmt.?, 0));
            }
            _ = sql_wrap.sqlite3_finalize(count_stmt.?);
        }

        // Get column count
        const col_query = state.frameFmt("PRAGMA table_info(\"{s}\")", .{table_name}) catch break;
        const c_col_query = std.heap.c_allocator.dupeZ(u8, col_query) catch break;
        defer std.heap.c_allocator.free(c_col_query);

        var col_stmt: ?*anyopaque = null;
        var col_tail: ?*[*:0]const u8 = null;
        const col_prepare = sql_wrap.sqlite3_prepare_v2(db_handle, c_col_query, -1, &col_stmt, &col_tail);
        
        var col_count: usize = 0;
        if (col_prepare == 0) {
            while (sql_wrap.sqlite3_step(col_stmt.?) == 100) {
                col_count += 1;
            }
            _ = sql_wrap.sqlite3_finalize(col_stmt.?);
        }

        // Display table info
        const table_display = state.frameAlloc(table_name) catch break;
        render_util.printLine(win, row, 1, table_display, .{ .fg = Theme.fg_accent, .bold = true }); // Inside border
        
        const info = state.frameFmt(" {d} rows, {d} cols", .{ row_count, col_count }) catch break;
        render_util.printLine(win, row, 1 + table_name.len, info, .{ .fg = Theme.fg_value });

        row += 1;
        table_count += 1;
    }

    if (table_count == 0) {
        render_util.printLine(win, start_row, 1, "(no tables)", .{ .fg = Theme.fg_label, .dim = true });
    }
}

fn previewDirectory(win: vaxis.Window, state: *State, path: []const u8, start_row: usize, max_lines: usize) void {
    const alloc = state.frame_arena.allocator();
    
    const root = tree_util.buildTreeAlloc(alloc, path) catch {
        render_util.printLine(win, start_row, 1, "(cannot read)", .{ .fg = Theme.fg_label, .dim = true });
        return;
    };
    
    var branch_stack: std.ArrayList(bool) = .{};
    var lines: std.ArrayList([]const u8) = .{};
    
    tree_util.flattenTreeSkipRoot(alloc, root, &branch_stack, &lines) catch {
        render_util.printLine(win, start_row, 1, "(error building tree)", .{ .fg = Theme.fg_label, .dim = true });
        return;
    };
    
    var row = start_row;
    const display_count = @min(lines.items.len, max_lines);
    
    // Calculate max width for truncation (window width - left padding - borders)
    const max_width = if (win.width > 3) win.width - 3 else 1;
    
    for (lines.items[0..display_count]) |line| {
        const color = if (std.mem.indexOf(u8, line, "──") != null)
            Theme.fg_accent
        else
            Theme.fg_value;
        
        // Truncate line to fit window width
        const display_line = if (line.len > max_width) line[0..max_width] else line;
        
        render_util.printLine(win, row, 1, display_line, .{ .fg = color });
        row += 1;
    }
    
    if (lines.items.len > max_lines and row < start_row + max_lines) {
        if (state.frameFmt("... +{d} more", .{lines.items.len - max_lines})) |more| {
            // Truncate "more" message to fit within window
            const more_display = if (more.len > max_width) more[0..max_width] else more;
            render_util.printLine(win, row, 1, more_display, .{ .fg = Theme.fg_label, .dim = true });
        } else |_| {}
    }
}
const std = @import("std");
const vaxis = @import("vaxis");
const panes = @import("../../panes.zig");
const border = panes.border;
const types = @import("../../types.zig");
const State = types.State;

const Theme = struct {
    const fg_text = vaxis.Color{ .index = 187 }; // warm beige
    const fg_dir = vaxis.Color{ .index = 66 }; // muted blue
    const fg_file = vaxis.Color{ .index = 65 }; // muted green
    const fg_dim = vaxis.Color{ .index = 137 }; // brown-gray
};

pub fn render(win: vaxis.Window, state: *State) void {
    border.draw(win, "bin");

    const content_h = if (win.height > 2) win.height - 2 else 0;
    const content_w = if (win.width > 2) win.width - 2 else 1;
    if (content_h == 0) return;

    // Build path to zig-out - use tree arena to ensure it lives long enough
    var tree_arena = std.heap.ArenaAllocator.init(state.alloc);
    defer tree_arena.deinit();
    const tree_alloc = tree_arena.allocator();

    const bin_path = std.fmt.allocPrint(tree_alloc, "{s}/zig-out/bin", .{state.project_root}) catch {
        printLine(win, 1, 1, "(cannot access bin)", .{ .fg = Theme.fg_dim, .dim = true });
        return;
    };

    var lines = std.ArrayListUnmanaged([]const u8){};
    defer {
        for (lines.items) |line| {
            tree_alloc.free(line);
        }
        lines.deinit(tree_alloc);
    }

    var parent_stack = std.ArrayListUnmanaged(bool){};
    defer parent_stack.deinit(tree_alloc);
    
    buildAndFlattenTree(tree_alloc, bin_path, &lines, 0, true, &parent_stack) catch |err| {
        const err_msg = state.frameFmt("(error: {s})", .{@errorName(err)}) catch "(error)";
        printLine(win, 1, 1, err_msg, .{ .fg = Theme.fg_dim, .dim = true });
        return;
    };

    // Display tree lines (truncate if too long)
    const start = if (lines.items.len > content_h) lines.items.len - content_h else 0;
    var row: usize = 0;

    for (lines.items[start..]) |line| {
        if (row >= content_h) break;

        // Truncate line if it exceeds width and ensure it's frame-allocated for vaxis
        const display_line_raw = if (line.len > content_w) line[0..content_w] else line;
        const display_line = state.frameAlloc(display_line_raw) catch break;
        
        const style: vaxis.Style = if (std.mem.endsWith(u8, line, ".dylib") or std.mem.endsWith(u8, line, ".so") or std.mem.endsWith(u8, line, ".dll")) .{
            .fg = Theme.fg_file,
        } else if (std.mem.indexOf(u8, line, "/") != null) .{
            .fg = Theme.fg_dir,
        } else .{
            .fg = Theme.fg_text,
        };

        printLine(win, row + 1, 1, display_line, style);
        row += 1;
    }
}

fn buildAndFlattenTree(alloc: std.mem.Allocator, path: []const u8, lines: *std.ArrayListUnmanaged([]const u8), depth: usize, is_last: bool, parent_is_last_stack: *std.ArrayListUnmanaged(bool)) !void {
    // Build prefix for this line
    var prefix = std.ArrayListUnmanaged(u8){};
    defer prefix.deinit(alloc);

    // Add tree characters based on depth and parent's last status
    // For each level from 0 to depth-1, check if that ancestor was the last child
    for (0..depth) |level| {
        // At level i, we need to check the parent stack at position (depth - 1 - level)
        // because stack[0] is the immediate parent, stack[1] is grandparent, etc.
        const stack_idx = depth - 1 - level;
        if (stack_idx < parent_is_last_stack.items.len) {
            const ancestor_was_last = parent_is_last_stack.items[stack_idx];
            if (ancestor_was_last) {
                try prefix.appendSlice(alloc, "    ");
            } else {
                try prefix.appendSlice(alloc, "│   ");
            }
        } else {
            try prefix.appendSlice(alloc, "│   ");
        }
    }

    // Add connector for current node
    if (depth > 0) {
        if (is_last) {
            try prefix.appendSlice(alloc, "└── ");
        } else {
            try prefix.appendSlice(alloc, "├── ");
        }
    }

    // Get name
    const name = std.fs.path.basename(path);
    var is_directory = false;

    // Try to open as directory
    if (std.fs.cwd().openDir(path, .{ .iterate = true })) |dir| {
        var dir_mut = @constCast(&dir);
        defer dir_mut.close();
        is_directory = true;

        // Build full line for directory
        try prefix.appendSlice(alloc, name);
        try prefix.appendSlice(alloc, "/");
        const line = try prefix.toOwnedSlice(alloc);
        try lines.append(alloc, line);

        // Process children
        var iter = dir.iterate();
        var children = std.ArrayListUnmanaged([]const u8){};
        defer {
            for (children.items) |child| {
                alloc.free(child);
            }
            children.deinit(alloc);
        }

        while (iter.next() catch null) |entry| {
            // Skip hidden files
            if (entry.name.len > 0 and entry.name[0] == '.') continue;

            const child_path = try std.fmt.allocPrint(alloc, "{s}/{s}", .{ path, entry.name });
            try children.append(alloc, child_path);
        }

        // Process each child
        const child_count = children.items.len;
        for (children.items, 0..) |child_path, i| {
            const child_is_last = (i == child_count - 1);
            // Push current node's last status to stack
            try parent_is_last_stack.append(alloc, is_last);
            try buildAndFlattenTree(alloc, child_path, lines, depth + 1, child_is_last, parent_is_last_stack);
            // Pop after processing
            _ = parent_is_last_stack.pop();
        }
    } else |_| {
        // It's a file
        try prefix.appendSlice(alloc, name);
        const line = try prefix.toOwnedSlice(alloc);
        try lines.append(alloc, line);
    }
    
    // Note: parent_is_last_stack is managed by caller, don't modify here
}

fn printLine(win: vaxis.Window, row: usize, col: usize, text: []const u8, style: vaxis.Style) void {
    const seg = vaxis.Cell.Segment{ .text = text, .style = style };
    _ = win.print(&[_]vaxis.Cell.Segment{seg}, .{
        .row_offset = @intCast(row),
        .col_offset = @intCast(col),
    });
}

const std = @import("std");

pub const Node = struct {
    name: []const u8,
    is_dir: bool,
    parent: ?*Node,
    children: []*Node,
};

pub fn buildTreeAlloc(alloc: std.mem.Allocator, path: []const u8) !*Node {
    var dir = try std.fs.cwd().openDir(path, .{ .iterate = true });

    const root = try alloc.create(Node);
    root.* = .{
        .name = try alloc.dupe(u8, path),
        .is_dir = true,
        .parent = null,
        .children = &.{},
    };

    try loadChildren(alloc, root, &dir);
    return root;
}

fn loadChildren(
    alloc: std.mem.Allocator,
    parent: *Node,
    dir: *std.fs.Dir,
) !void {
    var iter = dir.iterate();

    var list: std.ArrayList(*Node) = .{};
    defer list.deinit(alloc);

    while (try iter.next()) |entry| {
        if (std.mem.eql(u8, entry.name, ".DS_Store")) continue;

        const child = try alloc.create(Node);
        child.* = .{
            .name = try alloc.dupe(u8, entry.name),
            .is_dir = entry.kind == .directory,
            .parent = parent,
            .children = &.{},
        };

        try list.append(alloc, child);

        if (child.is_dir) {
            if (dir.openDir(entry.name, .{ .iterate = true })) |subdir| {
                try loadChildren(alloc, child, @constCast(&subdir));
            } else |_| {}
        }
    }

    parent.children = try list.toOwnedSlice(alloc);
}

pub fn flattenTree(
    alloc: std.mem.Allocator,
    node: *Node,
    last_mask: []bool, // stack representing last-child at each depth
    depth: usize,
    out: *std.ArrayList([]const u8),
) !void {
    // Build prefix string safely
    var prefix: std.ArrayList(u8) = .{};

    // Build prefix segments for all ancestor depths
    for (last_mask[0..depth], 0..) |is_last, i| {
        if (i + 1 == depth) {
            // this level's own prefix handled below
            break;
        }
        if (is_last) {
            try prefix.appendSlice(alloc, "    "); // 4 spaces
        } else {
            try prefix.appendSlice(alloc, "│   ");
        }
    }

    // Add own branch marker
    if (depth == 0) {
        // root, no marker
    } else if (last_mask[depth - 1]) {
        try prefix.appendSlice(alloc, "└── ");
    } else {
        try prefix.appendSlice(alloc, "├── ");
    }

    // Build final line: prefix + name
    var buf: std.ArrayList(u8) = .{};
    try buf.appendSlice(alloc, prefix.items);
    try buf.appendSlice(alloc, node.name);

    try out.append(alloc, try buf.toOwnedSlice(alloc));

    // Recurse children
    const child_count = node.children.len;
    for (node.children, 0..) |child, i| {
        // grow last_mask
        var next_mask = last_mask;
        if (depth >= next_mask.len) {
            next_mask = try alloc.realloc(next_mask, depth + 1);
        }
        next_mask[depth] = (i == child_count - 1);

        try flattenTree(alloc, child, next_mask, depth + 1, out);
    }
}

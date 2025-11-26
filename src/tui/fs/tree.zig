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
    branch_stack: *std.ArrayList(bool),
    depth: usize,
    out: *std.ArrayList([]const u8),
) !void {
    std.debug.assert(branch_stack.items.len == depth);

    var line = std.ArrayList(u8).init(alloc);
    defer line.deinit();

    // Build prefix segments
    for (branch_stack.items[0..depth], 0..) |is_last, i| {
        if (i + 1 == depth) break;
        if (is_last) {
            try line.appendSlice("    ");
        } else {
            try line.appendSlice("│   ");
        }
    }

    if (depth > 0) {
        const is_last = branch_stack.items[depth - 1];
        if (is_last) {
            try line.appendSlice("└── ");
        } else {
            try line.appendSlice("├── ");
        }
    }

    try line.appendSlice(node.name);
    try out.append(alloc, try line.toOwnedSlice());

    const child_count = node.children.len;
    for (node.children, 0..) |child, i| {
        const is_last = i == child_count - 1;

        try branch_stack.append(is_last);

        try flattenTree(alloc, child, branch_stack, depth + 1, out);
        _ = branch_stack.pop();
    }
}

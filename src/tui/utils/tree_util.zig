const dep = @import("../dep.zig");

const std = dep.Stdlib.std;

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
    try flattenTreeImpl(alloc, node, branch_stack, depth, out, false);
}

pub fn flattenTreeSkipRoot(
    alloc: std.mem.Allocator,
    node: *Node,
    branch_stack: *std.ArrayList(bool),
    out: *std.ArrayList([]const u8),
) !void {
    try flattenTreeImpl(alloc, node, branch_stack, 0, out, true);
}

fn flattenTreeImpl(
    alloc: std.mem.Allocator,
    node: *Node,
    branch_stack: *std.ArrayList(bool),
    depth: usize,
    out: *std.ArrayList([]const u8),
    skip_root: bool,
) !void {
    std.debug.assert(branch_stack.items.len == depth);

    // Skip root node if requested (only process children at depth 0)
    if (depth == 0 and skip_root) {
        for (node.children) |child| {
            // Don't add to stack for root level - children render at depth 0
            try flattenTreeImpl(alloc, child, branch_stack, 0, out, false);
        }
        return;
    }

    var line: std.ArrayList(u8) = .{};
    defer line.deinit(alloc);

    // Build the prefix with tree characters
    for (branch_stack.items[0..depth], 0..) |is_last, i| {
        if (i + 1 == depth) break;
        if (is_last) {
            try line.appendSlice(alloc, "    ");
        } else {
            try line.appendSlice(alloc, "│   ");
        }
    }

    // Add connector for current node
    if (depth > 0) {
        const is_last = branch_stack.items[depth - 1];
        if (is_last) {
            try line.appendSlice(alloc, "└── ");
        } else {
            try line.appendSlice(alloc, "├── ");
        }
    }

    try line.appendSlice(alloc, node.name);
    try out.append(alloc, try line.toOwnedSlice(alloc));

    const child_count = node.children.len;
    for (node.children, 0..) |child, i| {
        const is_last = i == child_count - 1;

        try branch_stack.append(alloc, is_last);

        try flattenTreeImpl(alloc, child, branch_stack, depth + 1, out, false);
        _ = branch_stack.pop();
    }
}


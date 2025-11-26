const std = @import("std");
const StringHashMap = std.StringHashMap;
const Engine = @import("../engine/engine.zig").Engine;

pub const EntryKind = enum {
    directory,
    file,
    auto, // .zig files in usr/auto
    map, // .jsonc files
    database, // .db files
    unknown,
};

pub const Entry = struct {
    name: []const u8,
    path: []const u8,
    kind: EntryKind,
    size: u64,
    is_dir: bool,
};

const MAX_LOGS = 20;

pub const LogEntry = struct {
    message: []const u8,
    timestamp: i64, // Unix timestamp when log was created
};

pub const ExecutionResult = struct {
    map_path: []const u8,
    auto_name: []const u8,
    auto_desc: []const u8,
    auto_path: []const u8,
    exec_mode: []const u8,
    db_path: []const u8,
    feed_mode: []const u8,
    table: []const u8,
    data_points: usize,
    trail_size: usize,
    balance: f64,
    output_dir: []const u8,
    output_orders_path: []const u8,
    output_fills_path: []const u8,
    output_positions_path: []const u8,
    init_time_ms: i64,
    exec_time_ms: i64,
    total_time_ms: i64,
    throughput: f64,
    success: bool,
};

pub const State = struct {
    alloc: std.mem.Allocator,
    cwd: []const u8,
    root: []const u8,
    project_root: []const u8,
    entries: std.ArrayListUnmanaged(Entry),
    cursor: usize,
    scroll_offset: usize,
    message: ?[]const u8,
    frame_arena: std.heap.ArenaAllocator,
    logs: std.ArrayListUnmanaged(LogEntry),
    execution_result: ?ExecutionResult,
    assembled_engine: ?Engine,
    current_workspace: u8,
    prompt_mode: bool,
    prompt_text: std.ArrayListUnmanaged(u8),
    selected_paths: StringHashMap(void),
    preview_scroll_offset: usize,
    last_previewed_path: ?[]const u8,

    pub fn init(alloc: std.mem.Allocator, start_path: []const u8, project_root: []const u8) !State {
        var state = State{
            .alloc = alloc,
            .cwd = try alloc.dupe(u8, start_path),
            .root = try alloc.dupe(u8, start_path),
            .project_root = try alloc.dupe(u8, project_root),
            .entries = .{},
            .cursor = 0,
            .scroll_offset = 0,
            .message = null,
            .frame_arena = std.heap.ArenaAllocator.init(alloc),
            .logs = .{},
            .execution_result = null,
            .assembled_engine = null,
            .current_workspace = 1,
            .prompt_mode = false,
            .prompt_text = .{},
            .selected_paths = StringHashMap(void).init(alloc),
            .preview_scroll_offset = 0,
            .last_previewed_path = null,
        };
        try state.loadDirectory();
        return state;
    }

    pub fn deinit(self: *State) void {
        self.alloc.free(self.cwd);
        self.alloc.free(self.root);
        self.alloc.free(self.project_root);
        for (self.entries.items) |entry| {
            self.alloc.free(entry.name);
            self.alloc.free(entry.path);
        }
        self.entries.deinit(self.alloc);
        if (self.message) |msg| self.alloc.free(msg);
        self.frame_arena.deinit();
        for (self.logs.items) |log| {
            self.alloc.free(log.message);
        }
        self.logs.deinit(self.alloc);
        self.prompt_text.deinit(self.alloc);
        var selected_iter = self.selected_paths.iterator();
        while (selected_iter.next()) |entry| {
            self.alloc.free(entry.key_ptr.*);
        }
        self.selected_paths.deinit();
        if (self.last_previewed_path) |path| {
            self.alloc.free(path);
        }
        if (self.execution_result) |*result| {
            self.alloc.free(result.map_path);
            self.alloc.free(result.auto_name);
            self.alloc.free(result.auto_desc);
            self.alloc.free(result.auto_path);
            self.alloc.free(result.exec_mode);
            self.alloc.free(result.db_path);
            self.alloc.free(result.feed_mode);
            self.alloc.free(result.table);
            self.alloc.free(result.output_dir);
            self.alloc.free(result.output_orders_path);
            self.alloc.free(result.output_fills_path);
            self.alloc.free(result.output_positions_path);
        }
        
        if (self.assembled_engine) |*engine| {
            engine.deinit();
        }
    }

    pub fn loadDirectory(self: *State) !void {
        // Clear old entries
        for (self.entries.items) |entry| {
            self.alloc.free(entry.name);
            self.alloc.free(entry.path);
        }
        self.entries.clearRetainingCapacity();

        var dir = std.fs.cwd().openDir(self.cwd, .{ .iterate = true }) catch {
            return;
        };
        defer dir.close();

        var iter = dir.iterate();
        while (try iter.next()) |item| {
            // Skip hidden files
            if (item.name.len > 0 and item.name[0] == '.') continue;

            const name = try self.alloc.dupe(u8, item.name);
            const path = try std.fs.path.join(self.alloc, &.{ self.cwd, item.name });

            const kind = classifyEntry(item.name, item.kind == .directory);
            const size = getFileSize(dir, item.name) catch 0;

            try self.entries.append(self.alloc, .{
                .name = name,
                .path = path,
                .kind = kind,
                .size = size,
                .is_dir = item.kind == .directory,
            });
        }

        // Sort: directories first, then alphabetically
        std.mem.sort(Entry, self.entries.items, {}, struct {
            fn lessThan(_: void, a: Entry, b: Entry) bool {
                if (a.is_dir != b.is_dir) return a.is_dir;
                return std.mem.lessThan(u8, a.name, b.name);
            }
        }.lessThan);

        self.cursor = 0;
        self.scroll_offset = 0;
    }

    pub fn moveUp(self: *State) void {
        if (self.cursor > 0) self.cursor -= 1;
    }

    pub fn moveDown(self: *State) void {
        if (self.cursor + 1 < self.entries.items.len) self.cursor += 1;
    }

    pub fn enter(self: *State) !void {
        if (self.entries.items.len == 0) return;

        const entry = self.entries.items[self.cursor];
        if (entry.is_dir) {
            self.clearMessage();
            self.alloc.free(self.cwd);
            self.cwd = try self.alloc.dupe(u8, entry.path);
            try self.loadDirectory();
        }
    }

    pub fn goUp(self: *State) !void {
        if (std.mem.eql(u8, self.cwd, self.root)) {
            try self.setMessage("Already at usr root");
            return;
        }
        const parent = std.fs.path.dirname(self.cwd) orelse return;
        const new_cwd = try self.alloc.dupe(u8, parent);
        self.alloc.free(self.cwd);
        self.cwd = new_cwd;
        self.clearMessage();
        try self.loadDirectory();
    }

    pub fn currentEntry(self: *State) ?*const Entry {
        if (self.entries.items.len == 0) return null;
        return &self.entries.items[self.cursor];
    }

    pub fn setMessage(self: *State, msg: []const u8) !void {
        if (self.message) |old| self.alloc.free(old);
        self.message = try self.alloc.dupe(u8, msg);
    }

    pub fn clearMessage(self: *State) void {
        if (self.message) |msg| {
            self.alloc.free(msg);
            self.message = null;
        }
    }

    pub fn beginFrame(self: *State) void {
        _ = self.frame_arena.reset(.retain_capacity);
    }

    pub fn frameAlloc(self: *State, bytes: []const u8) std.mem.Allocator.Error![]const u8 {
        return try self.frame_arena.allocator().dupe(u8, bytes);
    }

    pub fn frameFmt(self: *State, comptime fmt: []const u8, args: anytype) ![]const u8 {
        return try std.fmt.allocPrint(self.frame_arena.allocator(), fmt, args);
    }

    pub fn logMessage(self: *State, message: []const u8) !void {
        const copy = try self.alloc.dupe(u8, message);
        const timestamp = std.time.timestamp();
        const entry = LogEntry{
            .message = copy,
            .timestamp = timestamp,
        };
        try self.logs.append(self.alloc, entry);
        self.trimLogs();
    }

    pub fn logFmt(self: *State, comptime fmt: []const u8, args: anytype) !void {
        const msg = try std.fmt.allocPrint(self.alloc, fmt, args);
        errdefer self.alloc.free(msg);
        const timestamp = std.time.timestamp();
        const entry = LogEntry{
            .message = msg,
            .timestamp = timestamp,
        };
        try self.logs.append(self.alloc, entry);
        self.trimLogs();
    }

    pub fn logsSlice(self: *State) []const LogEntry {
        return self.logs.items;
    }

    fn trimLogs(self: *State) void {
        while (self.logs.items.len > MAX_LOGS) {
            const old = self.logs.orderedRemove(0);
            self.alloc.free(old.message);
        }
    }

    pub fn relativePath(self: *State, path: []const u8) []const u8 {
        if (std.mem.startsWith(u8, path, self.project_root)) {
            const idx = self.project_root.len;
            if (path.len > idx) {
                const slice = path[idx..];
                if (slice.len > 0 and slice[0] == '/') {
                    return slice[1..];
                }
                return slice;
            }
        }
        return path;
    }
};

fn classifyEntry(name: []const u8, is_dir: bool) EntryKind {
    if (is_dir) return .directory;
    if (std.mem.endsWith(u8, name, ".zig")) return .auto;
    if (std.mem.endsWith(u8, name, ".jsonc") or std.mem.endsWith(u8, name, ".json")) return .map;
    if (std.mem.endsWith(u8, name, ".db") or std.mem.endsWith(u8, name, ".sqlite")) return .database;
    return .file;
}

fn getFileSize(dir: std.fs.Dir, name: []const u8) !u64 {
    const stat = try dir.statFile(name);
    return stat.size;
}

const dep = @import("dep.zig");

const std = dep.Stdlib.std;
const builtin = dep.Stdlib.builtin;

const vaxis = dep.External.vaxis;

const State = dep.Types.State;
const ExecutionResult = dep.Types.ExecutionResult;

const border = dep.Panes.Shared.border;
const Footer = dep.Panes.Shared.footer;
const Prompt = dep.Panes.Shared.prompt;
const EventLog = dep.Panes.Shared.EventLog;
const FileList = dep.Panes.WSMain.FileList;
const FilePreview = dep.Panes.WSMain.FilePreview;
const BinTree = dep.Panes.WSMain.BinTree;
const Output = dep.Panes.WSBt.Output;
const EngineSpecs = dep.Panes.WSBt.EngineSpecs;
const DatasetSample = dep.Panes.WSBt.DatasetSample;

const Engine = dep.Engine.Engine;
const abi = dep.Engine.abi;
const execution_result_builder = dep.Engine.execution_result;

const path_util = dep.ProjectUtils.path_util;
const auto_gen = dep.TUIUtils.auto_gen_util;

const Event = union(enum) {
    key_press: vaxis.Key,
    winsize: vaxis.Winsize,
};

const EditorSelection = struct {
    value: []const u8,
    owned: bool,
};

const PauseHandle = struct {
    loop: *vaxis.Loop(Event),
    vx: *vaxis.Vaxis,
    tty: *vaxis.Tty,
    was_alt: bool,
    raw_changed: bool,
    resumed: bool = false,

    pub fn init(loop: *vaxis.Loop(Event), vx: *vaxis.Vaxis, tty: *vaxis.Tty) !PauseHandle {
        loop.stop();
        var handle = PauseHandle{
            .loop = loop,
            .vx = vx,
            .tty = tty,
            .was_alt = vx.state.alt_screen,
            .raw_changed = false,
        };
        if (handle.was_alt) try vx.exitAltScreen(tty.writer());
        handle.raw_changed = try suspendTerminal(tty);
        return handle;
    }

    pub fn restore(self: *PauseHandle) !void {
        if (self.resumed) return;
        if (self.raw_changed) try restoreTerminal(self.tty);
        if (self.was_alt) try self.vx.enterAltScreen(self.tty.writer());
        try self.loop.start();
        self.resumed = true;
    }

    pub fn ensureRestored(self: *PauseHandle) void {
        if (!self.resumed) {
            self.restore() catch {};
        }
    }
};

pub fn run(gpa: std.mem.Allocator) !void {
    var tty_buf: [4096]u8 = undefined;
    var tty = try vaxis.Tty.init(&tty_buf);
    defer tty.deinit();

    var vx = try vaxis.init(gpa, .{});
    defer vx.deinit(gpa, tty.writer());

    var loop: vaxis.Loop(Event) = .{ .tty = &tty, .vaxis = &vx };
    try loop.init();
    try loop.start();
    defer loop.stop();

    try vx.enterAltScreen(tty.writer());
    try vx.queryTerminal(tty.writer(), 100 * std.time.ms_per_s);

    const project_root = try path_util.getProjectRootPath(gpa);
    defer gpa.free(project_root);
    const usr_path = try std.fs.path.join(gpa, &.{ project_root, "usr" });
    defer gpa.free(usr_path);

    var state = try State.init(gpa, usr_path, project_root);
    defer state.deinit();

    try state.logFmt("log info: ZORG TUI initialized successfully", .{});
    try state.logFmt("log info: Connected to terminal interface", .{});
    try state.logFmt("log info: Project root: {s}", .{project_root});
    try state.logFmt("log info: Starting directory: {s}", .{usr_path});
    
    const cwd_test = std.fs.cwd();
    if (cwd_test.access(usr_path, .{})) |_| {
        try state.logFmt("log comp: File system access verified", .{});
    } else |err| {
        try state.logFmt("log warn: File system access check failed: {s}", .{@errorName(err)});
    }
    
    if (state.entries.items.len > 0) {
        try state.logFmt("log comp: Loaded {d} entries from starting directory", .{state.entries.items.len});
    } else {
        try state.logFmt("log warn: No entries found in starting directory", .{});
    }
    
    try state.logFmt("log info: Workspace system initialized (Main: Browser, Backtester: Backtest)", .{});
    try state.logFmt("log comp: All systems operational - ready for commands", .{});

    // Main loop
    while (true) {
        const event = loop.nextEvent();

        switch (event) {
            // Prompt pane management
            .key_press => |key| {
                if (state.prompt_mode) {
                    if (key.matches(vaxis.Key.escape, .{})) {
                        state.prompt_mode = false;
                        state.prompt_text.clearRetainingCapacity();
                        try renderTUI(&vx, &tty, &state);
                        continue;
                    } else if (key.matches(vaxis.Key.enter, .{})) {
                        const command = state.prompt_text.items;
                        state.prompt_mode = false;
                        if (command.len > 0) {
                            try executePromptCommand(&state, command, &vx, &tty);
                            renderTUI(&vx, &tty, &state) catch {};
                        }
                        state.prompt_text.clearRetainingCapacity();
                    } else if (key.matches(vaxis.Key.backspace, .{})) {
                        if (state.prompt_text.items.len > 0) {
                            _ = state.prompt_text.pop();
                        }
                    } else if (key.codepoint >= 32 and key.codepoint < 127) {
                        try state.prompt_text.append(state.alloc, @intCast(key.codepoint));
                    } else {
                        continue;
                    }
                }
                
                // Workspace management
                if (!state.prompt_mode) {
                    var is_workspace_key = false;
                    if (key.codepoint == '1') {
                        state.current_workspace = 1;
                        is_workspace_key = true;
                    } else if (key.codepoint == '2') {
                        state.current_workspace = 2;
                        is_workspace_key = true;
                    }

                    // Shared workspace actions
                    if (!is_workspace_key) {
                        if (key.matches('q', .{})) break;
                        if (key.matches('c', .{ .ctrl = true })) break;
                        
                        if (key.matches(':', .{})) {
                            state.prompt_mode = true;
                            state.prompt_text.clearRetainingCapacity();
                            try renderTUI(&vx, &tty, &state);
                            continue;
                        }
                        
                        if (state.current_workspace != 1) {
                            continue;
                        }

                        // Main workspace specific actions
                        if (key.matches(' ', .{})) {
                            if (state.entries.items.len > 0) {
                                const is_at_root = std.mem.eql(u8, state.cwd, state.root);
                                if (!is_at_root) {
                                    if (state.currentEntry()) |entry| {
                                        if (state.selected_paths.contains(entry.path)) {
                                            if (state.selected_paths.fetchRemove(entry.path)) |kv| {
                                                state.alloc.free(kv.key);
                                            }
                                        } else {
                                            const path_key = try state.alloc.dupe(u8, entry.path);
                                            try state.selected_paths.put(path_key, {});
                                        }
                                    }
                                }
                            }
                        }

                        if (key.matches(vaxis.Key.enter, .{})) {
                            if (state.currentEntry()) |entry| {
                                if (entry.is_dir) {
                                    try state.enter();
                                } else {
                                    try openFileInEditor(&state, gpa, entry.path, &loop, &vx, &tty);
                                }
                            }
                            continue;
                        }

                        if (key.matches('c', .{})) {
                            state.alloc.free(state.cwd);
                            state.cwd = try state.alloc.dupe(u8, state.root);
                            try state.loadDirectory();
                        }

                        if (key.matches('j', .{}) or key.matches(vaxis.Key.down, .{})) {
                            state.moveDown();
                        }
                        if (key.matches('k', .{}) or key.matches(vaxis.Key.up, .{})) {
                            state.moveUp();
                        }
                        if (key.matches('l', .{}) or key.matches(vaxis.Key.right, .{})) {
                            try state.enter();
                        }
                        if (key.matches('h', .{}) or key.matches(vaxis.Key.left, .{}) or key.matches(vaxis.Key.backspace, .{})) {
                            try state.goUp();
                        }

                        if (key.matches('g', .{})) {
                            state.cursor = 0;
                        }
                        if (key.matches('G', .{})) {
                            if (state.entries.items.len > 0) {
                                state.cursor = state.entries.items.len - 1;
                            }
                        }

                        if (key.matches('j', .{ .ctrl = true })) {
                            state.preview_scroll_offset += 1;
                        }
                        if (key.matches('k', .{ .ctrl = true })) {
                            if (state.preview_scroll_offset > 0) {
                                state.preview_scroll_offset -= 1;
                            }
                        }
                    }
                }
            },
            .winsize => |ws| {
                try vx.resize(gpa, tty.writer(), ws);
            },
        }
        try renderTUI(&vx, &tty, &state);
    }
}

fn renderTUI(vx: *vaxis.Vaxis, tty: *vaxis.Tty, state: *State) !void {
    const win = vx.window();
    state.beginFrame();
    win.clear();

    const full_w = win.width;
    const full_h = win.height;
    const footer_h: usize = 1;
    const content_h = if (full_h > footer_h) full_h - footer_h else 1;

    // Active workspace: backtest
    if (state.current_workspace == 2) {
        const space_w: usize = 0;
        const space_h: usize = 0;
        const browser_w: usize = (full_w * 2) / 3;
        const right_w: usize = if (full_w > browser_w + space_w * 2) full_w - browser_w - space_w * 2 else 1;
        const log_h: usize = 12;
        const prompt_h: usize = 3;
        const browser_h = if (content_h > log_h + prompt_h + space_h * 2) content_h - log_h - prompt_h - space_h * 2 else 1;
        const preview_h = browser_h + prompt_h;

        {
            const prompt_win = win.child(.{ .x_off = 0, .y_off = 0, .width = @intCast(browser_w), .height = @intCast(prompt_h) });
            Prompt.render(prompt_win, state);
        }
        {
            const browser_win = win.child(.{ .x_off = 0, .y_off = @intCast(prompt_h + space_h), .width = @intCast(browser_w), .height = @intCast(browser_h) });
            EngineSpecs.render(browser_win, state);
        }
        {
            const log_win = win.child(.{ .x_off = 0, .y_off = @intCast(prompt_h + browser_h + space_h * 2), .width = @intCast(browser_w), .height = @intCast(log_h) });
            EventLog.render(log_win, state);
        }
        {
            const preview_win = win.child(.{ .x_off = @intCast(browser_w + space_w), .y_off = 0, .width = @intCast(right_w), .height = @intCast(preview_h) });
            Output.render(preview_win, state);
        }
        {
            const bin_tree_win = win.child(.{ .x_off = @intCast(browser_w + space_w), .y_off = @intCast(prompt_h + browser_h + space_h * 2), .width = @intCast(right_w), .height = @intCast(log_h) });
            DatasetSample.render(bin_tree_win, state);
        }
        {
            const footer_win = win.child(.{ .x_off = 0, .y_off = @intCast(content_h), .width = full_w, .height = footer_h });
            Footer.render(footer_win, state);
        }
    } else { // Active workspace: Main
        const space_w: usize = 0;
        const space_h: usize = 0;
        const browser_w: usize = (full_w * 2) / 3;
        const right_w: usize = if (full_w > browser_w + space_w * 2) full_w - browser_w - space_w * 2 else 1;
        const log_h: usize = 12;
        const prompt_h: usize = 3;
        const browser_h = if (content_h > log_h + prompt_h + space_h * 2) content_h - log_h - prompt_h - space_h * 2 else 1;
        const preview_h = browser_h + prompt_h;

        {
            const prompt_win = win.child(.{ .x_off = 0, .y_off = 0, .width = @intCast(browser_w), .height = @intCast(prompt_h) });
            Prompt.render(prompt_win, state);
        }
        {
            const browser_win = win.child(.{ .x_off = 0, .y_off = @intCast(prompt_h + space_h), .width = @intCast(browser_w), .height = @intCast(browser_h) });
            FileList.render(browser_win, state);
        }
        {
            const log_win = win.child(.{ .x_off = 0, .y_off = @intCast(prompt_h + browser_h + space_h * 2), .width = @intCast(browser_w), .height = @intCast(log_h) });
            EventLog.render(log_win, state);
        }
        {
            const preview_win = win.child(.{ .x_off = @intCast(browser_w + space_w), .y_off = 0, .width = @intCast(right_w), .height = @intCast(preview_h) });
            FilePreview.render(preview_win, state);
        }
        {
            const bin_tree_win = win.child(.{ .x_off = @intCast(browser_w + space_w), .y_off = @intCast(prompt_h + browser_h + space_h * 2), .width = @intCast(right_w), .height = @intCast(log_h) });
            BinTree.render(bin_tree_win, state);
        }
        {
            const footer_win = win.child(.{ .x_off = 0, .y_off = @intCast(content_h), .width = full_w, .height = footer_h });
            Footer.render(footer_win, state);
        }
    }

    try vx.render(tty.writer());
}

fn executePromptCommand(state: *State, command: []const u8, vx: *vaxis.Vaxis, tty: *vaxis.Tty) !void {
    var tokens = std.mem.tokenizeScalar(u8, command, ' ');
    const cmd = tokens.next() orelse {
        try state.logFmt("log error: Empty command", .{});
        return;
    };
    
    // Listen for 'touch'
    // fmt: touch <filename>
    // fmt: touch <filename> <anotherfilename>
    // fmt: touch -auto <autoname>
    if (std.mem.eql(u8, cmd, "touch")) {
        const first_arg = tokens.next() orelse {
            try state.logFmt("log error: touch command requires a filename or '-auto <name>'", .{});
            return;
        };
        
        if (std.mem.eql(u8, first_arg, "-auto")) {
            const auto_name = tokens.next() orelse {
                try state.logFmt("log error: touch -auto requires an auto name", .{});
                return;
            };
            
            if (auto_name.len == 0) {
                try state.logFmt("log error: Auto name cannot be empty", .{});
                return;
            }
            
            try state.logFmt("log info: Creating auto '{s}'...", .{auto_name});
            renderTUI(vx, tty, state) catch {};
            
            auto_gen.createAuto(state.alloc, auto_name, state.project_root) catch |err| {
                const err_msg = switch (err) {
                    error.AutoAlreadyExists => "Auto already exists",
                    error.TemplateNotFound => "Template not found",
                    error.ZDKNotFound => "ZDK source not found",
                    error.EmptyAutoName => "Auto name cannot be empty",
                    else => @errorName(err),
                };
                try state.logFmt("log error: Failed to create auto '{s}': {s}", .{ auto_name, err_msg });
                return;
            };
            
            try state.logFmt("log comp: Successfully created auto '{s}'", .{auto_name});
            try state.logFmt("log info: Auto location: usr/auto/{s}/", .{auto_name});
            
            if (std.mem.indexOf(u8, state.cwd, "usr/auto") != null) {
                try state.loadDirectory();
            }
            return;
        }
        
        var filenames = std.ArrayListUnmanaged([]const u8){};
        defer filenames.deinit(state.alloc);
        
        try filenames.append(state.alloc, first_arg);
        
        while (tokens.next()) |filename| {
            try filenames.append(state.alloc, filename);
        }
        
        var success_count: usize = 0;
        var fail_count: usize = 0;
        
        for (filenames.items) |filename| {
            const file_path = try std.fs.path.join(state.alloc, &.{ state.cwd, filename });
            defer state.alloc.free(file_path);
            
            const file = std.fs.cwd().createFile(file_path, .{}) catch |err| {
                try state.logFmt("log error: Failed to create file '{s}': {s}", .{ filename, @errorName(err) });
                fail_count += 1;
                continue;
            };
            file.close();
            
            try state.logFmt("log comp: Created file '{s}'", .{filename});
            success_count += 1;
        }
        
        if (success_count > 0) {
            try state.logFmt("log comp: Created {d} file(s)", .{success_count});
        }
        if (fail_count > 0) {
            try state.logFmt("log warn: Failed to create {d} file(s)", .{fail_count});
        }
        
        try state.loadDirectory();
        
      // Listen for 'mkdir'
      // fmt: mkdir <dirname>
    } else if (std.mem.eql(u8, cmd, "mkdir")) {
        const is_at_root = std.mem.eql(u8, state.cwd, state.root);
        if (is_at_root) {
            try state.logFmt("log error: Cannot create directories at usr/ root level", .{});
            return;
        }
        
        const dirname = tokens.next() orelse {
            try state.logFmt("log error: mkdir command requires a directory name", .{});
            return;
        };
        
        const dir_path = try std.fs.path.join(state.alloc, &.{ state.cwd, dirname });
        defer state.alloc.free(dir_path);
        
        std.fs.cwd().makeDir(dir_path) catch |err| {
            try state.logFmt("log error: Failed to create directory '{s}': {s}", .{ dirname, @errorName(err) });
            return;
        };
        
        try state.logFmt("log comp: Created directory '{s}' at {s}", .{dirname, dir_path});
        try state.loadDirectory();
        
      // Listen for 'rename'
      // fmt: rename <oldname> <newname>
    } else if (std.mem.eql(u8, cmd, "rename")) {
        const is_at_root = std.mem.eql(u8, state.cwd, state.root);
        if (is_at_root) {
            try state.logFmt("log error: Cannot rename items at usr/ root level", .{});
            return;
        }
        
        const oldname = tokens.next() orelse {
            try state.logFmt("log error: rename command requires old and new filenames", .{});
            return;
        };
        const newname = tokens.next() orelse {
            try state.logFmt("log error: rename command requires a new filename", .{});
            return;
        };
        
        const old_path = try std.fs.path.join(state.alloc, &.{ state.cwd, oldname });
        defer state.alloc.free(old_path);
        const new_path = try std.fs.path.join(state.alloc, &.{ state.cwd, newname });
        defer state.alloc.free(new_path);
        
        std.fs.cwd().rename(old_path, new_path) catch |err| {
            try state.logFmt("log error: Failed to rename '{s}' to '{s}': {s}", .{ oldname, newname, @errorName(err) });
            return;
        };
        
        try state.logFmt("log comp: Renamed '{s}' to '{s}'", .{ oldname, newname });
        try state.loadDirectory();

      // Listen for 'rm'
      // fmt: rm <fileordirname>
      // fmt: rm <fileordirname> <anotherfileordirname>
      // fmt: rm -sel
      // fmt: rm -comp -auto <compiledautoname>
      // fmt: rm -comp -auto -a
    } else if (std.mem.eql(u8, cmd, "rm")) {
        const target = tokens.next() orelse {
            try state.logFmt("log error: rm command requires a filename, '-sel', or '-comp -auto <name>'", .{});
            return;
        };
        
        if (std.mem.eql(u8, target, "-sel")) {
            if (state.selected_paths.count() == 0) {
                try state.logFmt("log warn: No items selected", .{});
                return;
            }
            
            var success_count: usize = 0;
            var fail_count: usize = 0;
            var selected_iter = state.selected_paths.iterator();
            
            while (selected_iter.next()) |entry| {
                const path = entry.key_ptr.*;
                
                if (std.mem.eql(u8, path, state.root)) {
                    try state.logFmt("log error: Cannot delete usr/ root", .{});
                    fail_count += 1;
                    continue;
                }
                
                if (!std.mem.startsWith(u8, path, state.root)) {
                    try state.logFmt("log error: Path '{s}' is not under usr/", .{path});
                    fail_count += 1;
                    continue;
                }
                
                const rel_name = if (std.mem.startsWith(u8, path, state.root))
                    path[state.root.len + 1..]
                else
                    std.fs.path.basename(path);
                
                std.fs.cwd().deleteFile(path) catch |err| {
                    if (err == error.IsDir) {
                        std.fs.cwd().deleteTree(path) catch |del_err| {
                            try state.logFmt("log error: Failed to delete '{s}': {s}", .{ rel_name, @errorName(del_err) });
                            fail_count += 1;
                            continue;
                        };
                        try state.logFmt("log comp: Deleted directory '{s}'", .{rel_name});
                        success_count += 1;
                    } else {
                        try state.logFmt("log error: Failed to delete '{s}': {s}", .{ rel_name, @errorName(err) });
                        fail_count += 1;
                    }
                    continue;
                };
                
                try state.logFmt("log comp: Deleted file '{s}'", .{rel_name});
                success_count += 1;
            }
            
            var clear_iter = state.selected_paths.iterator();
            while (clear_iter.next()) |entry| {
                state.alloc.free(entry.key_ptr.*);
            }
            state.selected_paths.clearAndFree();
            
            if (success_count > 0) {
                try state.logFmt("log comp: Deleted {d} item(s)", .{success_count});
            }
            if (fail_count > 0) {
                try state.logFmt("log warn: Failed to delete {d} item(s)", .{fail_count});
            }
            
            try state.loadDirectory();
            return;
        }
        
        if (std.mem.eql(u8, target, "-comp")) {
            const auto_flag = tokens.next() orelse {
                try state.logFmt("log error: rm -comp requires '-auto' flag", .{});
                return;
            };
            
            if (!std.mem.eql(u8, auto_flag, "-auto")) {
                try state.logFmt("log error: rm -comp requires '-auto' flag", .{});
                return;
            }
            
            const first_auto = tokens.next() orelse {
                try state.logFmt("log error: rm -comp -auto requires at least one auto name or '-a'", .{});
                return;
            };
            
            if (std.mem.eql(u8, first_auto, "-a")) {
                const auto_bin_path = try std.fs.path.join(state.alloc, &.{ state.project_root, "zig-out/bin/auto" });
                defer state.alloc.free(auto_bin_path);
                
                var dir = std.fs.cwd().openDir(auto_bin_path, .{ .iterate = true }) catch |err| {
                    try state.logFmt("log error: Failed to open auto bin directory: {s}", .{@errorName(err)});
                    return;
                };
                defer dir.close();
                
                var success_count: usize = 0;
                var fail_count: usize = 0;
                
                var iter = dir.iterate();
                while (try iter.next()) |entry| {
                    if (entry.kind == .file and (std.mem.endsWith(u8, entry.name, ".dylib") or 
                                                  std.mem.endsWith(u8, entry.name, ".so") or 
                                                  std.mem.endsWith(u8, entry.name, ".dll"))) {
                        const file_path = try std.fs.path.join(state.alloc, &.{ auto_bin_path, entry.name });
                        defer state.alloc.free(file_path);
                        
                        std.fs.cwd().deleteFile(file_path) catch |err| {
                            try state.logFmt("log error: Failed to delete '{s}': {s}", .{ entry.name, @errorName(err) });
                            fail_count += 1;
                            continue;
                        };
                        
                        success_count += 1;
                    }
                }
                
                if (success_count > 0) {
                    try state.logFmt("log comp: Deleted all {d} compiled auto(s)", .{success_count});
                } else {
                    try state.logFmt("log warn: No compiled autos found to delete", .{});
                }
                if (fail_count > 0) {
                    try state.logFmt("log warn: Failed to delete {d} compiled auto(s)", .{fail_count});
                }
                
                return;
            }
            
            var auto_names = std.ArrayListUnmanaged([]const u8){};
            defer auto_names.deinit(state.alloc);
            try auto_names.append(state.alloc, first_auto);
            
            while (tokens.next()) |auto_name| {
                try auto_names.append(state.alloc, auto_name);
            }
            
            var success_count: usize = 0;
            var fail_count: usize = 0;
            
            for (auto_names.items) |auto_name| {
                const name_without_ext = blk: {
                    if (std.mem.endsWith(u8, auto_name, ".dylib")) {
                        break :blk auto_name[0..auto_name.len - 6];
                    } else if (std.mem.endsWith(u8, auto_name, ".so")) {
                        break :blk auto_name[0..auto_name.len - 3];
                    } else if (std.mem.endsWith(u8, auto_name, ".dll")) {
                        break :blk auto_name[0..auto_name.len - 4];
                    } else {
                        break :blk auto_name;
                    }
                };
                
                const ext = if (@import("builtin").os.tag == .macos) ".dylib" else ".so";
                
                const dylib_name = try std.fmt.allocPrint(state.alloc, "{s}{s}", .{ name_without_ext, ext });
                defer state.alloc.free(dylib_name);
                
                const dylib_path = try std.fs.path.join(state.alloc, &.{ state.project_root, "zig-out/bin/auto", dylib_name });
                defer state.alloc.free(dylib_path);
                
                std.fs.cwd().deleteFile(dylib_path) catch |err| {
                    try state.logFmt("log error: Failed to delete compiled auto '{s}': {s}", .{ name_without_ext, @errorName(err) });
                    fail_count += 1;
                    continue;
                };
                
                try state.logFmt("log comp: Deleted compiled auto '{s}'", .{name_without_ext});
                success_count += 1;
            }
            
            if (success_count > 0) {
                try state.logFmt("log comp: Deleted {d} compiled auto(s)", .{success_count});
            }
            if (fail_count > 0) {
                try state.logFmt("log warn: Failed to delete {d} compiled auto(s)", .{fail_count});
            }
            
            return;
        }
        
        var filenames = std.ArrayListUnmanaged([]const u8){};
        defer filenames.deinit(state.alloc);
        try filenames.append(state.alloc, target);
        
        while (tokens.next()) |filename| {
            try filenames.append(state.alloc, filename);
        }
        
        var success_count: usize = 0;
        var fail_count: usize = 0;
        
        for (filenames.items) |filename| {
            const file_path = try std.fs.path.join(state.alloc, &.{ state.cwd, filename });
            defer state.alloc.free(file_path);
            
            if (std.mem.eql(u8, file_path, state.root)) {
                try state.logFmt("log error: Cannot delete usr/ root", .{});
                fail_count += 1;
                continue;
            }
            
            const stat = std.fs.cwd().statFile(file_path) catch |err| {
                try state.logFmt("log error: Failed to stat '{s}': {s}", .{ filename, @errorName(err) });
                fail_count += 1;
                continue;
            };
            
            if (stat.kind == .directory) {
                // Delete directory recursively
                std.fs.cwd().deleteTree(file_path) catch |del_err| {
                    try state.logFmt("log error: Failed to delete directory '{s}': {s}", .{ filename, @errorName(del_err) });
                    fail_count += 1;
                    continue;
                };
                try state.logFmt("log comp: Deleted directory '{s}'", .{filename});
                success_count += 1;
            } else {
                std.fs.cwd().deleteFile(file_path) catch |err| {
                    try state.logFmt("log error: Failed to delete file '{s}': {s}", .{ filename, @errorName(err) });
                    fail_count += 1;
                    continue;
                };
                try state.logFmt("log comp: Deleted file '{s}'", .{filename});
                success_count += 1;
            }
        }
        
        if (success_count > 0) {
            try state.logFmt("log comp: Deleted {d} item(s)", .{success_count});
        }
        if (fail_count > 0) {
            try state.logFmt("log warn: Failed to delete {d} item(s)", .{fail_count});
        }
        
        try state.loadDirectory();

      // Listen for 'comp'
      // fmt: comp -auto <autoname>
      // fmt: comp -auto <autoname> <anotherautoname>
      // fmt: comp -auto -sel
    } else if (std.mem.eql(u8, cmd, "comp")) {
        const first_arg = tokens.next() orelse {
            try state.logFmt("log error: comp command requires '-auto' flag", .{});
            return;
        };
        
        if (!std.mem.eql(u8, first_arg, "-auto")) {
            try state.logFmt("log error: comp command requires '-auto' flag", .{});
            return;
        }
        
        const second_arg = tokens.next();
        
        if (second_arg) |arg| {
            if (std.mem.eql(u8, arg, "-sel")) {
                if (state.selected_paths.count() == 0) {
                    try state.logFmt("log warn: No items selected", .{});
                    return;
                }
                
                var auto_names = std.ArrayListUnmanaged([]const u8){};
                defer {
                    for (auto_names.items) |name| {
                        state.alloc.free(name);
                    }
                    auto_names.deinit(state.alloc);
                }
                
                var selected_iter = state.selected_paths.iterator();
                while (selected_iter.next()) |entry| {
                    const path = entry.key_ptr.*;
                    if (isAutoDir(path)) {
                        const auto_name = std.fs.path.basename(path);
                        const auto_name_dup = try state.alloc.dupe(u8, auto_name);
                        try auto_names.append(state.alloc, auto_name_dup);
                    }
                }
                
                if (auto_names.items.len == 0) {
                    try state.logFmt("log warn: No auto directories selected", .{});
                    return;
                }
                
                var success_count: usize = 0;
                var fail_count: usize = 0;
                
                for (auto_names.items) |auto_name| {
                    try state.logFmt("log info: Compiling auto '{s}'...", .{auto_name});
                    renderTUI(vx, tty, state) catch {};
                    
                    const compile_result = auto_gen.compileAuto(state.alloc, auto_name, state.project_root) catch |err| {
                        const err_msg = switch (err) {
                            error.AutoNotFound => "Auto not found",
                            else => @errorName(err),
                        };
                        try state.logFmt("log error: Failed to compile auto '{s}': {s}", .{ auto_name, err_msg });
                        fail_count += 1;
                        continue;
                    };
                    
                    if (compile_result.stderr.len > 0) {
                        var stderr_lines = std.mem.splitScalar(u8, compile_result.stderr, '\n');
                        while (stderr_lines.next()) |line| {
                            if (line.len > 0) {
                                try state.logFmt("log error: {s}", .{line});
                            }
                        }
                        state.alloc.free(compile_result.stderr);
                        fail_count += 1;
                        continue;
                    }
                    state.alloc.free(compile_result.stderr);
                    
                    try state.logFmt("log comp: Successfully compiled auto '{s}'", .{auto_name});
                    success_count += 1;
                }
                
                if (success_count > 0) {
                    try state.logFmt("log comp: Compiled {d} auto(s) successfully", .{success_count});
                }
                if (fail_count > 0) {
                    try state.logFmt("log warn: Failed to compile {d} auto(s)", .{fail_count});
                }
                return;
            }
        }
        
        var auto_names = std.ArrayListUnmanaged([]const u8){};
        defer auto_names.deinit(state.alloc);
        
        if (second_arg) |name| {
            try auto_names.append(state.alloc, name);
            while (tokens.next()) |name_arg| {
                try auto_names.append(state.alloc, name_arg);
            }
        } else {
            try state.logFmt("log error: comp -auto requires auto name(s) or -sel flag", .{});
            return;
        }
        
        var success_count: usize = 0;
        var fail_count: usize = 0;
        
        for (auto_names.items) |auto_name| {
            if (auto_name.len == 0) {
                try state.logFmt("log warn: Skipping empty auto name", .{});
                fail_count += 1;
                continue;
            }
            
            try state.logFmt("log info: Compiling auto '{s}'...", .{auto_name});
            renderTUI(vx, tty, state) catch {};
            
            const compile_result = auto_gen.compileAuto(state.alloc, auto_name, state.project_root) catch |err| {
                const err_msg = switch (err) {
                    error.AutoNotFound => "Auto not found",
                    else => @errorName(err),
                };
                try state.logFmt("log error: Failed to compile auto '{s}': {s}", .{ auto_name, err_msg });
                fail_count += 1;
                continue;
            };
            
            if (compile_result.stderr.len > 0) {
                var stderr_lines = std.mem.splitScalar(u8, compile_result.stderr, '\n');
                while (stderr_lines.next()) |line| {
                    if (line.len > 0) {
                        try state.logFmt("log error: {s}", .{line});
                    }
                }
                state.alloc.free(compile_result.stderr);
                fail_count += 1;
                continue;
            }
            state.alloc.free(compile_result.stderr);
            
            try state.logFmt("log comp: Successfully compiled auto '{s}'", .{auto_name});
            success_count += 1;
        }
        
        if (success_count > 0) {
            try state.logFmt("log comp: Compiled {d} auto(s) successfully", .{success_count});
        }
        if (fail_count > 0) {
            try state.logFmt("log warn: Failed to compile {d} auto(s)", .{fail_count});
        }

      // Listen for 'mv'
      // fmt: mv <currentpath> <newpath>
      // fmt: mv -sel <newpath>
    } else if (std.mem.eql(u8, cmd, "mv")) {
        const source = tokens.next() orelse {
            try state.logFmt("log error: mv command requires source and destination", .{});
            return;
        };
        
        if (std.mem.eql(u8, source, "-sel")) {
            const dest_path = tokens.next() orelse {
                try state.logFmt("log error: mv -sel requires a destination path", .{});
                return;
            };
            
            if (state.selected_paths.count() == 0) {
                try state.logFmt("log warn: No items selected", .{});
                return;
            }
            
            const dest_full = if (std.fs.path.isAbsolute(dest_path))
                try state.alloc.dupe(u8, dest_path)
            else
                try std.fs.path.join(state.alloc, &.{ state.cwd, dest_path });
            defer state.alloc.free(dest_full);
            
            if (!std.mem.startsWith(u8, dest_full, state.root)) {
                try state.logFmt("log error: Destination must be under usr/", .{});
                return;
            }
            
            std.fs.cwd().makePath(dest_full) catch |err| {
                try state.logFmt("log error: Failed to create destination directory '{s}': {s}", .{ dest_path, @errorName(err) });
                return;
            };
            
            var success_count: usize = 0;
            var fail_count: usize = 0;
            var selected_iter = state.selected_paths.iterator();
            
            while (selected_iter.next()) |entry| {
                const src_path = entry.key_ptr.*;
                
                if (std.mem.eql(u8, src_path, state.root)) {
                    try state.logFmt("log error: Cannot move usr/ root", .{});
                    fail_count += 1;
                    continue;
                }
                
                if (!std.mem.startsWith(u8, src_path, state.root)) {
                    try state.logFmt("log error: Path '{s}' is not under usr/", .{src_path});
                    fail_count += 1;
                    continue;
                }
                
                const basename = std.fs.path.basename(src_path);
                const new_path = try std.fs.path.join(state.alloc, &.{ dest_full, basename });
                defer state.alloc.free(new_path);
                
                std.fs.cwd().rename(src_path, new_path) catch |err| {
                    const rel_name = if (std.mem.startsWith(u8, src_path, state.root))
                        src_path[state.root.len + 1..]
                    else
                        basename;
                    try state.logFmt("log error: Failed to move '{s}': {s}", .{ rel_name, @errorName(err) });
                    fail_count += 1;
                    continue;
                };
                
                const rel_name = if (std.mem.startsWith(u8, src_path, state.root))
                    src_path[state.root.len + 1..]
                else
                    basename;
                try state.logFmt("log comp: Moved '{s}' to '{s}'", .{ rel_name, dest_path });
                success_count += 1;
            }
            
            var clear_iter = state.selected_paths.iterator();
            while (clear_iter.next()) |entry| {
                state.alloc.free(entry.key_ptr.*);
            }
            state.selected_paths.clearAndFree();
            
            if (success_count > 0) {
                try state.logFmt("log comp: Moved {d} item(s) to '{s}'", .{ success_count, dest_path });
            }
            if (fail_count > 0) {
                try state.logFmt("log warn: Failed to move {d} item(s)", .{fail_count});
            }
            
            try state.loadDirectory();
            return;
        }
        
        const dest_name = tokens.next() orelse {
            try state.logFmt("log error: mv command requires source and destination", .{});
            return;
        };
        
        const is_at_root = std.mem.eql(u8, state.cwd, state.root);
        if (is_at_root) {
            try state.logFmt("log error: Cannot move items at usr/ root level", .{});
            return;
        }
        
        const old_path = try std.fs.path.join(state.alloc, &.{ state.cwd, source });
        defer state.alloc.free(old_path);
        const new_path = try std.fs.path.join(state.alloc, &.{ state.cwd, dest_name });
        defer state.alloc.free(new_path);
        
        std.fs.cwd().rename(old_path, new_path) catch |err| {
            try state.logFmt("log error: Failed to move '{s}' to '{s}': {s}", .{ source, dest_name, @errorName(err) });
            return;
        };
        
        try state.logFmt("log comp: Moved '{s}' to '{s}'", .{ source, dest_name });
        try state.loadDirectory();
        
      // Listen for 'assemble'
      // fmt: assemble <mapfile.jsonc>
    } else if (std.mem.eql(u8, cmd, "assemble")) {
        const map_file = tokens.next() orelse {
            try state.logFmt("log error: assemble command requires a map file", .{});
            return;
        };
        
        const map_path = if (std.fs.path.isAbsolute(map_file))
            try state.alloc.dupe(u8, map_file)
        else
            try std.fs.path.join(state.alloc, &.{ state.project_root, "usr", "map", map_file });
        defer state.alloc.free(map_path);
        
        try state.logFmt("log info: Assembling engine for map file 'usr/map/{s}'", .{map_file});
        
        const start = std.time.milliTimestamp();
        const engine = Engine.init(state.alloc, map_path) catch |err| {
            try state.logFmt("log error: Engine assembly failed: {s}", .{@errorName(err)});
            return;
        };
        const elapsed = std.time.milliTimestamp() - start;
        
        if (state.assembled_engine) |*old_engine| {
            old_engine.deinit();
        }
        
        state.assembled_engine = engine;
        
        const mode_str = switch (engine.map.exec_mode) {
            .LiveExecution => "LIVE",
            .Backtest => "BACKTEST",
            .Optimization => "OPTIMIZATION",
        };
        try state.logFmt("log comp: Engine assembled successfully in {d}ms", .{elapsed});
        try state.logFmt("log info: Execution mode: {s}", .{mode_str});
        
        if (engine.map.exec_mode == .Backtest) {
            state.current_workspace = 2;
            try state.logFmt("log info: Switched to Backtester workspace", .{});
        }
        renderTUI(vx, tty, state) catch {};

      // Listen for 'engine'
      // fmt: engine run
    } else if (std.mem.eql(u8, cmd, "engine")) {
        const subcmd = tokens.next() orelse {
            try state.logFmt("log error: engine command requires a subcommand (run)", .{});
            return;
        };
        
        if (std.mem.eql(u8, subcmd, "run")) {
            if (state.assembled_engine == null) {
                try state.logFmt("log error: No engine assembled. Use 'assemble <map>' first", .{});
                return;
            }
            
            try executeEngineRun(state, vx, tty);
        } else {
            try state.logFmt("log error: Unknown engine subcommand '{s}'. Use: engine run", .{subcmd});
        }
      
      // Handle every non-existant command   
    } else {
        try state.logFmt("log error: Unknown command '{s}'.", .{cmd});
    }
}

fn openFileInEditor(
    state: *State,
    gpa: std.mem.Allocator,
    path: []const u8,
    loop: *vaxis.Loop(Event),
    vx: *vaxis.Vaxis,
    tty: *vaxis.Tty,
) !void {
    var pause = try PauseHandle.init(loop, vx, tty);
    defer pause.ensureRestored();

    const editor = try selectEditor(gpa);
    defer if (editor.owned) gpa.free(editor.value);

    const rel = state.relativePath(path);
    try state.logFmt("log info: Opening file '{s}' in external editor (Neovim)", .{rel});

    spawnEditorProcess(gpa, editor.value, path) catch |err| {
        try state.logFmt("log warn: Failed to open file '{s}' in external editor: {s}", .{ rel, @errorName(err) });
        try state.setMessage("Failed to open editor");
        return err;
    };

    try pause.restore();
    try state.logFmt("log info: Successfully closed editor for file '{s}'", .{rel});
    try state.setMessage("File edited successfully");
}

fn selectEditor(gpa: std.mem.Allocator) !EditorSelection {
    const vars = [_][]const u8{ "VISUAL", "EDITOR" };
    for (vars) |name| {
        if (std.process.getEnvVarOwned(gpa, name)) |value| {
            if (value.len == 0) {
                gpa.free(value);
                continue;
            }
            return .{ .value = value, .owned = true };
        } else |_| {}
    }
    return .{ .value = "nvim", .owned = false };
}

fn spawnEditorProcess(gpa: std.mem.Allocator, editor: []const u8, path: []const u8) !void {
    var argv = [_][]const u8{ editor, path };
    var child = std.process.Child.init(&argv, gpa);
    child.stdin_behavior = .Inherit;
    child.stdout_behavior = .Inherit;
    child.stderr_behavior = .Inherit;

    const term = try child.spawnAndWait();
    switch (term) {
        .Exited => |code| {
            if (code == 0) return;
        },
        else => {},
    }
    return error.EditorFailed;
}

fn isAutoDir(path: []const u8) bool {
    return std.mem.indexOf(u8, path, "/usr/auto/") != null;
}

fn executeEngineRun(state: *State, vx: *vaxis.Vaxis, tty: *vaxis.Tty) !void {
    const engine = &state.assembled_engine.?;
    
    try state.logFmt("log info: Starting engine execution", .{});
    renderTUI(vx, tty, state) catch {};
    
    const start_total = std.time.milliTimestamp();
    
    const mode_str = switch (engine.map.exec_mode) {
        .LiveExecution => "LIVE",
        .Backtest => "BACKTEST",
        .Optimization => "OPTIMIZATION",
    };
    try state.logFmt("log info: Execution mode: {s}", .{mode_str});
    renderTUI(vx, tty, state) catch {};
    
    try state.logFmt("log info: Processing {d} data points", .{engine.track.size});
    renderTUI(vx, tty, state) catch {};
    
    const start_exec = std.time.milliTimestamp();
    try state.logFmt("log info: Running strategy logic", .{});
    renderTUI(vx, tty, state) catch {};
    
    // Reset trail to first row before execution (allows multiple runs)
    try engine.trail.load(engine.track, 0);
    
    engine.ExecuteProcess() catch |err| {
        try state.logFmt("log error: Engine execution failed: {s}", .{@errorName(err)});
        const exec_time = 0;
        const total_time = std.time.milliTimestamp() - start_total;
        
        // Free old result
        if (state.execution_result) |*old| {
            state.alloc.free(old.map_path);
            state.alloc.free(old.auto_name);
            state.alloc.free(old.auto_path);
            state.alloc.free(old.exec_mode);
            state.alloc.free(old.db_path);
            state.alloc.free(old.feed_mode);
            state.alloc.free(old.table);
            state.alloc.free(old.output_dir);
            state.alloc.free(old.output_orders_path);
            state.alloc.free(old.output_fills_path);
            state.alloc.free(old.output_positions_path);
        }
        
        // Build failed result using engine helper
        const failed_result = try execution_result_builder.buildExecutionResult(
            state.alloc,
            engine,
            engine.map.auto,
            state.project_root,
            0, // init_time_ms
            exec_time,
            total_time,
            false, // success
        );
        state.execution_result = failed_result;
        return;
    };
    
    const exec_time = std.time.milliTimestamp() - start_exec;
    const total_time = std.time.milliTimestamp() - start_total;
    
    try state.logFmt("log info: Strategy execution completed", .{});
    renderTUI(vx, tty, state) catch {};
    
    try state.logFmt("log info: Writing output files", .{});
    renderTUI(vx, tty, state) catch {};
    
    // Free old result
    if (state.execution_result) |*old_result| {
        state.alloc.free(old_result.map_path);
        state.alloc.free(old_result.auto_name);
        state.alloc.free(old_result.auto_path);
        state.alloc.free(old_result.exec_mode);
        state.alloc.free(old_result.db_path);
        state.alloc.free(old_result.feed_mode);
        state.alloc.free(old_result.table);
        state.alloc.free(old_result.output_dir);
        state.alloc.free(old_result.output_orders_path);
        state.alloc.free(old_result.output_fills_path);
        state.alloc.free(old_result.output_positions_path);
    }
    
    // Build success result using engine helper
    const result = try execution_result_builder.buildExecutionResult(
        state.alloc,
        engine,
        engine.map.auto,
        state.project_root,
        0, // init_time_ms (not tracked for assembled engine)
        exec_time,
        total_time,
        true, // success
    );
    state.execution_result = result;
    
    try state.logFmt("log comp: Execution completed in {d}ms", .{exec_time});
    try state.logFmt("log info: Output files written to {s}", .{engine.out.abs_dir_path});
    renderTUI(vx, tty, state) catch {};
}

fn suspendTerminal(tty: *vaxis.Tty) !bool {
    if (comptime builtin.os.tag == .windows) return false;
    const T = @TypeOf(tty.*);
    if (comptime @hasField(T, "termios") and @hasField(T, "fd")) {
        try std.posix.tcsetattr(tty.fd, .FLUSH, tty.termios);
        return true;
    }
    return false;
}

fn restoreTerminal(tty: *vaxis.Tty) !void {
    if (comptime builtin.os.tag == .windows) return;
    const T = @TypeOf(tty.*);
    if (comptime @hasDecl(T, "makeRaw") and @hasField(T, "fd")) {
        _ = try T.makeRaw(tty.fd);
    }
}

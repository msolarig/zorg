const std = @import("std");
const vaxis = @import("vaxis");
const path_util = @import("../utils/path_utility.zig");
const builtin = @import("builtin");

const types = @import("types.zig");
const State = types.State;
const ExecutionResult = types.ExecutionResult;

const panes = @import("panes.zig");
const Footer = panes.footer;
const FileList = panes.FileList;
const FilePreview = panes.FilePreview;
const BinTree = panes.BinTree;
const EventLog = panes.EventLog;
const border = panes.border;
const ConfigView = panes.ConfigView;
const Assembly = panes.Assembly;
const Execution = panes.Execution;
const Output = panes.Output;
const EngineSpecs = panes.EngineSpecs;
const DatasetSample = panes.DatasetSample;

const Engine = @import("../engine/engine.zig").Engine;
const abi = @import("../zdk/abi.zig");
const auto_creator = @import("../utils/auto_creator.zig");

// Helper function to render the TUI (extracted from main loop)
fn renderTUI(vx: *vaxis.Vaxis, tty: *vaxis.Tty, state: *State) !void {
    const win = vx.window();
    state.beginFrame();
    win.clear();

    const full_w = win.width;
    const full_h = win.height;
    const footer_h: usize = 1;
    const content_h = if (full_h > footer_h) full_h - footer_h else 1;

    if (state.current_workspace == 2) {
        // WORKSPACE 2: Same layout as Main, but empty panes (only log is active)
        const space_w: usize = 0;
        const space_h: usize = 0;
        const browser_w: usize = (full_w * 2) / 3;
        const right_w: usize = if (full_w > browser_w + space_w * 2) full_w - browser_w - space_w * 2 else 1;
        const log_h: usize = 24;
        const prompt_h: usize = 3;
        const browser_h = if (content_h > log_h + prompt_h + space_h * 2) content_h - log_h - prompt_h - space_h * 2 else 1;
        const preview_h = browser_h + prompt_h;

        // Prompt pane (same as Main workspace)
        {
            const prompt_win = win.child(.{ .x_off = 0, .y_off = 0, .width = @intCast(browser_w), .height = @intCast(prompt_h) });
            border.draw(prompt_win, "");
            const prompt_style = if (state.prompt_mode)
                vaxis.Style{ .fg = vaxis.Color{ .index = 187 }, .bold = true }
            else
                vaxis.Style{ .fg = vaxis.Color{ .index = 180 } };
            if (state.prompt_mode) {
                const prompt_text_slice = state.prompt_text.items;
                const prompt_display = if (prompt_text_slice.len > 0)
                    state.frameFmt(">{s}", .{prompt_text_slice}) catch ">"
                else
                    ">";
                const seg = vaxis.Cell.Segment{ .text = prompt_display, .style = prompt_style };
                _ = prompt_win.print(&[_]vaxis.Cell.Segment{seg}, .{ .row_offset = 1, .col_offset = 1 });
            } else {
                const seg = vaxis.Cell.Segment{ .text = ":", .style = prompt_style };
                _ = prompt_win.print(&[_]vaxis.Cell.Segment{seg}, .{ .row_offset = 1, .col_offset = 1 });
            }
        }
        // Browser pane - Engine specs
        {
            const browser_win = win.child(.{ .x_off = 0, .y_off = @intCast(prompt_h + space_h), .width = @intCast(browser_w), .height = @intCast(browser_h) });
            EngineSpecs.render(browser_win, state);
        }
        // Log pane (active - shows logs)
        {
            const log_win = win.child(.{ .x_off = 0, .y_off = @intCast(prompt_h + browser_h + space_h * 2), .width = @intCast(browser_w), .height = @intCast(log_h) });
            EventLog.render(log_win, state);
        }
        // Preview pane - Execution stats/output (only when execution_result exists)
        {
            const preview_win = win.child(.{ .x_off = @intCast(browser_w + space_w), .y_off = 0, .width = @intCast(right_w), .height = @intCast(preview_h) });
            if (state.execution_result) |_| {
                Output.render(preview_win, state);
            } else {
                border.draw(preview_win, "");
            }
        }
        // Binary Tree pane - Dataset sample
        {
            const bin_tree_win = win.child(.{ .x_off = @intCast(browser_w + space_w), .y_off = @intCast(prompt_h + browser_h + space_h * 2), .width = @intCast(right_w), .height = @intCast(log_h) });
            DatasetSample.render(bin_tree_win, state);
        }
        {
            const footer_win = win.child(.{ .x_off = 0, .y_off = @intCast(content_h), .width = full_w, .height = footer_h });
            Footer.render(footer_win, state);
        }
    } else {
        // WORKSPACE 1: Browser Layout
        const space_w: usize = 0;
        const space_h: usize = 0;
        const browser_w: usize = (full_w * 2) / 3;
        const right_w: usize = if (full_w > browser_w + space_w * 2) full_w - browser_w - space_w * 2 else 1;
        const log_h: usize = 24;
        const prompt_h: usize = 3;
        const browser_h = if (content_h > log_h + prompt_h + space_h * 2) content_h - log_h - prompt_h - space_h * 2 else 1;
        const preview_h = browser_h + prompt_h;

        {
            const prompt_win = win.child(.{ .x_off = 0, .y_off = 0, .width = @intCast(browser_w), .height = @intCast(prompt_h) });
            border.draw(prompt_win, "");
            const prompt_style = if (state.prompt_mode)
                vaxis.Style{ .fg = vaxis.Color{ .index = 187 }, .bold = true }
            else
                vaxis.Style{ .fg = vaxis.Color{ .index = 180 } };
            if (state.prompt_mode) {
                const prompt_text_slice = state.prompt_text.items;
                const prompt_display = if (prompt_text_slice.len > 0)
                    state.frameFmt(">{s}", .{prompt_text_slice}) catch ">"
                else
                    ">";
                const seg = vaxis.Cell.Segment{ .text = prompt_display, .style = prompt_style };
                _ = prompt_win.print(&[_]vaxis.Cell.Segment{seg}, .{ .row_offset = 1, .col_offset = 1 });
            } else {
                const seg = vaxis.Cell.Segment{ .text = ":", .style = prompt_style };
                _ = prompt_win.print(&[_]vaxis.Cell.Segment{seg}, .{ .row_offset = 1, .col_offset = 1 });
            }
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
    // Parse command: create/rename/delete <args>
    var tokens = std.mem.tokenizeScalar(u8, command, ' ');
    const cmd = tokens.next() orelse {
        try state.logFmt("log error: Empty command", .{});
        return;
    };
    
    if (std.mem.eql(u8, cmd, "touch")) {
        // Check for -auto flag
        const first_arg = tokens.next() orelse {
            try state.logFmt("log error: touch command requires a filename or '-auto <name>'", .{});
            return;
        };
        
        if (std.mem.eql(u8, first_arg, "-auto")) {
            // Create new auto: touch -auto <auto_name>
            const auto_name = tokens.next() orelse {
                try state.logFmt("log error: touch -auto requires an auto name", .{});
                return;
            };
            
            // Validate auto name
            if (auto_name.len == 0) {
                try state.logFmt("log error: Auto name cannot be empty", .{});
                return;
            }
            
            try state.logFmt("log info: Creating auto '{s}'...", .{auto_name});
            renderTUI(vx, tty, state) catch {};
            
            auto_creator.createAuto(state.alloc, auto_name, state.project_root) catch |err| {
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
            
            // Reload directory if we're in the auto directory
            if (std.mem.indexOf(u8, state.cwd, "usr/auto") != null) {
                try state.loadDirectory();
            }
            return;
        }
        
        // Regular file creation: touch <filename1> [filename2] ...
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
        
    } else if (std.mem.eql(u8, cmd, "mkdir")) {
        // Create directory: mkdir <dirname>
        // Check if we're at root level - don't allow creating directories at usr/
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
        
        try state.logFmt("log comp: Created directory '{s}'", .{dirname});
        try state.loadDirectory();
        
    } else if (std.mem.eql(u8, cmd, "rename")) {
        // Rename file: rename <oldname> <newname>
        // Check if we're at root level - don't allow renaming at usr/
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
        
    } else if (std.mem.eql(u8, cmd, "rm")) {
        const target = tokens.next() orelse {
            try state.logFmt("log error: rm command requires a filename or '-sel'", .{});
            return;
        };
        
        // Handle bulk deletion of selected items
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
                
                // Check if we're trying to delete at usr/ root level
                if (std.mem.eql(u8, path, state.root)) {
                    try state.logFmt("log error: Cannot delete usr/ root", .{});
                    fail_count += 1;
                    continue;
                }
                
                // Check if path is under usr/ root
                if (!std.mem.startsWith(u8, path, state.root)) {
                    try state.logFmt("log error: Path '{s}' is not under usr/", .{path});
                    fail_count += 1;
                    continue;
                }
                
                // Get relative name for logging
                const rel_name = if (std.mem.startsWith(u8, path, state.root))
                    path[state.root.len + 1..] // +1 to skip the trailing slash
                else
                    std.fs.path.basename(path);
                
                // Try to delete as file first
                std.fs.cwd().deleteFile(path) catch |err| {
                    if (err == error.IsDir) {
                        // Try to delete as directory
                        std.fs.cwd().deleteDir(path) catch |del_err| {
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
            
            // Clear selections after operation
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
        
        // Multiple file/directory deletion: rm <file1> [file2] ...
        // Check if we're at root level - don't allow deleting at usr/
        const is_at_root = std.mem.eql(u8, state.cwd, state.root);
        if (is_at_root) {
            try state.logFmt("log error: Cannot delete items at usr/ root level", .{});
            return;
        }
        
        // Collect all filenames
        var filenames = std.ArrayListUnmanaged([]const u8){};
        defer filenames.deinit(state.alloc);
        try filenames.append(state.alloc, target); // Add the first one we already got
        
        while (tokens.next()) |filename| {
            try filenames.append(state.alloc, filename);
        }
        
        var success_count: usize = 0;
        var fail_count: usize = 0;
        
        for (filenames.items) |filename| {
            const file_path = try std.fs.path.join(state.alloc, &.{ state.cwd, filename });
            defer state.alloc.free(file_path);
            
            // Check if it's a directory or file
            const stat = std.fs.cwd().statFile(file_path) catch |err| {
                if (err == error.IsDir) {
                    // Try to delete as directory
                    std.fs.cwd().deleteDir(file_path) catch |del_err| {
                        try state.logFmt("log error: Failed to delete directory '{s}': {s}", .{ filename, @errorName(del_err) });
                        fail_count += 1;
                        continue;
                    };
                    try state.logFmt("log comp: Deleted directory '{s}'", .{filename});
                    success_count += 1;
                } else {
                    try state.logFmt("log error: Failed to delete '{s}': {s}", .{ filename, @errorName(err) });
                    fail_count += 1;
                }
                continue;
            };
            
            _ = stat; // Use stat to determine it's a file
            std.fs.cwd().deleteFile(file_path) catch |err| {
                try state.logFmt("log error: Failed to delete file '{s}': {s}", .{ filename, @errorName(err) });
                fail_count += 1;
                continue;
            };
            
            try state.logFmt("log comp: Deleted file '{s}'", .{filename});
            success_count += 1;
        }
        
        if (success_count > 0) {
            try state.logFmt("log comp: Deleted {d} item(s)", .{success_count});
        }
        if (fail_count > 0) {
            try state.logFmt("log warn: Failed to delete {d} item(s)", .{fail_count});
        }
        
        try state.loadDirectory();
        
    } else if (std.mem.eql(u8, cmd, "comp")) {
        // Compile command: comp -auto <name1> [name2] ... or comp -auto -sel
        const first_arg = tokens.next() orelse {
            try state.logFmt("log error: comp command requires '-auto' flag", .{});
            return;
        };
        
        if (!std.mem.eql(u8, first_arg, "-auto")) {
            try state.logFmt("log error: comp command requires '-auto' flag", .{});
            return;
        }
        
        const second_arg = tokens.next();
        
        // Check for -sel flag
        if (second_arg) |arg| {
            if (std.mem.eql(u8, arg, "-sel")) {
                // Compile selected autos
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
                
                // Extract auto names from selected paths
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
                
                // Compile each auto
                var success_count: usize = 0;
                var fail_count: usize = 0;
                
                for (auto_names.items) |auto_name| {
                    try state.logFmt("log info: Compiling auto '{s}'...", .{auto_name});
                    renderTUI(vx, tty, state) catch {};
                    
                    const compile_result = auto_creator.compileAuto(state.alloc, auto_name, state.project_root) catch |err| {
                        const err_msg = switch (err) {
                            error.AutoNotFound => "Auto not found",
                            else => @errorName(err),
                        };
                        try state.logFmt("log error: Failed to compile auto '{s}': {s}", .{ auto_name, err_msg });
                        fail_count += 1;
                        continue;
                    };
                    
                    // Check if compilation failed (non-empty stderr indicates error)
                    if (compile_result.stderr.len > 0) {
                        // Log the actual zig error message
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
        
        // Compile specific autos by name: comp -auto NAME1 NAME2 ...
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
        
        // Compile each auto
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
            
            const compile_result = auto_creator.compileAuto(state.alloc, auto_name, state.project_root) catch |err| {
                const err_msg = switch (err) {
                    error.AutoNotFound => "Auto not found",
                    else => @errorName(err),
                };
                try state.logFmt("log error: Failed to compile auto '{s}': {s}", .{ auto_name, err_msg });
                fail_count += 1;
                continue;
            };
            
            // Check if compilation failed (non-empty stderr indicates error)
            if (compile_result.stderr.len > 0) {
                // Log the actual zig error message
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
        
    } else if (std.mem.eql(u8, cmd, "mv")) {
        const source = tokens.next() orelse {
            try state.logFmt("log error: mv command requires source and destination", .{});
            return;
        };
        
        // Handle bulk move of selected items
        if (std.mem.eql(u8, source, "-sel")) {
            const dest_path = tokens.next() orelse {
                try state.logFmt("log error: mv -sel requires a destination path", .{});
                return;
            };
            
            if (state.selected_paths.count() == 0) {
                try state.logFmt("log warn: No items selected", .{});
                return;
            }
            
            // Resolve destination path
            const dest_full = if (std.fs.path.isAbsolute(dest_path))
                try state.alloc.dupe(u8, dest_path)
            else
                try std.fs.path.join(state.alloc, &.{ state.cwd, dest_path });
            defer state.alloc.free(dest_full);
            
            // Check if destination is under usr/ root
            if (!std.mem.startsWith(u8, dest_full, state.root)) {
                try state.logFmt("log error: Destination must be under usr/", .{});
                return;
            }
            
            // Ensure destination directory exists
            std.fs.cwd().makePath(dest_full) catch |err| {
                try state.logFmt("log error: Failed to create destination directory '{s}': {s}", .{ dest_path, @errorName(err) });
                return;
            };
            
            var success_count: usize = 0;
            var fail_count: usize = 0;
            var selected_iter = state.selected_paths.iterator();
            
            while (selected_iter.next()) |entry| {
                const src_path = entry.key_ptr.*;
                
                // Check if we're trying to move usr/ root
                if (std.mem.eql(u8, src_path, state.root)) {
                    try state.logFmt("log error: Cannot move usr/ root", .{});
                    fail_count += 1;
                    continue;
                }
                
                // Check if path is under usr/ root
                if (!std.mem.startsWith(u8, src_path, state.root)) {
                    try state.logFmt("log error: Path '{s}' is not under usr/", .{src_path});
                    fail_count += 1;
                    continue;
                }
                
                // Get basename for destination
                const basename = std.fs.path.basename(src_path);
                const new_path = try std.fs.path.join(state.alloc, &.{ dest_full, basename });
                defer state.alloc.free(new_path);
                
                // Move the file/directory
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
            
            // Clear selections after operation
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
        
        // Single file/directory move (rename)
        const dest_name = tokens.next() orelse {
            try state.logFmt("log error: mv command requires source and destination", .{});
            return;
        };
        
        // Check if we're at root level - don't allow moving at usr/
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
        
    } else if (std.mem.eql(u8, cmd, "assemble")) {
        // Assemble engine: assemble <map_file.jsonc>
        const map_file = tokens.next() orelse {
            try state.logFmt("log error: assemble command requires a map file", .{});
            return;
        };
        
        // Resolve map file path - look in usr/map/
        const map_path = if (std.fs.path.isAbsolute(map_file))
            try state.alloc.dupe(u8, map_file)
        else
            try std.fs.path.join(state.alloc, &.{ state.project_root, "usr", "map", map_file });
        defer state.alloc.free(map_path);
        
        try state.logFmt("log info: Assembling engine for map file 'usr/map/{s}'", .{map_file});
        // Note: renderTUI will be called after this function returns
        
        const start = std.time.milliTimestamp();
        const engine = Engine.init(state.alloc, map_path) catch |err| {
            try state.logFmt("log error: Engine assembly failed: {s}", .{@errorName(err)});
            return;
        };
        const elapsed = std.time.milliTimestamp() - start;
        
        // Free old engine if exists
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
        
        // Switch to appropriate workspace based on execution mode
        if (engine.map.exec_mode == .Backtest) {
            state.current_workspace = 2;
            try state.logFmt("log info: Switched to Backtester workspace", .{});
        }
        renderTUI(vx, tty, state) catch {};
        
    } else if (std.mem.eql(u8, cmd, "engine")) {
        const subcmd = tokens.next() orelse {
            try state.logFmt("log error: engine command requires a subcommand (run)", .{});
            return;
        };
        
        if (std.mem.eql(u8, subcmd, "run")) {
            var engine = state.assembled_engine orelse {
                try state.logFmt("log error: No engine assembled. Use 'assemble <map>' first", .{});
                return;
            };
            
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
                // Set a failed execution result
                const failed_result = ExecutionResult{
                    .map_path = try state.alloc.dupe(u8, engine.map.auto),
                    .auto_name = try state.alloc.dupe(u8, std.mem.span(engine.auto.api.name)),
                    .auto_desc = try state.alloc.dupe(u8, std.mem.span(engine.auto.api.desc)),
                    .auto_path = try extractRelPath(state.alloc, engine.map.auto, state.project_root),
                    .exec_mode = try state.alloc.dupe(u8, "BACKTEST"),
                    .db_path = try extractRelPath(state.alloc, engine.map.db, state.project_root),
                    .feed_mode = try state.alloc.dupe(u8, "SQLite3"),
                    .table = try state.alloc.dupe(u8, engine.map.table),
                    .data_points = engine.track.size,
                    .trail_size = engine.map.trail_size,
                    .balance = engine.map.account.balance,
                    .output_dir = try state.alloc.dupe(u8, engine.out.abs_dir_path),
                    .output_orders_path = try state.alloc.dupe(u8, ""),
                    .output_fills_path = try state.alloc.dupe(u8, ""),
                    .output_positions_path = try state.alloc.dupe(u8, ""),
                    .init_time_ms = 0,
                    .exec_time_ms = 0,
                    .total_time_ms = std.time.milliTimestamp() - start_total,
                    .throughput = 0,
                    .success = false,
                };
                if (state.execution_result) |*old| {
                    state.alloc.free(old.map_path);
                    state.alloc.free(old.auto_name);
                    state.alloc.free(old.auto_desc);
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
                state.execution_result = failed_result;
                return;
            };
            const exec_time = std.time.milliTimestamp() - start_exec;
            
            try state.logFmt("log info: Strategy execution completed", .{});
            renderTUI(vx, tty, state) catch {};
            
            try state.logFmt("log info: Writing output files", .{});
            renderTUI(vx, tty, state) catch {};
            
            const output_dir = engine.out.abs_dir_path;
            const orders_path = try engine.out.filePath(state.alloc, "orders.csv");
            defer state.alloc.free(orders_path);
            const fills_path = try engine.out.filePath(state.alloc, "fills.csv");
            defer state.alloc.free(fills_path);
            const positions_path = try engine.out.filePath(state.alloc, "positions.csv");
            defer state.alloc.free(positions_path);
            
            const auto_name = try state.alloc.dupe(u8, std.mem.span(engine.auto.api.name));
            errdefer state.alloc.free(auto_name);
            const auto_desc = try state.alloc.dupe(u8, std.mem.span(engine.auto.api.desc));
            errdefer state.alloc.free(auto_desc);
            const auto_path = try extractRelPath(state.alloc, engine.map.auto, state.project_root);
            errdefer state.alloc.free(auto_path);
            
            const exec_mode = try state.alloc.dupe(u8, mode_str);
            errdefer state.alloc.free(exec_mode);
            
            const db_path = try extractRelPath(state.alloc, engine.map.db, state.project_root);
            errdefer state.alloc.free(db_path);
            
            const feed_str = switch (engine.map.feed_mode) {
                .Live => "LIVE",
                .SQLite3 => "SQLite3",
            };
            const feed_mode = try state.alloc.dupe(u8, feed_str);
            errdefer state.alloc.free(feed_mode);
            
            const table = try state.alloc.dupe(u8, engine.map.table);
            errdefer state.alloc.free(table);
            
            const output_dir_dup = try state.alloc.dupe(u8, output_dir);
            errdefer state.alloc.free(output_dir_dup);
            
            const orders_path_dup = try state.alloc.dupe(u8, orders_path);
            errdefer state.alloc.free(orders_path_dup);
            
            const fills_path_dup = try state.alloc.dupe(u8, fills_path);
            errdefer state.alloc.free(fills_path_dup);
            
            const positions_path_dup = try state.alloc.dupe(u8, positions_path);
            errdefer state.alloc.free(positions_path_dup);
            
            const map_path = try state.alloc.dupe(u8, engine.map.auto);
            errdefer state.alloc.free(map_path);
            
            const total_time = std.time.milliTimestamp() - start_total;
            const throughput = if (exec_time > 0) @as(f64, @floatFromInt(engine.track.size)) / (@as(f64, @floatFromInt(exec_time)) / 1000.0) else 0.0;
            
            const result = ExecutionResult{
                .map_path = map_path,
                .auto_name = auto_name,
                .auto_desc = auto_desc,
                .auto_path = auto_path,
                .exec_mode = exec_mode,
                .db_path = db_path,
                .feed_mode = feed_mode,
                .table = table,
                .data_points = engine.track.size,
                .trail_size = engine.map.trail_size,
                .balance = engine.map.account.balance,
                .output_dir = output_dir_dup,
                .output_orders_path = orders_path_dup,
                .output_fills_path = fills_path_dup,
                .output_positions_path = positions_path_dup,
                .init_time_ms = 0,
                .exec_time_ms = exec_time,
                .total_time_ms = total_time,
                .throughput = throughput,
                .success = true,
            };
            
            if (state.execution_result) |*old_result| {
                state.alloc.free(old_result.map_path);
                state.alloc.free(old_result.auto_name);
                state.alloc.free(old_result.auto_desc);
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
            state.execution_result = result;
            
            try state.logFmt("log comp: Execution completed in {d}ms", .{exec_time});
            try state.logFmt("log info: Output files written to {s}", .{output_dir});
            renderTUI(vx, tty, state) catch {};
        } else {
            try state.logFmt("log error: Unknown engine subcommand '{s}'. Use: engine run", .{subcmd});
        }
        
    } else {
        try state.logFmt("log error: Unknown command '{s}'. Use: touch, mkdir, rename, rm, mv, assemble, or engine", .{cmd});
    }
}

const Event = union(enum) {
    key_press: vaxis.Key,
    winsize: vaxis.Winsize,
};

pub fn run(gpa: std.mem.Allocator) !void {
    // Initialize TTY
    var tty_buf: [4096]u8 = undefined;
    var tty = try vaxis.Tty.init(&tty_buf);
    defer tty.deinit();

    var vx = try vaxis.init(gpa, .{});
    defer vx.deinit(gpa, tty.writer());

    // Event Loop
    var loop: vaxis.Loop(Event) = .{ .tty = &tty, .vaxis = &vx };
    try loop.init();
    try loop.start();
    defer loop.stop();

    try vx.enterAltScreen(tty.writer());
    try vx.queryTerminal(tty.writer(), 100 * std.time.ms_per_s);

    // Initialize state with usr/ directory
    const project_root = try path_util.getProjectRootPath(gpa);
    defer gpa.free(project_root);
    const usr_path = try std.fs.path.join(gpa, &.{ project_root, "usr" });
    defer gpa.free(usr_path);

    var state = try State.init(gpa, usr_path, project_root);
    defer state.deinit();

    // Startup initialization messages
    try state.logFmt("log info: ZORG TUI initialized successfully", .{});
    try state.logFmt("log info: Connected to terminal interface", .{});
    try state.logFmt("log info: Project root: {s}", .{project_root});
    try state.logFmt("log info: Starting directory: {s}", .{usr_path});
    
    // Verify file system access
    const cwd_test = std.fs.cwd();
    if (cwd_test.access(usr_path, .{})) |_| {
        try state.logFmt("log comp: File system access verified", .{});
    } else |err| {
        try state.logFmt("log warn: File system access check failed: {s}", .{@errorName(err)});
    }
    
    // Verify directory loading
    if (state.entries.items.len > 0) {
        try state.logFmt("log comp: Loaded {d} entries from starting directory", .{state.entries.items.len});
    } else {
        try state.logFmt("log warn: No entries found in starting directory", .{});
    }
    
    // Verify workspace system
    try state.logFmt("log info: Workspace system initialized (Main: Browser, Backtester: Backtest)", .{});
    try state.logFmt("log comp: All systems operational - ready for commands", .{});

    // Main loop
    while (true) {
        const event = loop.nextEvent();

        switch (event) {
            .key_press => |key| {
                // Workspace switching - ABSOLUTE FIRST PRIORITY
                // Direct codepoint check for maximum speed and reliability
                // Prompt mode handling - must be first to block all other keys (including workspace keys)
                if (state.prompt_mode) {
                    // Handle prompt mode keys
                    if (key.matches(vaxis.Key.escape, .{})) {
                        // Exit prompt mode and clear text
                        state.prompt_mode = false;
                        state.prompt_text.clearRetainingCapacity();
                    } else if (key.matches(vaxis.Key.enter, .{})) {
                        // Execute command from prompt
                        const command = state.prompt_text.items;
                        state.prompt_mode = false;
                        
                        if (command.len > 0) {
                            try executePromptCommand(&state, command, &vx, &tty);
                            // Render immediately after command execution
                            renderTUI(&vx, &tty, &state) catch {};
                        }
                        
                        state.prompt_text.clearRetainingCapacity();
                        // Don't continue - let it fall through to render immediately
                    } else if (key.matches(vaxis.Key.backspace, .{})) {
                        // Backspace in prompt
                        if (state.prompt_text.items.len > 0) {
                            _ = state.prompt_text.pop();
                        }
                        // Don't continue - let it fall through to render immediately
                    } else if (key.codepoint >= 32 and key.codepoint < 127) {
                        // Printable ASCII character (including numbers 0-9)
                        // This handles all printable characters including numbers, so workspace keys 1,2 are blocked
                        try state.prompt_text.append(state.alloc, @intCast(key.codepoint));
                        // Don't continue - let it fall through to render immediately
                    } else {
                        // Block all other keys - don't process navigation or other commands
                        continue;
                    }
                    // Fall through to render after handling prompt input
                }
                
                // Workspace switching (only when NOT in prompt mode)
                if (!state.prompt_mode) {
                    var is_workspace_key = false;
                    if (key.codepoint == '1') {
                        state.current_workspace = 1;
                        is_workspace_key = true;
                    } else if (key.codepoint == '2') {
                        state.current_workspace = 2;
                        is_workspace_key = true;
                    }

                    // If it was a workspace key, skip other handlers and go straight to render
                    if (!is_workspace_key) {
                        // Quit - works in all workspaces
                        if (key.matches('q', .{})) break;
                        if (key.matches('c', .{ .ctrl = true })) break;
                        
                        // Prompt mode handling - works in both workspaces
                        // Enter prompt mode with ':'
                        if (key.matches(':', .{})) {
                            state.prompt_mode = true;
                            state.prompt_text.clearRetainingCapacity();
                            // Render immediately - don't continue, fall through to render
                            try renderTUI(&vx, &tty, &state);
                            continue;
                        }
                        
                        // Only process other keys for workspace 1
                        if (state.current_workspace != 1) {
                            // Workspace 2 doesn't process navigation keys (except prompt and quit which are handled above)
                            continue;
                        }

                        // Selection with space (only when not in prompt mode)
                        if (key.matches(' ', .{})) {
                            if (state.entries.items.len > 0) {
                                // Check if we're at root level (usr/) - don't allow selection
                                const is_at_root = std.mem.eql(u8, state.cwd, state.root);
                                if (!is_at_root) {
                                    if (state.currentEntry()) |entry| {
                                        // Use path as key instead of index
                                        if (state.selected_paths.contains(entry.path)) {
                                            // Remove selection - free the path key
                                            if (state.selected_paths.fetchRemove(entry.path)) |kv| {
                                                state.alloc.free(kv.key);
                                            }
                                        } else {
                                            // Add selection - duplicate the path as key
                                            const path_key = try state.alloc.dupe(u8, entry.path);
                                            try state.selected_paths.put(path_key, {});
                                        }
                                    }
                                }
                            }
                            // Don't continue - let it fall through to render
                        }

                        // Handle all other keys normally (only for workspace 1)
                        if (key.matches('r', .{})) {
                            try runSelectedMap(&state, gpa, &loop, &vx, &tty);
                            continue;
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

                        // Navigate to root (usr/)
                        if (key.matches('c', .{})) {
                            state.alloc.free(state.cwd);
                            state.cwd = try state.alloc.dupe(u8, state.root);
                            try state.loadDirectory();
                        }

                        // Navigation
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

                        // Jump to top/bottom
                        if (key.matches('g', .{})) {
                            state.cursor = 0;
                        }
                        if (key.matches('G', .{})) {
                            if (state.entries.items.len > 0) {
                                state.cursor = state.entries.items.len - 1;
                            }
                        }

                        // Preview scrolling (Ctrl+j/k)
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

        // Render using renderTUI function
        try renderTUI(&vx, &tty, &state);
    }
}

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

// Removed buildCurrentAuto - use :comp -auto command instead

fn isAutoDir(path: []const u8) bool {
    return std.mem.indexOf(u8, path, "/usr/auto/") != null;
}

fn runSelectedMap(
    state: *State,
    gpa: std.mem.Allocator,
    loop: *vaxis.Loop(Event),
    vx: *vaxis.Vaxis,
    tty: *vaxis.Tty,
) !void {
    const entry = state.currentEntry() orelse {
        try state.setMessage("Select a map file");
        return;
    };

    if (entry.kind != .map) {
        try state.setMessage("Select a map file (.jsonc)");
        return;
    }

    const rel_path = state.relativePath(entry.path);
    try state.logFmt("log info: Starting backtest execution for map file '{s}'", .{rel_path});

    var pause = try PauseHandle.init(loop, vx, tty);
    defer pause.ensureRestored();

    const start = std.time.milliTimestamp();

    // Initialize engine
    const start_init = std.time.milliTimestamp();
    var engine = Engine.init(gpa, entry.path) catch |err| {
        try pause.restore();
        try state.logFmt("log error: Engine initialization failed for map '{s}': {s}", .{ rel_path, @errorName(err) });
        try state.setMessage("Engine initialization failed");
        return;
    };
    const elapsed_init = std.time.milliTimestamp() - start_init;
    defer engine.deinit();

    // Extract info
    const auto_name = try gpa.dupe(u8, std.mem.span(engine.auto.api.name));
    errdefer gpa.free(auto_name);
    const auto_desc = try gpa.dupe(u8, std.mem.span(engine.auto.api.desc));
    errdefer gpa.free(auto_desc);
    const auto_path = try extractRelPath(gpa, engine.map.auto, "zorg/");
    errdefer gpa.free(auto_path);

    const mode_str = switch (engine.map.exec_mode) {
        .LiveExecution => "LIVE",
        .Backtest => "BACKTEST",
        .Optimization => "OPTIMIZATION",
    };
    const exec_mode = try gpa.dupe(u8, mode_str);
    errdefer gpa.free(exec_mode);

    // Switch to workspace 2 for backtests
    if (engine.map.exec_mode == .Backtest) {
        state.current_workspace = 2;
    }

    const db_path = try extractRelPath(gpa, engine.map.db, "zorg/");
    errdefer gpa.free(db_path);

    const feed_str = switch (engine.map.feed_mode) {
        .Live => "LIVE",
        .SQLite3 => "SQLite3",
    };
    const feed_mode = try gpa.dupe(u8, feed_str);
    errdefer gpa.free(feed_mode);

    const table = try gpa.dupe(u8, engine.map.table);
    errdefer gpa.free(table);
    const output_dir = try gpa.dupe(u8, engine.map.output.OUTPUT_DIR_NAME);
    errdefer gpa.free(output_dir);
    const map_path = try gpa.dupe(u8, entry.path);
    errdefer gpa.free(map_path);

    // Execute
    const start_exec = std.time.milliTimestamp();
    engine.ExecuteProcess() catch |err| {
        try pause.restore();
        try state.logFmt("log error: Backtest execution failed for map '{s}': {s}", .{ rel_path, @errorName(err) });
        try state.setMessage("Backtest execution failed");

        // Store failed result
        const empty_path = try gpa.dupe(u8, "");
        errdefer gpa.free(empty_path);
        const result = ExecutionResult{
            .map_path = map_path,
            .auto_name = auto_name,
            .auto_desc = auto_desc,
            .auto_path = auto_path,
            .exec_mode = exec_mode,
            .db_path = db_path,
            .feed_mode = feed_mode,
            .table = table,
            .data_points = engine.track.size,
            .trail_size = engine.map.trail_size,
            .balance = engine.acc.balance,
            .output_dir = output_dir,
            .output_orders_path = empty_path,
            .output_fills_path = empty_path,
            .output_positions_path = empty_path,
            .init_time_ms = elapsed_init,
            .exec_time_ms = 0,
            .total_time_ms = std.time.milliTimestamp() - start,
            .throughput = 0,
            .success = false,
        };
        if (state.execution_result) |*old| {
            gpa.free(old.map_path);
            gpa.free(old.auto_name);
            gpa.free(old.auto_desc);
            gpa.free(old.auto_path);
            gpa.free(old.exec_mode);
            gpa.free(old.db_path);
            gpa.free(old.feed_mode);
            gpa.free(old.table);
            gpa.free(old.output_dir);
            gpa.free(old.output_orders_path);
            gpa.free(old.output_fills_path);
            gpa.free(old.output_positions_path);
        }
        state.execution_result = result;
        return;
    };
    const elapsed_exec = std.time.milliTimestamp() - start_exec;
    const elapsed_total = std.time.milliTimestamp() - start;

    // Calculate throughput
    const data_points = engine.track.size;
    const throughput: f64 = if (elapsed_exec > 0)
        @as(f64, @floatFromInt(data_points)) / (@as(f64, @floatFromInt(elapsed_exec)) / 1000.0)
    else
        0;

    // Get output file paths
    const output_orders_path = try engine.out.filePath(gpa, "orders.csv");
    errdefer gpa.free(output_orders_path);
    const output_fills_path = try engine.out.filePath(gpa, "fills.csv");
    errdefer gpa.free(output_fills_path);
    const output_positions_path = try engine.out.filePath(gpa, "positions.csv");
    errdefer gpa.free(output_positions_path);

    try pause.restore();

    // Store result
    const result = ExecutionResult{
        .map_path = map_path,
        .auto_name = auto_name,
        .auto_desc = auto_desc,
        .auto_path = auto_path,
        .exec_mode = exec_mode,
        .db_path = db_path,
        .feed_mode = feed_mode,
        .table = table,
        .data_points = data_points,
        .trail_size = engine.map.trail_size,
        .balance = engine.acc.balance,
        .output_dir = output_dir,
        .output_orders_path = output_orders_path,
        .output_fills_path = output_fills_path,
        .output_positions_path = output_positions_path,
        .init_time_ms = elapsed_init,
        .exec_time_ms = elapsed_exec,
        .total_time_ms = elapsed_total,
        .throughput = throughput,
        .success = true,
    };

    if (state.execution_result) |*old| {
        gpa.free(old.map_path);
        gpa.free(old.auto_name);
        gpa.free(old.auto_desc);
        gpa.free(old.auto_path);
        gpa.free(old.exec_mode);
        gpa.free(old.db_path);
        gpa.free(old.feed_mode);
        gpa.free(old.table);
        gpa.free(old.output_dir);
    }
    state.execution_result = result;

    try state.logFmt("log comp: Backtest execution completed successfully in {d}ms (init: {d}ms, exec: {d}ms, throughput: {d:.0} candles/sec)", .{ elapsed_total, elapsed_init, elapsed_exec, throughput });
    try state.setMessage("Backtest execution completed successfully");
}

fn extractRelPath(alloc: std.mem.Allocator, path: []const u8, marker: []const u8) ![]const u8 {
    if (std.mem.indexOf(u8, path, marker)) |idx| {
        const rel = path[idx..];
        if (rel.len > 0 and rel[0] == '/') {
            return try alloc.dupe(u8, rel[1..]);
        }
        return try alloc.dupe(u8, rel);
    }
    return try alloc.dupe(u8, path);
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

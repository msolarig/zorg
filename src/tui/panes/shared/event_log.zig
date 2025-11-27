const dep = @import("../../dep.zig");

const std = dep.Stdlib.std;

const vaxis = dep.External.vaxis;

const State = dep.Types.State;

const border = dep.Panes.Shared.border;

const render_util = dep.TUIUtils.render_util;
const format_util = dep.TUIUtils.format_util;

const Theme = struct {
    const fg_text = vaxis.Color{ .index = 255 }; // white
    const fg_time = vaxis.Color{ .index = 240 }; // very dark gray (timestamps)
    const fg_tag_info = vaxis.Color{ .index = 24 }; // very dark blue (info)
    const fg_tag_warning = vaxis.Color{ .index = 58 }; // very dark orange (warning)
    const fg_tag_success = vaxis.Color{ .index = 22 }; // very dark green (success)
    const fg_tag_error = vaxis.Color{ .index = 52 }; // very dark red (error)
    const fg_tag_comp = vaxis.Color{ .index = 22 }; // very dark green (comp)
};

pub fn render(win: vaxis.Window, state: *State) void {
    border.draw(win, "log");

    const content_h = if (win.height > 2) win.height - 2 else 0;
    if (content_h == 0) return;

    const logs = state.logsSlice();
    if (logs.len == 0) {
        render_util.printLine(win, 1, 1, "(no events)", .{ .fg = Theme.fg_time, .dim = true });
        return;
    }

    const start = if (logs.len > content_h) logs.len - content_h else 0;
    var row: usize = 0;
    
    for (logs[start..]) |log_entry| {
        // Use stored timestamp (fixed, not current time)
        const time_str = formatTimestamp(state, log_entry.timestamp) catch "00:00:00";
        
        // Parse log prefix to determine color
        const prefix_color = getPrefixColor(log_entry.message);
        
        // Find where the prefix ends (after ": ")
        var prefix_end: usize = 0;
        if (std.mem.indexOf(u8, log_entry.message, ": ")) |idx| {
            prefix_end = idx + 2;
        } else if (std.mem.indexOf(u8, log_entry.message, ":")) |idx| {
            prefix_end = idx + 1;
        } else {
            prefix_end = log_entry.message.len;
        }
        
        const prefix = if (prefix_end < log_entry.message.len) log_entry.message[0..prefix_end] else log_entry.message;
        const message = if (prefix_end < log_entry.message.len) log_entry.message[prefix_end..] else "";
        
        // Calculate available width (accounting for borders)
        const content_w = if (win.width > 2) win.width - 2 else 1;
        
        // Print timestamp in gray
        render_util.printLine(win, row + 1, 1, "[", .{ .fg = Theme.fg_time, .dim = true });
        render_util.printLine(win, row + 1, 2, time_str, .{ .fg = Theme.fg_time, .dim = true });
        render_util.printLine(win, row + 1, 2 + time_str.len, "] ", .{ .fg = Theme.fg_time, .dim = true });
        
        var col: usize = 4 + time_str.len;
        
        // Calculate remaining width for prefix and message
        const remaining_width = if (col < content_w) content_w - col else 0;
        
        // Print prefix with color coding (truncate if needed)
        const prefix_display = if (prefix.len > remaining_width) prefix[0..remaining_width] else prefix;
        render_util.printLine(win, row + 1, col, prefix_display, .{ .fg = prefix_color, .bold = true });
        col += prefix_display.len;
        
        // Print message (truncate if needed to fit in remaining width)
        if (message.len > 0) {
            const msg_remaining = if (col < content_w) content_w - col else 0;
            if (msg_remaining > 0) {
                const message_display = if (message.len > msg_remaining) message[0..msg_remaining] else message;
                render_util.printLine(win, row + 1, col, message_display, .{ .fg = Theme.fg_text });
            }
        }
        
        row += 1;
        if (row >= content_h) break;
    }
    
    // Show "... more" if there are older logs not visible
    if (start > 0 and content_h > 0) {
        const hidden = start;
        if (state.frameFmt("... +{d} older", .{hidden})) |more| {
            const content_w = if (win.width > 2) win.width - 2 else 1;
            const more_display = if (more.len > content_w) more[0..content_w] else more;
            if (row < content_h) {
                render_util.printLine(win, row + 1, 1, more_display, .{ .fg = Theme.fg_time, .dim = true });
            }
        } else |_| {}
    }
}

fn getPrefixColor(message: []const u8) vaxis.Color {
    if (std.mem.startsWith(u8, message, "log info:")) {
        return Theme.fg_tag_info;
    } else if (std.mem.startsWith(u8, message, "log warn:")) {
        return Theme.fg_tag_warning;
    } else if (std.mem.startsWith(u8, message, "log comp:")) {
        return Theme.fg_tag_comp;
    } else if (std.mem.startsWith(u8, message, "log error:")) {
        return Theme.fg_tag_error;
    }
    // Backward compatibility with old format
    if (std.mem.startsWith(u8, message, "Log Information:")) {
        return Theme.fg_tag_info;
    } else if (std.mem.startsWith(u8, message, "Log Warning:")) {
        return Theme.fg_tag_warning;
    } else if (std.mem.startsWith(u8, message, "Log Success:")) {
        return Theme.fg_tag_success;
    } else if (std.mem.startsWith(u8, message, "Log Error:")) {
        return Theme.fg_tag_error;
    }
    return Theme.fg_text; // Default color
}

fn formatTimestamp(state: *State, timestamp: i64) ![]const u8 {
    const epoch = std.time.epoch;
    const epoch_sec = epoch.EpochSeconds{ .secs = @intCast(timestamp) };
    const day_sec = epoch_sec.getDaySeconds();
    const hours = day_sec.getHoursIntoDay();
    const minutes = day_sec.getMinutesIntoHour();
    const seconds = day_sec.getSecondsIntoMinute();
    
    return state.frameFmt("{d:0>2}:{d:0>2}:{d:0>2}", .{ hours, minutes, seconds });
}



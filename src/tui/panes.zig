// Re-export all panes to reduce relative imports in app.zig
pub const border = @import("panes/shared/border.zig");
pub const footer = @import("panes/shared/footer.zig");
pub const header = @import("panes/shared/header.zig");

pub const FileList = @import("panes/ws1/file_list.zig");
pub const FilePreview = @import("panes/ws1/file_preview.zig");
pub const BinTree = @import("panes/ws1/bin_tree.zig");
pub const EventLog = @import("panes/ws1/event_log.zig");
pub const Shortcuts = @import("panes/ws1/shortcuts.zig");

pub const ConfigView = @import("panes/ws2/config_view.zig");
pub const Assembly = @import("panes/ws2/assembly.zig");
pub const Execution = @import("panes/ws2/execution.zig");
pub const Output = @import("panes/ws2/output.zig");


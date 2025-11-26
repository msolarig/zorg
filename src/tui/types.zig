// Re-export commonly used TUI types to reduce ../ imports
pub const State = @import("state.zig").State;
pub const EntryKind = @import("state.zig").EntryKind;
pub const Entry = @import("state.zig").Entry;
pub const ExecutionResult = @import("state.zig").ExecutionResult;
pub const LogEntry = @import("state.zig").LogEntry;


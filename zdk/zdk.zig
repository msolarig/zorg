//! ZDK (Zorg Development Kit) - Main entrypoint
//! 
//! This module provides access to all ZDK modules.
//! Import specific modules as needed, or use the namespace exports.

const version = @import("version");

/// Target Zorg version for ABI compatibility
/// Imported from unified version module
pub const ZDK_VERSION: u32 = version.TARGET_ZORG_VERSION;

// Index all modules
pub const types = @import("types.zig");
pub const abi = @import("abi.zig");
pub const commands = @import("commands.zig");
pub const io = @import("io.zig");
pub const order = @import("order.zig");
pub const log = @import("log.zig");
pub const time = @import("time.zig");

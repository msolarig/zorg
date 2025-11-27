const std = @import("std");
const tui = @import("tui/app.zig");

/// ============================================================================
/// ZORG VERSION SOURCE
/// ============================================================================
pub const ZORG_VERSION = "0.1.0";
/// ============================================================================

pub fn main() !void {
    var GPA = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = GPA.deinit();
    const gpa = GPA.allocator();

    try tui.run(gpa);
}

test {
    _ = @import("tests/tests.zig");
}

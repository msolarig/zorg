const std = @import("std");
const tui = @import("tui/app.zig");

pub fn main() !void {
    var GPA = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = GPA.deinit();
    const gpa = GPA.allocator();

    try tui.run(gpa);
}

test {
    _ = @import("tests/tests.zig");
}

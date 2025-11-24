const std = @import("std");
const cli = @import("ui/script.zig");
const tui = @import("ui/tui/app.zig");

pub fn main() !void {
    var GPA = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = GPA.deinit();
    const gpa = GPA.allocator();

    switch (isTuiMode()) {
        true => try tui.run(gpa),
        false => try cli.run(gpa),
    }
}

fn isTuiMode() bool {
    // Require at least one arg, compare with "--tui"
    return std.os.argv.len > 1 and
        std.mem.eql(u8, std.mem.span(std.os.argv[1]), "--tui");
}

test {
    _ = @import("test/engine_test.zig");
}

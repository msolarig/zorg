const std = @import("std");
const Engine = @import("../engine/engine.zig").Engine;

const Style = struct {
    pub const reset = "\x1b[0m";
    pub const bold = "\x1b[1m";
    pub const dim = "\x1b[2m";

    pub const title = "\x1b[31m";
    pub const accent = "\x1b[38;5;208m";
    pub const info = "\x1b[38;5;33m";
    pub const subtle = "\x1b[90m";
};

pub fn run(alloc: std.mem.Allocator) !void {
    var stdout_buffer: [1024]u8 = undefined;
    var stdout_writer = std.fs.File.stdout().writer(&stdout_buffer);
    const stdout = &stdout_writer.interface;

    var stdin_buffer: [1024]u8 = undefined;
    var stdin_reader = std.fs.File.stdin().reader(&stdin_buffer);
    const stdin = &stdin_reader.interface;

    try stdout.print("\x1b[2J\x1b[H", .{});
    try stdout.print(
        \\{s}┌─────────────────────────────────────────────────────────────┐{s}
        \\{s}│ {s}{s}Zorg{s}  {s}/ v1.0.0 in Active Development /{s}  {s}
        \\{s}└─────────────────────────────────────────────────────────────┘{s}
    , .{
        Style.subtle, Style.reset,
        Style.subtle, Style.subtle,
        Style.bold,   Style.reset,
        Style.dim,    Style.reset,
        Style.subtle, Style.subtle,
        Style.reset,
    });

    try stdout.print(
        "\n{s}{s}  ENGINE MAP{s} {s}› {s}",
        .{ Style.bold, Style.accent, Style.reset, Style.dim, Style.reset },
    );
    try stdout.flush();

    const engine_map = try stdin.takeDelimiterExclusive('\n');

    const start = std.time.milliTimestamp();

    const start_init = std.time.milliTimestamp();
    var engine = try Engine.init(alloc, engine_map);
    const elapsed_init = std.time.milliTimestamp() - start_init;

    defer engine.deinit();

    try stdout.print("\n{s}{s}  ENGINE ASSEMBLED{s}\n", .{ Style.bold, Style.accent, Style.reset });
    try stdout.print("{s}    exec:{s} {any}\n", .{ Style.info, Style.reset, engine.map.exec_mode });

    const auto_rel = engine.map.auto[std.mem.indexOf(u8, engine.map.auto, "zorg/").?..];
    try stdout.print("{s}    auto:{s} /{s}\n", .{ Style.info, Style.reset, auto_rel });

    const db_rel = engine.map.db[std.mem.indexOf(u8, engine.map.db, "zorg/").?..];
    try stdout.print("{s}    feed:{s} /{s}\n\n", .{ Style.info, Style.reset, db_rel });

    try stdout.flush();

    try stdout.print("{s}{s}  EXECUTING PROCESS…{s}\n", .{ Style.bold, Style.accent, Style.reset });
    try stdout.flush();

    const start_exec = std.time.milliTimestamp();
    try engine.ExecuteProcess();
    const elapsed_exec = std.time.milliTimestamp() - start_exec;

    const elapsed_total = std.time.milliTimestamp() - start;

    try stdout.print(
        "{s}{s}  DONE | EA:{d}ms | PE:{d}ms | TR:{d}ms | {s}\n\n",
        .{
            Style.bold,
            Style.subtle,
            elapsed_init,
            elapsed_exec,
            elapsed_total,
            Style.reset,
        },
    );
    try stdout.flush();
}

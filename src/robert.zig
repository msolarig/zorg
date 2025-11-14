const std = @import("std");
const header = @import("tui/header.zig");
const Engine = @import("engine/engine.zig").Engine;

const Style = struct {
  pub const reset = "\x1b[0m";
  pub const bold  = "\x1b[1m";
  pub const dim   = "\x1b[2m";

  pub const title  = "\x1b[31m";
  pub const accent = "\x1b[38;5;208m";
  pub const info   = "\x1b[38;5;33m";
  pub const subtle = "\x1b[90m";
};

pub fn main() !void {
  // Allocator
  var gpa = std.heap.GeneralPurposeAllocator(.{}){};
  defer _ = gpa.deinit();
  const alloc = gpa.allocator();

  // Writer
  var stdout_buffer: [1024]u8 = undefined;
  var stdout_writer = std.fs.File.stdout().writer(&stdout_buffer);
  const stdout = &stdout_writer.interface;

  // Reader
  var stdin_buffer: [1024]u8 = undefined;
  var stdin_reader = std.fs.File.stdin().reader(&stdin_buffer);
  const stdin = &stdin_reader.interface;

  //----------------------------------------------------------------------------------------------
  // ROBERT – Terminal User Interface
  //----------------------------------------------------------------------------------------------

  try stdout.print("\x1B[2J\x1B[H", .{});
  try header.printMenuHeader(stdout, Style);

  // Read map.json name
  try stdout.print(
    "\n{s}{s}  ENGINE MAP{s} {s}› {s}",
    .{ Style.bold, Style.accent, Style.reset, Style.dim, Style.reset },
  );
  try stdout.flush();
  const engine_map = try stdin.takeDelimiterExclusive('\n');

  // Initialize Engine (provide map.json)
  const start = std.time.milliTimestamp();
  var engine = try Engine.init(alloc, engine_map);
  const elapsed = std.time.milliTimestamp() - start;
  defer engine.deinit();
  
  // Display assembled Engine details
  try stdout.print("\n{s}{s}  ENGINE ASSEMBLED | {d}ms | {s}\n", 
                   .{ Style.bold, Style.accent, elapsed, Style.reset });
  try stdout.print("{s}    exec:{s} {any}\n", .{ Style.info, Style.reset, engine.map.exec_mode });
  const auto_relative_path = engine.map.auto[std.mem.indexOf(u8, engine.map.auto, "robert/").? ..];
  try stdout.print("{s}    auto:{s} /{s}\n", .{ Style.info, Style.reset, auto_relative_path});
  const db_realtive_path = engine.map.db[std.mem.indexOf(u8, engine.map.db, "robert/").? ..];
  try stdout.print("{s}    feed:{s} /{s}\n\n", .{ Style.info, Style.reset, db_realtive_path });
  try stdout.flush();

  // Call Engine execution
  try stdout.print("{s}{s}  EXECUTING PROCESS…{s}\n", .{ Style.bold, Style.accent, Style.reset });
  try stdout.flush();

  try engine.ExecuteProcess();

  try stdout.print("{s}{s}  DONE{s}\n\n", .{ Style.bold, Style.subtle, Style.reset });
  try stdout.flush();
}

test {
  _ = @import("test/track_test.zig");
}

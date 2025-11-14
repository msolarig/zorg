const std    = @import("std");
const Engine = @import("engine/engine.zig").Engine;

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

  //-----------------------------------------------------------------------------------------------
  // ROBERT Loop - Terminal User Interface
  //-----------------------------------------------------------------------------------------------

  try stdout.print("\x1B[2J\x1B[H", .{});
  try stdout.print("ROBERT! \nThe Robotic Execution & Research Terminal\n", .{});
  try stdout.print("————————————————————————————————————————————————————\n\n", .{});
  try stdout.flush();
  
  try stdout.print("Engine-Map File: ", .{});
  try stdout.flush();
  const engine_map = try stdin.takeDelimiterExclusive('\n');

  try stdout.print("\n\x1b[31mRUNTIME LOG:\n\x1b[0m", .{});
  try stdout.flush();

  var engine = try Engine.init(alloc, engine_map);
  defer engine.deinit();

  try stdout.print("\x1b[31mEngine Details:\n\x1b[0m", .{});
  try stdout.print("Loaded Auto Adress: {s}\n", .{engine.map.auto});
  try stdout.print("Loaded Feed Adress: {s}\n\n", .{engine.map.db});
  try stdout.flush();

  try engine.ExecuteProcess();
}

test {
    _ = @import("test/track_test.zig");
}

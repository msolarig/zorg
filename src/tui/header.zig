const std = @import("std");

pub fn printMenuHeader(stdout: anytype, Style: anytype) !void {
  try stdout.print(
    \\{s}┌─────────────────────────────────────────────────────────────┐{s}
    \\{s}│ {s}{s}ROBERT{s}  {s}/ Robotic Execution & Research Terminal /{s}  {s}
    \\{s}└─────────────────────────────────────────────────────────────┘{s}
    , .{
    Style.subtle, Style.reset,
    Style.subtle, Style.subtle, Style.bold, Style.reset, Style.dim, Style.reset, Style.subtle,
    Style.subtle, Style.reset,
  });
}

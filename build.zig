const std = @import("std");

pub fn build(b: *std.Build) void {
  const target = b.standardTargetOptions(.{});
  const optimize = b.standardOptimizeOption(.{});

  const exe = b.addExecutable(.{
    .name = "robert",
    .root_module = b.createModule(.{
      .root_source_file = b.path("src/robert.zig"),
      .target = target,
      .optimize = optimize,
      .imports = &.{}
    }),
  });
    
  // Link External Libraries ------------------------------
  exe.linkSystemLibrary("sqlite3");
  // ------------------------------------------------------

  b.installArtifact(exe);

  const run_step = b.step("run", "Run the app");

  const run_cmd = b.addRunArtifact(exe);
  run_step.dependOn(&run_cmd.step);

  run_cmd.step.dependOn(b.getInstallStep());

  if (b.args) |args| {
    run_cmd.addArgs(args);
  }

  // Unit Tests | Entry Point src/robert.zig --------------
  const test_step = b.step("test", "Run unit tests");

  const t = b.addTest(.{
    .name = "unit_tests",
    .root_module = b.createModule(.{
      .root_source_file = b.path("src/robert.zig"),
      .target = target,
      .optimize = optimize,
    }),
  });
  t.linkSystemLibrary("sqlite3");

  const run_t = b.addRunArtifact(t);
  run_t.cwd = b.path(".");

  test_step.dependOn(&run_t.step);
}

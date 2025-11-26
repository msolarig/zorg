const std = @import("std");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    const vaxis = b.dependency("vaxis", .{
        .target = target,
        .optimize = optimize,
    });

    const zdk_mod = b.createModule(.{
        .root_source_file = b.path("zdk/zdk.zig"),
        .target = target,
        .optimize = optimize,
    });

    const exe = b.addExecutable(.{
        .name = "zorg",
        .root_module = b.createModule(.{
            .root_source_file = b.path("src/zorg.zig"),
            .target = target,
            .optimize = optimize,
        }),
    });

    exe.root_module.addImport("vaxis", vaxis.module("vaxis"));
    exe.root_module.addImport("zdk", zdk_mod);
    exe.linkSystemLibrary("sqlite3");

    b.installArtifact(exe);

    const run_step = b.step("run", "Run the app");
    const run_cmd = b.addRunArtifact(exe);
    run_step.dependOn(&run_cmd.step);
    run_cmd.step.dependOn(b.getInstallStep());

    if (b.args) |args| {
        run_cmd.addArgs(args);
    }

    const test_step = b.step("test", "Run unit tests");

    const t = b.addTest(.{
        .name = "unit_tests",
        .root_module = b.createModule(.{
            .root_source_file = b.path("src/zorg.zig"),
            .target = target,
            .optimize = optimize,
        }),
    });

    t.root_module.addImport("zdk", zdk_mod);
    t.linkSystemLibrary("sqlite3");

    const run_t = b.addRunArtifact(t);
    run_t.cwd = b.path(".");

    test_step.dependOn(&run_t.step);

    // Create auto tool
    const create_auto_exe = b.addExecutable(.{
        .name = "create-auto",
        .root_module = b.createModule(.{
            .root_source_file = b.path("src/utils/create_auto.zig"),
            .target = target,
            .optimize = optimize,
        }),
    });

    create_auto_exe.root_module.addImport("path_utility", b.createModule(.{
        .root_source_file = b.path("src/utils/path_utility.zig"),
        .target = target,
        .optimize = optimize,
    }));
    create_auto_exe.root_module.addImport("auto_creator", b.createModule(.{
        .root_source_file = b.path("src/utils/auto_creator.zig"),
        .target = target,
        .optimize = optimize,
    }));

    b.installArtifact(create_auto_exe);

    const create_auto_step = b.step("create-auto", "Create a new auto");
    const create_auto_cmd = b.addRunArtifact(create_auto_exe);
    create_auto_step.dependOn(&create_auto_cmd.step);
    create_auto_cmd.step.dependOn(b.getInstallStep());
    
    // Pass all build args to create-auto (auto name, etc.)
    if (b.args) |args| {
        create_auto_cmd.addArgs(args);
    }
}

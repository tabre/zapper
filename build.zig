const std = @import("std");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});

    const optimize = b.standardOptimizeOption(.{});

    const zapper = b.createModule(.{
        .root_source_file = b.path("src/main.zig"),
        .target = target,
        .optimize = optimize,
    });

    const tooling = b.createModule(.{
        .root_source_file = b.path("src/tooling/zapper.zig"),
        .target = target,
        .optimize = optimize,
    });
        
    const zap = b.dependency("zap", .{
        .target = target,
        .optimize = optimize,
        .openssl = false,
    }); 
    zapper.addImport("zap", zap.module("zap"));
    tooling.addImport("zap", zap.module("zap"));

    const clap = b.dependency("clap", .{
        .target = target,
        .optimize = optimize,
    });
    tooling.addImport("clap", clap.module("clap"));

    const exe_zapper = b.addExecutable(.{
        .name = "zap-srv",
        .root_module = zapper,
    });

    const exe_tooling = b.addExecutable(.{
        .name = "zapper",
        .root_module = tooling
    });

    b.installArtifact(exe_zapper);

    const run_cmd_zapper = b.addRunArtifact(exe_zapper);
    const run_cmd_tooling = b.addRunArtifact(exe_tooling);

    run_cmd_zapper.step.dependOn(b.getInstallStep());
    run_cmd_tooling.step.dependOn(b.getInstallStep());

    if (b.args) |args| {
        run_cmd_zapper.addArgs(args);
        run_cmd_tooling.addArgs(args);
    }

    const run_step_zapper = b.step("run", "Run web server");
    run_step_zapper.dependOn(&run_cmd_zapper.step);
    
    const run_step_tooling = b.step("run-zapper", "Run zapper utility");
    run_step_tooling.dependOn(&run_cmd_tooling.step);

    // const exe_unit_tests = b.addTest(.{
    //     .root_module = exe_mod,
    // });

    // const run_exe_unit_tests = b.addRunArtifact(exe_unit_tests);

    // const test_step = b.step("test", "Run unit tests");
    // test_step.dependOn(&run_exe_unit_tests.step);
}

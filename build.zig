const std = @import("std");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});

    const optimize = b.standardOptimizeOption(.{});

    const zap_srv = b.createModule(.{
        .root_source_file = b.path("src/main.zig"),
        .target = target,
        .optimize = optimize,
    });

    const zapper = b.createModule(.{
        .root_source_file = b.path("src/tooling/zapper.zig"),
        .target = target,
        .optimize = optimize,
    });
        
    const zap = b.dependency("zap", .{
        .target = target,
        .optimize = optimize,
        .openssl = false,
    }); 
    zap_srv.addImport("zap", zap.module("zap"));
    zapper.addImport("zap", zap.module("zap"));

    const clap = b.dependency("clap", .{
        .target = target,
        .optimize = optimize,
    });
    zapper.addImport("clap", clap.module("clap"));

    const exe_zap_srv = b.addExecutable(.{
        .name = "zap-srv",
        .root_module = zap_srv,
    });
    b.installArtifact(exe_zap_srv);

    const exe_zapper = b.addExecutable(.{
        .name = "zapper",
        .root_module = zapper
    });
    b.installArtifact(exe_zapper);

    const run_cmd_zap_srv = b.addRunArtifact(exe_zap_srv);
    const run_cmd_zapper = b.addRunArtifact(exe_zapper);

    run_cmd_zap_srv.step.dependOn(b.getInstallStep());
    run_cmd_zapper.step.dependOn(b.getInstallStep());

    if (b.args) |args| {
        run_cmd_zap_srv.addArgs(args);
        run_cmd_zapper.addArgs(args);
    }
    
    const run_step_zap_srv = b.step("run", "Run Zap web server");
    run_step_zap_srv.dependOn(&run_cmd_zap_srv.step);

    const run_step_zapper= b.step("run-zapper", "Run zapper utility");
    run_step_zapper.dependOn(&run_cmd_zapper.step);

    // const exe_unit_tests = b.addTest(.{
    //     .root_module = exe_mod,
    // });

    // const run_exe_unit_tests = b.addRunArtifact(exe_unit_tests);

    // const test_step = b.step("test", "Run unit tests");
    // test_step.dependOn(&run_exe_unit_tests.step);
}

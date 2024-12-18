const std = @import("std");

pub fn build(b: *std.Build) void {
    //const optn_step = b.addOptions();
    //optn_step.addOption(bool, "build_wasm", false);
    var build_wasm_opt = false;
    if (b.option(bool, "build_wasm", "Build wasm module")) |val| {
        build_wasm_opt = val;
    }
    const target = if (build_wasm_opt) b.standardTargetOptions(
        .{
            .default_target = .{
                .cpu_arch = .wasm32,
                .os_tag = .macos,
            },
        },
    ) else b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    const raylib_dep = b.dependency("raylib_zig", .{
        .target = target,
        .optimize = optimize,
    });

    const raylib = raylib_dep.module("raylib"); // main raylib module
    const raygui = raylib_dep.module("raygui"); // raygui module
    const raylib_artifact = raylib_dep.artifact("raylib"); // raylib C library

    const lib = b.addStaticLibrary(.{
        .name = "znake-lib",
        .root_source_file = b.path("src/root.zig"),
        .target = target,
        .optimize = .ReleaseSmall,
    });
    const exe = b.addExecutable(.{
        .name = "znake",
        .root_source_file = b.path("src/main.zig"),
        .target = target,
        .optimize = optimize,
    });

    exe.linkLibrary(raylib_artifact);
    exe.root_module.addImport("raylib", raylib);
    exe.root_module.addImport("raygui", raygui);

    lib.linkLibrary(raylib_artifact);
    lib.root_module.addImport("raylib", raylib);
    lib.root_module.addImport("raygui", raygui);

    b.installArtifact(lib);

    b.installArtifact(exe);
    const run_cmd = b.addRunArtifact(exe);
    run_cmd.step.dependOn(b.getInstallStep());

    if (b.args) |args| {
        run_cmd.addArgs(args);
    }

    const run_step = b.step("run", "Run the app");
    run_step.dependOn(&run_cmd.step);

    const exe_unit_tests = b.addTest(.{
        .root_source_file = b.path("src/main.zig"),
        .target = target,
        .optimize = optimize,
    });

    exe_unit_tests.linkLibrary(raylib_artifact);
    exe_unit_tests.root_module.addImport("raylib", raylib);
    exe_unit_tests.root_module.addImport("raygui", raygui);

    const run_exe_unit_tests = b.addRunArtifact(exe_unit_tests);

    const test_step = b.step("test", "Run unit tests");
    test_step.dependOn(&run_exe_unit_tests.step);
}

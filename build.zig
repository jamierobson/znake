const std = @import("std");

pub const emcc = @import("emcc.zig");

pub fn build(b: *std.Build) void {
    //const optn_step = b.addOptions();
    //optn_step.addOption(bool, "build_wasm", false);
    var build_wasm_opt = false;
    if (b.option(bool, "build_wasm", "Build wasm module")) |val| {
        build_wasm_opt = val;
    }
    if (build_wasm_opt) {
        b.sysroot = "./thirdparty/emsdk/upstream/emscripten";
    }
    const target = if (build_wasm_opt) b.standardTargetOptions(
        .{
            .default_target = .{
                .cpu_arch = .wasm32,
                .os_tag = .emscripten,
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
    const raylib_artifact = raylib_dep.artifact("raylib"); // raylib C addStaticLibrary

    if (!build_wasm_opt) {
        const exe = b.addExecutable(.{
            .name = "znake",
            .root_source_file = b.path("src/main.zig"),
            .target = target,
            .optimize = optimize,
        });

        exe.linkLibrary(raylib_artifact);
        exe.root_module.addImport("raylib", raylib);
        exe.root_module.addImport("raygui", raygui);

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
    } else {
        const wasm_step = b.step("wasm", "Build wasm module");
        const wasm_lib = emcc.compileForEmscripten(b, "znake_wasm", "src/main.zig", target, .ReleaseSmall) catch |err| {
            std.log.err("Error compiling for emscripten: {} \n", .{err});
            return;
        };
        wasm_lib.linkLibrary(raylib_artifact);
        wasm_lib.root_module.addImport("raylib", raylib);
        wasm_lib.root_module.addImport("raygui", raygui);
        wasm_lib.entry = .{ .symbol_name = "_main" };
        wasm_lib.export_table = true;
        wasm_lib.initial_memory = 0x200000;
        wasm_lib.max_memory = 0x400000;
        wasm_lib.shared_memory = false;

        const link_step = emcc.linkWithEmscripten(b, &.{ wasm_lib, raylib_artifact }) catch |err| {
            std.log.err("Error linking with emscripten: {} \n", .{err});
            return;
        };

        //"-sALLOW_MEMORY_GROWTH=1",
        //"-sFORCE_FILESYSTEM=1",
        //"-sEXPORTED_RUNTIME_METHODS=ccall",
        //"-sEXPORTED_FUNCTIONS=[\"_free\",\"_malloc\",\"_main\"]",
        //"--preload-file Graphics",
        //"--preload-file Sounds",

        link_step.step.dependOn(&wasm_lib.step);
        link_step.addArg("-sALLOW_MEMORY_GROWTH=1");
        link_step.addArg("-sEXPORTED_RUNTIME_METHODS=ccall");
        link_step.addArg("-sERROR_ON_UNDEFINED_SYMBOLS=0");
        link_step.addArg("-sEXPORTED_FUNCTIONS=[\"_free\",\"_malloc\",\"_main\", \"_memcpy\"]");
        //link_step.addArg("--embed-file");
        //link_step.addArg("resources/");

        b.installArtifact(wasm_lib);

        const run_step = emcc.emscriptenRunStep(b) catch |err| {
            std.log.err("Error creating run step: {}\n", .{err});
            return;
        };
        run_step.step.dependOn(&link_step.step);
        const run_option = b.step("run", "Run the wasm module");

        run_option.dependOn(&run_step.step);
        wasm_step.dependOn(&wasm_lib.step);
    }
}

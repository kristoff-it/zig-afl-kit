const std = @import("std");

pub fn addInstrumentedExe(
    b: *std.Build,
    target: std.Build.ResolvedTarget,
    optimize: std.builtin.OptimizeMode,
    obj: *std.Build.Step.Compile,
) std.Build.LazyPath {
    const afl_kit = b.dependencyFromBuildZig(@This(), .{});

    // TODO: validate obj

    // std.debug.assert(obj.root_module.stack_check == false); // not linking with compiler-rt
    // std.debug.assert(obj.root_module.link_libc == true); // afl runtime depends on libc

    if (false) {
        const exe = b.addExecutable(.{
            .name = obj.name,
            .target = target,
            .optimize = optimize,
        });
        // exe.root_module.fuzz = false;
        exe.root_module.link_libc = true;
        exe.addCSourceFile(.{
            .file = afl_kit.path("afl.c"),
            .flags = &.{},
        });
        obj.root_module.fuzz = true;
        obj.root_module.link_libc = true;
        obj.sanitize_coverage_trace_pc_guard = true;
        exe.addObject(obj);

        // exe.addObject(afl_kit.path("afl-compiler-rt.o"));
        exe.addCSourceFile(.{
            .file = afl_kit.path("afl-compiler-rt.o"),
            .flags = &.{},
        });

        return exe;
    }
    const afl = afl_kit.builder.dependency("AFLplusplus", .{
        .target = target,
        .optimize = optimize,
    });

    const install_tools = b.addInstallDirectory(.{
        .source_dir = std.Build.LazyPath{
            .cwd_relative = afl.builder.install_path,
        },
        .install_dir = .prefix,
        .install_subdir = "AFLplusplus",
    });

    install_tools.step.dependOn(afl.builder.getInstallStep());
    _ = obj.getEmittedBin(); // hack around build system bug

    {
        const run_afl_cc = b.addSystemCommand(&.{
            b.pathJoin(&.{ afl.builder.exe_dir, "afl-cc" }),
            "-O3",
            "-o",
        });
        run_afl_cc.step.dependOn(&afl.builder.top_level_steps.get("llvm_exes").?.step);
        run_afl_cc.step.dependOn(&install_tools.step);
        const fuzz_exe = run_afl_cc.addOutputFileArg(obj.name);
        run_afl_cc.addFileArg(afl_kit.path("afl.c"));
        run_afl_cc.addFileArg(obj.getEmittedLlvmBc());
        return fuzz_exe;
    }
}

pub fn build(b: *std.Build) !void {
    _ = b;
    // const target = b.standardTargetOptions(.{});
    // const optimize = b.standardOptimizeOption(.{});

}

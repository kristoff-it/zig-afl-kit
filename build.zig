const std = @import("std");

pub fn addInstrumentedExe(b: *std.Build, obj: *std.Build.Step.Compile) std.Build.LazyPath {
    const afl_kit = b.dependencyFromBuildZig(@This(), .{});

    // TODO: validate obj

    std.debug.assert(obj.root_module.stack_check == false); // not linking with compiler-rt
    std.debug.assert(obj.root_module.link_libc == true); // afl runtime depends on libc

    _ = obj.getEmittedBin(); // hack around build system bug

    const use_own_afl = b.option([]const u8, "afl-path", "Path to existing build of AFLplusplus. We'll build it ourselves when this flag is not defined.");

    const run_afl_cc = if (use_own_afl) |afl_path| blk: {
        const afl_cc_path = b.findProgram(
            &.{ "afl-clang-fast", "afl-clang", "afl-cc" },
            &.{afl_path},
        ) catch "afl-clang-cc";

        break :blk b.addSystemCommand(&.{
            afl_cc_path,
            "-o",
        });
    } else blk: {
        const afl = afl_kit.builder.dependency("AFLplusplus", .{
            .optimize = .ReleaseFast,
        });

        const run = b.addSystemCommand(&.{
            b.pathJoin(&.{ afl.builder.exe_dir, "afl-cc" }),
            "-o",
        });
        run.step.dependOn(&afl.builder.top_level_steps.get("llvm_exes").?.step);

        if (b.option(
            bool,
            "tools",
            "Install AFL++ tools (default true)",
        ) orelse true) {
            const install_tools = b.addInstallDirectory(.{
                .source_dir = std.Build.LazyPath{
                    .cwd_relative = afl.builder.install_path,
                },
                .install_dir = .prefix,
                .install_subdir = "AFLplusplus",
            });

            install_tools.step.dependOn(afl.builder.getInstallStep());

            run.step.dependOn(&install_tools.step);
        }

        break :blk run;
    };

    const fuzz_exe = run_afl_cc.addOutputFileArg(obj.name);
    run_afl_cc.addFileArg(afl_kit.path("afl.c"));
    run_afl_cc.addFileArg(obj.getEmittedLlvmBc());
    return fuzz_exe;
}

pub fn build(b: *std.Build) !void {
    _ = b;
    // const target = b.standardTargetOptions(.{});
    // const optimize = b.standardOptimizeOption(.{});

}

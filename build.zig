const std = @import("std");

pub fn addInstrumentedExe(b: *std.Build, obj: *std.Build.Step.Compile) std.Build.LazyPath {
    const afl = b.dependencyFromBuildZig(@This(), .{});

    // TODO: validate obj

    std.debug.assert(obj.root_module.stack_check == false); // not linking with compiler-rt
    std.debug.assert(obj.root_module.link_libc == true); // afl runtime depends on libc

    _ = obj.getEmittedBin(); // hack around build system bug

    const afl_clang_fast_path = b.findProgram(
        &.{ "afl-clang-fast", "afl-clang" },
        if (b.option([]const u8, "afl-path", "Path to AFLplusplus")) |afl_path|
            &.{afl_path}
        else
            &.{},
    ) catch "afl-clang-fast";

    const run_afl_clang_fast = b.addSystemCommand(&.{
        afl_clang_fast_path,
        "-o",
    });

    const fuzz_exe = run_afl_clang_fast.addOutputFileArg(b.fmt("{s}-afl", .{
        obj.name,
    }));
    run_afl_clang_fast.addFileArg(afl.path("afl.c"));
    run_afl_clang_fast.addFileArg(obj.getEmittedLlvmBc());
    return fuzz_exe;
}

pub fn build(b: *std.Build) !void {
    _ = b;
    // const target = b.standardTargetOptions(.{});
    // const optimize = b.standardOptimizeOption(.{});

}

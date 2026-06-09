const std = @import("std");

pub fn addInstrumentedExe(
    b: *std.Build,
    target: std.Build.ResolvedTarget,
    optimize: std.builtin.OptimizeMode,
    /// Pass null if llvm-config is in PATH
    llvm_config_path: ?[]const []const u8,
    /// If true will search the path for afl++ instead of compiling from source.
    /// This is a workaround for issues with zig compiled afl++ and C++11 abi on ubuntu.
    use_system_afl: bool,
    obj: *std.Build.Step.Compile,
    /// Extra arguments to pass to the c++ compiler.
    extra_cc_args: []const []const u8,
) ?std.Build.LazyPath {
    const afl_kit = b.dependencyFromBuildZig(@This(), .{});

    if (!use_system_afl) @panic("feature regressed, use system afl");
    _ = target;
    _ = optimize;
    _ = llvm_config_path;

    // TODO: validate obj

    // std.debug.assert(obj.root_module.stack_check == false); // not linking with compiler-rt
    // std.debug.assert(obj.root_module.link_libc == true); // afl runtime depends on libc

    // if (!use_system_afl) {
    //     const afl = afl_kit.builder.lazyDependency("AFLplusplus", .{
    //         .target = target,
    //         .optimize = optimize,
    //         .@"llvm-config-path" = llvm_config_path orelse &[_][]const u8{},
    //     }) orelse return null;

    // const install_tools = b.addInstallDirectory(.{
    //     .source_dir = std.Build.LazyPath{
    //         .cwd_relative = afl.builder.install_path,
    //     },
    //     .install_dir = .prefix,
    //     .install_subdir = "AFLplusplus",
    // });

    // var afl_cc_install: ?*std.Build.Step.InstallArtifact = null;
    // for (afl_kit.builder.install_tls.step.dependencies.items) |dep_step| {
    //     const inst = dep_step.cast(std.Build.Step.InstallArtifact) orelse continue;
    //     const install_tool = b.addInstallArtifact(inst.artifact, .{
    //         .dest_sub_path = "AFLplusplus",
    //     });
    //     std.debug.print("ART = [{s}]\n", .{inst.artifact.name});
    //     if (std.mem.eql(u8, inst.artifact.name, "afl-cc")) {
    //         afl_cc_install = install_tool;
    //     }
    //     install_tool.step.dependOn(afl.builder.getInstallStep());
    // }

    // const run_afl_cc = b.addRunArtifact(afl_kit.artifact("afl-cc"));
    // run_afl_cc.step.dependOn(&afl_cc_install.?.step);

    // return aflCcArgs(run_afl_cc, afl_kit, obj, extra_cc_args);
    // } else {
    const run_afl_cc = b.addSystemCommand(&.{
        b.findProgram(.{ .names = &.{"afl-cc"} }) orelse @panic("Could not find 'afl-cc', which is required to build"),
        "-O3",
    });
    return aflCcArgs(run_afl_cc, afl_kit, obj, extra_cc_args);
    // }
}

fn aflCcArgs(
    run_afl_cc: anytype,
    afl_kit: *std.Build.Dependency,
    obj: *std.Build.Step.Compile,
    extra_cc_args: []const []const u8,
) std.Build.LazyPath {
    _ = obj.getEmittedBin(); // hack around build system bug
    run_afl_cc.addArgs(extra_cc_args);
    run_afl_cc.addArg("-o");
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

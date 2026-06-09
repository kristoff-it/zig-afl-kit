# zig-afl-kit

Convenience functions for easy integration with AFL++ for both Zig and
C/C++ programmers!

# Dependencies

Thanks to the amazing work done in
[allyourcodebase/AFLplusplus](https://github.com/allyourcodebase/AFLplusplus),
you don't even need to build the toolchain manually anymore. _You will need
LLVM though, we haven't packaged that yet sorry!_

This package is AFL++ specific so if you're just looking how to fuzz your
Zig executable, make sure to follow ziglang/zig#20702.

# Usage

## Add as a dependency

`zig fetch --save git+https://github.com/kristoff-it/zig-afl-kit`

**NOTE: no need to make it a lazy dependency, the package is very small and
the transitive dependency on AFLplusplus proper is already lazy and is only
pulled if you are not using a system-provided build of AFL.**

## Use it in your build.zig

Create an object file step with your test code (more on that later) and
pass it to `addInstrumentedExe`. While not mandatory, you will probably
want to create a dedicated named step, and you will also probably want to
install the instrumented executable.

```zig
// build.zig
const afl = @import("afl_kit");

// Define a step for generating fuzzing tooling:
const fuzz = b.step("fuzz", "Generate an instrumented executable for AFL++");

// Define an object file that contains your test function:
  const afl_obj = b.addObject(.{
    .name = "my_fuzz_obj",
    .root_module = b.createModule(.{
        .root_source_file = b.path("src/fuzz.zig"),
        .target = target,
        .optimize = .Debug,
    }),
});

// Required options:
afl_obj.root_module.stack_check = false; // not linking with compiler-rt
afl_obj.root_module.link_libc = true; // afl runtime depends on libc
afl_obj.root_module.fuzz = true;
afl_obj.sanitize_coverage_trace_pc_guard = true;


// Generate an instrumented executable:
const afl_fuzz = afl.addInstrumentedExe(b, target, optimize, null, true, afl_obj, &.{});

// Install it
fuzz.dependOn(&b.addInstallBinFile(afl_fuzz orelse return, "myfuzz-afl").step);
```

### Your test code

To create an instrumented executable, your object file must export two C symbols:

- `export fn zig_fuzz_init() void {}` invoked once to initialize resources (eg allocators)
- `export fn zig_fuzz_test(buf: [*]const u8, len: isize) void {}` invoked in a loop, containing the main test code, expected to not leave dirty state / leak memory across invocations.

This library integrates with AFL++ using:

- persistent mode (runs multiple tests on a single process, increases performance drammatically)
- shared memory (a shared memory buffer is used to get input from the fuzzer instead of reading from stdin)

See `afl.c` for more info.
See `example.zig` for an example of how to structure your test code.

## CLI arguments

`addInstrumentedExe` will define a `afl-path` option to allow you to point at a directory where you built AFL++, like so:

`zig build fuzz -Dafl-path="../AFLPlusplus"`

## I'm a C or C++ programmer, can I use this?

Of course, you can just set up your object file step to be compiled from C/C++ files!

Something along these lines:

```zig
const afl_obj = b.addObject(.{
    .name = "my_fuzz_obj",
    //.root_source_file = b.path("src/fuzz.zig"),
    .target = target,
    .optimize = .Debug,
});

afl_obj.addCSourceFiles(.{
    .files = &.{
        "foo.c",
        "bar.c",
    },
    // In case you need flags:
    //.flags = &.{"-Wextra", "-DFOO"},
});

// Required options:
afl_obj.root_module.stack_check = false; // not linking with compiler-rt
afl_obj.root_module.link_libc = true; // afl runtime depends on libc
afl_obj.root_module.fuzz = true;
afl_obj.sanitize_coverage_trace_pc_guard = true;

```

The Zig build system can also deal with all other kinds of C build requirements, see the official Zig standard library docs for more info.

## Fuzz your application

By default, your fuzz step (depending on the instrumented executable to me more precise) will also install the entire AFLplusplus toolchain.

```
zig-out
├─ bin
│   └── myfuzz-afl
└── AFLplusplus
    ├── bin
    │   ├── afl-analyze
    │   ├── afl-as
    │   ├── afl-cc
    │   ├── afl-compiler-rt-64
    │   ├── afl-compiler-rt.o
    │   ├── afl-fuzz
    │   ├── afl-gotcpu
    │   ├── afl-llvm-rt-lto-64
    │   ├── afl-llvm-rt-lto.o
    │   ├── afl-showmap
    │   └── afl-tmin
    └── lib
        └── <various afl++ dependencies>
```

If you don't want to build and install the full toolchain, set the `tools` option to `false` (`-Dtools=false`), this way `afl-cc` will be used directly from inside Zig's cache.

Create one or more example cases that execute successfully:

```bash
cd zig-out/AFLPlusPlus
mkdir cases
echo "good case" > cases/init.txt
```

Start fuzzing:
`./afl-fuzz -i cases -o output_dir ../../bin/myfuzz-afl`

Crashing inputs will be placed in `output_dir/default/crashes`.

Read the docs at https://aflplus.plus to learn more on how to use AFL++.

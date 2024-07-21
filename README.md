# zig-afl-kit
Convenience functions for easy integration with AFL++

# Dependencies
You need to have a build of AFL++ on your system, see https://aflplus.plus/ for more info.

Unless you know you need something different, you will want to build the `source-only` target (so `make source-only`), which will build only the tools for fuzzing programs that you have sources of.

Make sure to have successfully built "llvm mode" (aka `afl-clang-fast`).

Once https://github.com/allyourcodebase/AFLplusplus is able to build `afl-clang-fast` and `afl-clang-lto`, then you won't need to do this yourself anymore (but you will still need a build of LLVM, at least until that gets packaged for Zig aswell :^)).

# Usage

## Add as a dependency
`zig fetch --save git+https://github.com/kristoff-it/zig-afl-kit`

## Use it in your build.zig

Create an object file step with your test code (more on that later) and pass it to `addInstrumentedExe`. While not mandatory, you will probably want to create a dedicated named step, and you will also probably want to install the instrumented executable.

```zig
// build.zig
const afl = @import("zig-afl-kit");

// Define a step for generating fuzzing tooling:
const fuzz = b.step("fuzz", "Generate an instrumented executable for AFL++");

// Define an oblect file that contains your test function:
const afl_obj = b.addObject(.{
    .name = "my_fuzz_obj",
    .root_source_file = b.path("src/fuzz.zig"),
    .target = target,
    .optimize = .Debug,
});

// Required options:
afl_obj.root_module.stack_check = false; // not linking with compiler-rt
afl_obj.root_module.link_libc = true; // afl runtime depends on libc

//Add your code as a submodule:
//afl_obj.root_module.addImport("mylib", mylib);

// Generate an instrumented executable:
const afl_fuzz = afl.addInstrumentedExe(b, afl_obj);

// Install it
fuzz.dependOn(&b.addInstallBinFile(afl_fuzz, "myfuzz-afl").step);
```

### Your test code
To create an instrumented executable, your object file must export two C symbols: 
- `zig_fuzz_init` invoked once to initialize resources (eg allocators)
- `zig_fuzz_test` invoked in a loop, containing the main test code, expected to not leave dirty state / leak memory across invocations.

This library integrates with AFL++ using:
- persistent mode (runs multiple tests on a single process, increases performance drammatically)
- shared memory (a shared memory buffer is used to get input from the fuzzer instead of reading from stdin)

See `afl.c` for more info.
See `example.zig` for an example of how to structure your test code.

### **------> IMPORTANT <------**
For better fuzzing performance you will want to modify `std.mem.backend_can_use_eql_bytes` to return false, otherwise AFL++ will not be able to observe char-by-char string comparisons and its fuzzing capabilities will be greatly reduced.

*If you don't do this, you might aswell go back to writing unit tests like a bozo.*

This means modifying your copy of the Zig stdlib. If you have ZLS you can simply write `std.mem` anywhere in your code and goto definiton, otherwise you can invoke `zig env` and modify `$std_dir/mem.zig`.

**Also don't forget to revert this change after you're done!**
(ideally this will be streamlined in the near future)

## CLI arguments
`addInstrumentedExe` will define a `afl-path` option to allow you to point at a directory where you built AFL++, like so:

`zig build fuzz -Dafl-path="../AFLPlusplus"`

## Fuzz your application
Create one or more example cases that execute successfully:

```bash
cd AFLPlusPlus
mkdir cases
echo "good case" > cases/init.txt   
```

Start fuzzing:
`./afl-fuzz -i cases -o output_dir /path/to/myfuzz-afl`

Crashing inputs will be placed in `output_dir/default/crashes`.

Read the docs at https://aflplus.plus to learn more on how to use AFL++.

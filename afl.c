#include <limits.h>
#include <signal.h>
#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <unistd.h>
#ifdef __APPLE__
#include <mach-o/getsect.h>
#include <mach-o/ldsyms.h>
#endif
/* Main entry point. */

/* To ensure checks are not optimized out it is recommended to disable
   code optimization for the fuzzer harness main() */
#pragma clang optimize off
#pragma GCC optimize("O0")

// Zig integration
void zig_fuzz_init();
void zig_fuzz_test(unsigned char *, ssize_t);

#ifndef __APPLE__
// ELF (Linux): linker auto-generates __start_*/__stop_* section boundary
// symbols.
extern uint32_t __start___sancov_guards;
extern uint32_t __stop___sancov_guards;
#endif

void __sanitizer_cov_trace_pc_guard_init(uint32_t *, uint32_t *);

// Symbols not defined by afl-compiler-rt
__attribute__((visibility("default"))) __attribute__((
    tls_model("initial-exec"))) _Thread_local uintptr_t __sancov_lowest_stack;

void __sanitizer_cov_trace_pc_indir() {}
void __sanitizer_cov_8bit_counters_init() {}
void __sanitizer_cov_pcs_init() {}

//__AFL_FUZZ_INIT()
int __afl_sharedmem_fuzzing = 1;
extern __attribute__((visibility("default"))) unsigned int *__afl_fuzz_len;
extern __attribute__((visibility("default"))) unsigned char *__afl_fuzz_ptr;
unsigned char __afl_fuzz_alt[1048576];
unsigned char *__afl_fuzz_alt_ptr = __afl_fuzz_alt;

int main(int argc, char **argv) {
#ifdef __APPLE__
  // On macOS (Mach-O), use getsectiondata to find the __sancov_guards section
  // at runtime. The guards land in __DATA,__sancov_guards.
  unsigned long sancov_size = 0;
  uint32_t *sancov_start = (uint32_t *)getsectiondata(
      &_mh_execute_header, "__DATA", "__sancov_guards", &sancov_size);
  uint32_t *sancov_stop = sancov_start + sancov_size / sizeof(uint32_t);
  __sanitizer_cov_trace_pc_guard_init(sancov_start, sancov_stop);
#else
  __sanitizer_cov_trace_pc_guard_init(&__start___sancov_guards,
                                      &__stop___sancov_guards);
#endif

  // __AFL_INIT();
  static volatile const char *_A __attribute__((used, unused));
  _A = (const char *)"##SIG_AFL_DEFER_FORKSRV##";
#ifdef __APPLE__
  __attribute__((visibility("default"))) void _I(void) __asm__(
      "___afl_manual_init");
#else
  __attribute__((visibility("default"))) void _I(void) __asm__(
      "__afl_manual_init");
#endif
  _I();

  zig_fuzz_init();

  // unsigned char *buf = __AFL_FUZZ_TESTCASE_BUF;
  unsigned char *buf = __afl_fuzz_ptr ? __afl_fuzz_ptr : __afl_fuzz_alt_ptr;

  // while (__AFL_LOOP(UINT_MAX)) {
  while (({
    static volatile const char *_B __attribute__((used, unused));
    _B = (const char *)"##SIG_AFL_PERSISTENT##";
    extern __attribute__((visibility("default"))) int __afl_connected;
#ifdef __APPLE__
    __attribute__((visibility("default"))) int _L(unsigned int) __asm__(
        "___afl_persistent_loop");
#else 
      __attribute__((visibility("default"))) int _L(unsigned int) __asm__("__afl_persistent_loop");
#endif
    _L(__afl_connected ? UINT_MAX : 1);
  })) {

    // int len = __AFL_FUZZ_TESTCASE_LEN;
    int len =
        __afl_fuzz_ptr ? *__afl_fuzz_len
        : (*__afl_fuzz_len = read(0, __afl_fuzz_alt_ptr, 1048576)) == 0xffffffff
            ? 0
            : *__afl_fuzz_len;

    zig_fuzz_test(buf, len);
  }

  return 0;
}

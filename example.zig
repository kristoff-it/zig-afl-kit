const std = @import("std");

// Disable chatty logging
pub const std_options = .{ .log_level = .err };

// To allow AFL++ to observe branching char-by-char in
// string comparisons, edit your stdlib according to the
// following code (note that it's commented out because
// std.mem.backend_can_use_eql_bytes is actually private).
//
// Ideally in the future this is going to be easier to set.
//
// const toggle_me = std.mem.backend_can_use_eql_bytes;
// comptime {
//     std.debug.assert(toggle_me == false);
// }

// An example of how to initialize a GPA and an arena
// semi-statically.
var gpa_impl: std.heap.GeneralPurposeAllocator(.{}) = .{};
var arena_impl: std.heap.ArenaAllocator = .{
    .child_allocator = undefined,
    .state = .{},
};

export fn zig_fuzz_test(buf: [*]u8, len: isize) void {
    const gpa = gpa_impl.allocator();
    arena_impl.child_allocator = gpa;
    const arena = arena_impl.allocator();
    _ = arena_impl.reset(.retain_capacity);

    const src = buf[0..@intCast(len)];
    _ = src;

    // Your test code goes here.
}

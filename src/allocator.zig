const std = @import("std");
const sys = @import("system.zig");

var general_purpose_allocator = std.heap.GeneralPurposeAllocator(.{}){};
/// General Purpose Allocator is a catchall for maintaining memory beyond scope
pub const gpa = general_purpose_allocator.allocator();

/// Size of Fixed Buffer Allocator
pub const fixed_buffer_size = (1 << 12);
var fixed_buffer: [fixed_buffer_size]u8 = undefined;
var fixed_buffer_allocator = std.heap.FixedBufferAllocator.init(&fixed_buffer);

/// Fixed Buffer Allocator is for runtime-known sized buffers that do not need to live beyond scope
pub const fba = fixed_buffer_allocator.allocator();

var general_arena_allocator = std.heap.ArenaAllocator.init(gpa);
///Arena Allocator from General Purpose Allocator
pub const gpa_arena = general_arena_allocator.allocator();

var paged_arena_allocator = std.heap.ArenaAllocator.init(std.heap.page_allocator);
pub const paa = paged_arena_allocator.allocator();

var thread_safe_allocator: std.heap.ThreadSafeAllocator = .{
    .child_allocator = paa,
};
pub const tsa = thread_safe_allocator.allocator();

var threadsafe_fixed_buffer: [fixed_buffer_size]u8 = undefined;
var threadsafe_fixed_buffer_allocator =
    std.heap.FixedBufferAllocator.init(&threadsafe_fixed_buffer);
var threadsafe_fixed_buffer_allocator_but_for_real_this_time: std.heap.ThreadSafeAllocator =
    .{ .child_allocator = threadsafe_fixed_buffer_allocator.allocator() };
pub const tsf = threadsafe_fixed_buffer_allocator_but_for_real_this_time.allocator();

/// Dedicated allocator for loading mesh data, currently thread-safe generic
pub const mesh_allocator = tsa;

pub fn init() !void {}

pub fn deinit() void {
    general_arena_allocator.deinit();

    if (sys.DEBUG_MODE)
        _ = general_purpose_allocator.detectLeaks();
    _ = general_purpose_allocator.deinit();
    paged_arena_allocator.deinit();
}

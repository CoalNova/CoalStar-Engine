//! The threadmanager is responsible for the generation and destruction of threads, as well as
//! with the dissemination of thread tasks.
const std = @import("std");
const sys = @import("../system.zig");
const chr = @import("../system/chronosystem.zig");
const alc = @import("../allocator.zig");

pub const ThreadType = enum {
    resource,
    render,
    script,
    simulation,
};

pub var resource_thread: CoalStarThread = .{};
pub var render_thread: CoalStarThread = .{};
pub var script_thread: CoalStarThread = .{};
pub var simulation_thread: CoalStarThread = .{};

pub const ThreadState = enum { red, yellow, green, black };

const CoalStarThread = struct {
    clock: chr.Clock = .{},
    pid: std.Thread.Id = undefined,
    thread: std.Thread = undefined,
    alive: bool = false,
    queue: JobQueue = .{},
    state: ThreadState = .black,
    /// Initialization does not start the thread, it only enables resources
    pub fn init(self: *CoalStarThread, allocator: std.mem.Allocator, pool_size: u32) !void {
        self.state = .yellow;
        errdefer self.state = .red;
        try self.clock.init();
        try self.queue.init(allocator, pool_size);
    }
    pub fn deinit(self: *CoalStarThread) void {
        self.state = .yellow;
        defer self.state = .black;
        if (self.alive) {
            self.alive = false;
            self.thread.join();
        }
        self.queue.deinit();
    }
};

pub const Job = struct {
    task: *const fn (?u32) void,
    payload: ?u32 = null,
    relevant: bool = true,
};

/// Job Queue
/// Ring buffer for jobs to place, yoink, and process as able.
const JobQueue = struct {
    buffer: []?Job = undefined,
    start: usize = 0,
    end: usize = 0,
    lock: std.Thread.Mutex = .{},
    allocator: std.mem.Allocator = undefined,
    /// Initialize internal ring buffer
    pub fn init(self: *JobQueue, allocator: std.mem.Allocator, pool_size: u32) !void {
        self.lock.lock();
        defer self.lock.unlock();
        self.allocator = allocator;
        self.buffer = try allocator.alloc(?Job, pool_size);
        for (self.buffer) |*v| v.* = null;
    }
    pub fn deinit(self: *JobQueue) void {
        self.lock.lock();
        defer self.lock.unlock();
        self.allocator.free(self.buffer);
    }
    pub fn put(self: *JobQueue, job: Job) !void {
        self.lock.lock();
        defer self.lock.unlock();
        self.buffer[self.end] = job;
        self.end = (self.end + 1) % self.buffer.len;
        if (self.end == self.start) {
            std.log.err("Ring Buffer Saturated! Start:{}, End:{}", .{ self.start, self.end });
            if (sys.DEBUG_MODE)
                std.debug.panic("Ring Buffer Saturated! Start:{}, End:{}", .{ self.start, self.end });
        }
    }
    pub fn pop(self: *JobQueue) ?Job {
        self.lock.lock();
        defer self.lock.unlock();
        const job = self.buffer[self.start];
        if (job != null) {
            self.buffer[self.start] = null;
            self.start = (self.start + 1) % self.buffer.len;
        }
        return job;
    }
};

pub fn init() !void {
    try resource_thread.init(alc.gpa, 512);
    try render_thread.init(alc.gpa, 1024);
    try script_thread.init(alc.gpa, 256);
    try simulation_thread.init(alc.gpa, 16);
    sys.setStateOn(.thread);
}

pub fn deinit() void {
    if (sys.getState(.thread)) {
        resource_thread.deinit();
        render_thread.deinit();
        script_thread.deinit();
        simulation_thread.deinit();
        sys.setStateOff(.thread);
    } else if (sys.DEBUG_MODE) {
        std.log.err("Thread system attempted to deinit thread while state is off", .{});
    }
}

/// If system is in DEBUG_MODE,
/// Checks Processor ID of current thread context against what is expected
pub inline fn checkPID(thread_type: ThreadType) void {
    if (sys.DEBUG_MODE) {
        const current_id = std.Thread.getCurrentId();
        const thread_id = switch (thread_type) {
            .render => render_thread.pid,
            .resource => resource_thread.pid,
            .script => script_thread.pid,
            .simulation => simulation_thread.pid,
        };
        std.debug.assert(current_id == thread_id);
    }
}

/// Checks all threads for a "green light" status
pub inline fn getGreenLight() bool {
    return (resource_thread.state == .green and
        render_thread.state == .green and
        script_thread.state == .green and
        simulation_thread.state == .green);
}

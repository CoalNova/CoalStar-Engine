const std = @import("std");
const sys = @import("../system.zig");

// Shorthands
const Mutex = std.Thread.Mutex;
const Instant = std.time.Instant;

pub const ns_per_s = std.time.ns_per_s;
pub const ns_per_ms = std.time.ns_per_ms;
pub const ns_per_min = std.time.ns_per_min;
pub const ns_per_hour = std.time.ns_per_hour;

/// Will contain unique clocks for the separate threads, threads will need to compare against own
/// Separated to help avoid lock congestion
pub const Clock = struct {
    then: Instant = undefined,
    delta: f32 = 1.0,
    fps_then: Instant = undefined,
    fps_tick: u64 = 0,
    /// Initialize clocks collection, clock count should match number of used threads *including* main thread
    pub fn init(self: *Clock) !void {
        self.then = try Instant.now();
        self.fps_then = try Instant.now();
    }

    /// Frees used element storage
    pub fn deinit() void {
        // currently nothing?
    }

    /// Updates frame start time
    pub fn proc(self: *Clock) !void {
        self.fps_tick +|= 1;
        const now = try Instant.now();
        self.delta = @as(f32, @floatFromInt(now.since(self.then))) * 1e-9;
        self.then = now;
    }

    /// Time since frame logical update, with 1.0 as one second
    /// Requires thread number for isolation
    /// Note: inaccuracy coincides with Update() complexity/cost
    pub fn frameDelta(self: *Clock) f32 {
        return self.delta;
    }

    pub fn pollFPSCounter(self: *Clock, per_second_divisor: u64) !u64 {
        var fps: u64 = 0;
        const fps_cap = @as(u64, 1e9) / per_second_divisor;
        const fps_now = try Instant.now();
        const fps_delta = Instant.since(fps_now, self.fps_then);
        if (fps_delta > fps_cap) {
            self.fps_then = fps_now;
            fps = self.fps_tick;
            self.fps_tick = 0;
        }
        return fps;
    }

    pub fn since(self: Clock) !u64 {
        const now = try Instant.now();
        return now.since(self.then);
    }
};

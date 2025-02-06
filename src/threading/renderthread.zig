const std = @import("std");
const sys = @import("../system.zig");
const thm = @import("threadmanager.zig");
const ren = @import("../render/rendersystem.zig");
const tex = @import("../resource/texture.zig");
const uis = @import("../userinterface/uisystem.zig");

pub fn renderThreadLoop(
    render_options: ren.RenderOptions,
    allocator: std.mem.Allocator,
) void {
    _ = allocator;
    const self = &thm.render_thread;

    self.pid = std.Thread.getCurrentId();
    self.alive = true;

    ren.initGL(render_options) catch |err|
        return std.log.err("GL initialization failure! {!}", .{err});
    defer ren.deinitGL();
    std.log.info("GL System initialized.", .{});

    uis.init() catch |err|
        return std.log.err("Texture Stack initialization failure! {!}", .{err});
    defer uis.deinit();
    std.log.info("UI System initialized.", .{});

    var then: std.time.Instant = std.time.Instant.now() catch unreachable;

    while (self.alive) {
        // first run through queue
        while (self.queue.pop()) |job|
            job.task(job.payload);

        // update clock
        self.clock.proc() catch unreachable;

        // render
        ren.rend();

        //std.Thread.yield() catch unreachable;
        const now = std.time.Instant.now() catch unreachable;
        if (now.since(then) > std.time.ns_per_s) {
            std.debug.print(
                "FPS: {d}\r",
                .{self.clock.pollFPSCounter(std.time.ns_per_s) catch 0},
            );
            then = now;
        }
    }
}

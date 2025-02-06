//! The main insertion point for the program. This area is left empty for testing concepts and
//! experimentation. All code within the main loop should be removed or placed into appropriate
//! component before production.
const std = @import("std");
const sys = @import("system.zig");
const gme = @import("game.zig");
const evt = @import("event.zig");
const thm = @import("threading/threadmanager.zig");
const ren = @import("render/rendersystem.zig");
const chr = @import("system/chronosystem.zig");
const cfg = @import("system/configuration.zig");

/// Main insertion point
pub fn main() !void {
    // initializes the everything
    try sys.init();
    // deinitializes everything that was initialized
    defer sys.deinit();

    // verifies threads are properly engaged before continuing
    while (thm.getGreenLight()) {
        // checks for thread start failure by way of lagging
        // fails out if so
        if (try sys.sys_clock.since() > 30 * chr.ns_per_s) {
            std.log.err("Threads took longer than 30 seconds to reach green status, closing", .{});
            sys.setStateOff(.alive);
            return error.ThreadWarmup;
        }
    }

    //load game data
    try gme.init();
    defer gme.deinit();

    // main loop
    while (try sys.proc()) {
        // quit if 'escape' key is pressed
        if (evt.getInputDown(.{ .input_id = @intFromEnum(evt.Scancode.escape) }))
            sys.setStateOff(.alive);

        // toggle wireframe
        if (evt.getInputDown(.{ .input_id = @intFromEnum(evt.Scancode.space) }))
            try thm.render_thread.queue.put(thm.Job{ .task = ren.toggleWireFrame });
    }
}

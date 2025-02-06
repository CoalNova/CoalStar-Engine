//! System contains engine initialization and deinitialization calls.
//!
const builtin = @import("builtin");
/// This flag indicates if the engine is being built in either Debug or ReleaseSafe modes.
/// It should only be used for debugging and exhaustive/expensive error checking purposes.
pub const DEBUG_MODE = (builtin.mode == .Debug or builtin.mode == .ReleaseSafe);
const std = @import("std");
const sdl = @import("zsdl");
const zmt = @import("zmath");
const msh = @import("resource/mesh.zig");
const mat = @import("resource/material.zig");
const shd = @import("resource/shader.zig");
const tex = @import("resource/texture.zig");
const alc = @import("allocator.zig");
const wnd = @import("window.zig");
const evt = @import("event.zig");
const thm = @import("threading/threadmanager.zig");
const phy = @import("system/physics.zig");
const chr = @import("system/chronosystem.zig");
const aud = @import("system/audio.zig");
const lua = @import("system/scripting.zig");
const uis = @import("userinterface/uisystem.zig");
const ren = @import("render/rendersystem.zig");
const arg = @import("system/args.zig");

/// Public variable
pub var sys_clock: chr.Clock = undefined;
pub var main_pid: std.Thread.Id = undefined;

/// Engine States, each flag is a bit array entry for state.
/// Some Engine states dictate what processes are executed.
pub const EngineState = enum(u16) {
    /// The flag that maintains active engine state
    alive = 0b0000_0000_0000_0001,
    /// The flag for the SDL events system being initialized
    events = 0b0000_0000_0000_0010,
    /// The flag for the OpenGL context being set
    render = 0b0000_0000_0000_0100,
    /// The flag for the LUA script impl being initialized
    script = 0b0000_0000_0000_1000,
    /// The flag for the loading of the Jolt physics system
    physics = 0b0000_0000_0001_0000,
    /// The flag for the thread workers being loaded
    thread = 0b0000_0000_0010_0000,
    /// The flag for the simulation state
    simulation = 0b0000_0000_0100_0000,
    /// The flag for Audio processing
    audio = 0b0000_0000_1000_0000,
    /// The flag for the minimum viable loading state
    mv_loaded = 0b0000_0001_0000_0000,
    /// The flag to indicate whether the engine is in a "heavy loading" state
    loading = 0b0000_0010_0000_0000,
    /// The flag indicating the game is in a playing state,
    playing = 0b0000_0100_0000_0000,
};

/// Engine State
var state: u16 = 0;

/// Set an engine state as true, or 'on'
pub inline fn setStateOn(new_state: EngineState) void {
    state |= @intFromEnum(new_state);
}

/// Set an engine state as false, or 'off'
pub inline fn setStateOff(new_state: EngineState) void {
    if (getState(new_state))
        state ^= @intFromEnum(new_state);
}

/// Returns state boolean for provided state
pub inline fn getState(new_state: EngineState) bool {
    return (state & @intFromEnum(new_state) > 0);
}

/// Initialize Engine in totality
pub fn init() !void {
    if (DEBUG_MODE)
        main_pid = std.Thread.getCurrentId();

    // perform anu initialization of memory
    try alc.init();
    std.log.info("Allocation System initialized successfully.", .{});

    // initialize asset containers
    try msh.init(alc.gpa);
    try mat.init(alc.gpa);
    try shd.init(alc.gpa);
    std.log.info("Resources initialized successfully.", .{});

    // initialize thread backends
    try thm.init();
    std.log.info("Thread manager successfully initialized.", .{});

    // initialize (z)sdl and create window
    try sdl.init(sdl.InitFlags.everything);
    std.log.info("SDL initialized successfully.", .{});
    setStateOn(EngineState.events);

    try wnd.init(1, .{ .title = "Coalstar" });
    std.log.info("Window initialized successfully.", .{});

    // initialize physics
    try phy.init();
    std.log.info("Physics engine initialized successfully.", .{});

    try sys_clock.init();
    std.log.info("Frame timer initialized.", .{});

    try aud.init();
    std.log.info("Audio system initialized successfully.", .{});

    try lua.init();
    std.log.info("Scripting system initialized successfully.", .{});

    // initialize render thread
    try ren.init(.{}, alc.gpa);

    // set engine flags to everything we need
    setStateOn(EngineState.alive);
}

/// Deinitialize Engine
pub fn deinit() void {
    if (getState(.thread))
        thm.deinit();

    if (getState(.audio))
        aud.deinit();

    if (getState(.script))
        lua.deinit();

    if (getState(.physics))
        phy.deinit();

    if (getState(.render))
        ren.deinit();

    wnd.deinit();

    if (getState(.events)) {
        sdl.quit();
        setStateOff(.events);
    }

    if (DEBUG_MODE) {
        msh.deinit();
        mat.deinit();
        shd.deinit();

        alc.deinit();
    }
}

/// Run a single main loop frame, returns engine alive flag
pub fn proc() !bool {

    //set from events
    if (getState(EngineState.events))
        try evt.processEvents();

    //update clock
    try sys_clock.proc();

    //run all scripts
    try lua.proc();

    //sdl.delay(1);
    return getState(EngineState.alive);
}

//! The render system contains all of the rendering code required by the render_thread.
const std = @import("std");
const zopengl = @import("zopengl");
pub const zgl = zopengl.bindings;
const sdl = @import("zsdl");
const sys = @import("../system.zig");
const thr = @import("../threading/threadmanager.zig");
const rth = @import("../threading/renderthread.zig");
const cam = @import("../camera.zig");
const euc = @import("../euclid.zig");
const prp = @import("../worldspace/prop.zig");
const wnd = @import("../window.zig");
const uis = @import("../userinterface/uisystem.zig");
const msh = @import("../resource/mesh.zig");
const shd = @import("../resource/shader.zig");
const mat = @import("../resource/material.zig");
const alc = @import("../allocator.zig");
const rsc = @import("../resource/resourcecollection.zig");

// Name declarations for clarification
/// Texture name
pub const GLTexName = u32;
/// Texture pixel format
pub const GLFmt = u32;
/// Texture compression/pixel type
pub const GLFmtType = u32;
/// Texture Format Set
pub const GLFmtSet = u32;
/// Catchall GL Type
pub const GLType = u32;

pub const RenderOptions = struct {
    major_version: u32 = 3,
    minor_version: u32 = 3,
    poly_mode: enum { fill, line, point } = .fill,
    v_sync: enum { none, single, double, triple } = .single,
    t_blend: bool = true,
    culling: enum { none, front, back } = .back,
    z_depth: enum { none, front, back } = .back,
};

pub const PropBind = struct {
    euclid: euc.Euclid,
    prop: *prp.Prop,
};

pub const RenderBuffer = struct {
    cam_data: cam.Camera,
    prop_binds: [2048]?PropBind = [_]?PropBind{null} ** 2048,
};

/// The currently sent render states to the GPU
/// Used to reduce unnecessary API calls which do not change state
/// Could go very wrong.
pub const AssumedGPUStates = struct {
    program: ?u32 = null,
    vbo: ?u32 = null,
    vao: ?u32 = null,
    context: ?sdl.gl.Context = null,
};

/// This is the maximum size of a texture array
pub var max_tex_array_layers: i32 = 0;
/// This is the number of binding points available
pub var max_tex_binding_points: i32 = 0;
/// The current GPU states
pub var assumed_gpu_states: AssumedGPUStates = .{};

/// Returns if GL has had an error operation.
/// The error state only clears after checking, so may not be connected to prior operation.
/// This only calls during DEBUG in RELEASESAFE builds, and will not function outside to save system resources.
pub fn checkGLError(gl_op_description: []const u8) void {
    if (sys.DEBUG_MODE) {
        thr.checkPID(.render);
        const gl_err = zgl.getError();
        if (gl_err > 0) {
            std.log.err("GL operation: {s}, error: {s} - [0x{x}]", .{
                gl_op_description,
                getGLErrorString(gl_err),
                gl_err,
            });
        }
    }
}

/// Resolves GLerror Enums to legible string equivalents
pub inline fn getGLErrorString(gl_error_enum_value: u32) []const u8 {
    switch (gl_error_enum_value) {
        0x0500 => {
            return "Invalid Enum";
        },
        0x0501 => {
            return "Invalid Value";
        },
        0x0502 => {
            return "Invalid Operation";
        },
        0x0503 => {
            return "Stack Overflow";
        },
        0x0504 => {
            return "Stack Underflow";
        },
        0x0505 => {
            return "OOM!";
        },
        0x0506 => {
            return "Invalid Framebuffer Operation";
        },
        0x0507 => {
            return "GL_INVALID_ENUM";
        },
        0x8031 => {
            return "Table Too Large";
        },
        else => {
            return "No associated GL Enum?";
        },
    }
    unreachable;
}

pub fn init(
    render_options: RenderOptions,
    allocator: std.mem.Allocator,
) !void {
    thr.render_thread.thread = try std.Thread.spawn(
        .{},
        rth.renderThreadLoop,
        .{ render_options, allocator },
    );
}

pub fn initGL(render_options: RenderOptions) !void {
    const windows = wnd.getWindows();

    // create a gl context for the window
    try sdl.gl.setAttribute(sdl.gl.Attr.context_profile_mask, @intFromEnum(sdl.gl.Profile.core));
    try sdl.gl.setAttribute(sdl.gl.Attr.context_major_version, @intCast(render_options.major_version));
    try sdl.gl.setAttribute(sdl.gl.Attr.context_minor_version, @intCast(render_options.minor_version));
    const context = try sdl.gl.createContext(windows[0].sdl_window);

    // if fails, destroy it
    errdefer (sdl.gl.deleteContext(context));
    std.log.info("GL context created successfully", .{});

    // also make context current
    try sdl.gl.makeCurrent(windows[0].sdl_window, context);
    assumed_gpu_states.context = context;

    // if GL has not been initialized then do so
    // required after context creation as GL needs an active context to initialize
    // it's actually worse than this, but don't question it for your own sanity's sake
    if (!sys.getState(sys.EngineState.render)) {
        try zopengl.loadCoreProfile(
            sdl.gl.getProcAddress,
            render_options.major_version,
            render_options.minor_version,
        );

        switch (render_options.poly_mode) {
            .fill => zgl.polygonMode(zgl.FRONT_AND_BACK, zgl.FILL),
            .line => zgl.polygonMode(zgl.FRONT_AND_BACK, zgl.LINE),
            .point => zgl.polygonMode(zgl.FRONT_AND_BACK, zgl.POINT),
        }

        switch (render_options.culling) {
            .none => {},
            .front => {
                zgl.enable(zgl.CULL_FACE);
                zgl.cullFace(zgl.FRONT);
            },
            .back => {
                zgl.enable(zgl.CULL_FACE);
                zgl.cullFace(zgl.BACK);
            },
        }
        switch (render_options.z_depth) {
            .none => {},
            .back => {
                zgl.enable(zgl.DEPTH_TEST);
                zgl.depthFunc(zgl.LESS);
            },
            .front => {
                zgl.enable(zgl.DEPTH_TEST);
                zgl.depthFunc(zgl.GREATER);
            },
        }

        if (render_options.t_blend) {
            zgl.enable(zgl.BLEND);
            zgl.blendFunc(zgl.SRC_ALPHA, zgl.ONE_MINUS_SRC_ALPHA);
        }

        zgl.clearColor(0.1, 0.11, 0.22, 1.0);

        zgl.getIntegerv(zgl.MAX_ARRAY_TEXTURE_LAYERS, &max_tex_array_layers);
        std.log.info("Max Texture Array Layer Depth: {}", .{max_tex_array_layers});
        zgl.getIntegerv(zgl.MAX_TEXTURE_IMAGE_UNITS, &max_tex_binding_points);
        std.log.info("Max Texture Binding Points: {}", .{max_tex_binding_points});

        for (windows) |*w|
            w.gl_context = context;

        sys.setStateOn(sys.EngineState.render);
    }

    const swap_interval: u8 = switch (render_options.v_sync) {
        .none => 0,
        .single => 1,
        .double => 2,
        .triple => 3,
    };
    try sdl.gl.setSwapInterval(swap_interval);
}

pub fn deinit() void {}

pub fn deinitGL() void {
    const windows = wnd.getWindows();

    if (windows[0].gl_context) |context| {
        for (windows) |*w|
            w.gl_context = null;

        sdl.gl.deleteContext(context);
    }
    sys.setStateOff(sys.EngineState.render);
}

pub fn proc() void {}

pub fn rend() void {
    // per window
    for (wnd.windows) |*window| {

        // update window data
        window.proc();

        //set context
        if (window.gl_context) |context|
            sdl.gl.makeCurrent(window.sdl_window, context) catch unreachable;

        // clear
        clear();

        // render UI
        uis.rend();

        // render dynamics
        // TODO determine where the dynamics live

        // render statics
        // TODO determine where the statics live

        // render terrain

        // render LODWorld

        // swap
        swap(window);
    }
}

inline fn clear() void {
    zgl.clear(zgl.DEPTH_BUFFER_BIT | zgl.COLOR_BUFFER_BIT);
}

inline fn swap(window: *wnd.Window) void {
    sdl.gl.swapWindow(window.sdl_window);
}

/// Toggles Wireframe rendering state
pub fn toggleWireFrame(_: ?u32) void {
    const toggle_state = struct {
        var wire: bool = false;
    };

    toggle_state.wire = !toggle_state.wire;
    if (toggle_state.wire)
        zgl.polygonMode(zgl.FRONT_AND_BACK, zgl.LINE) //LINE
    else
        zgl.polygonMode(zgl.FRONT_AND_BACK, zgl.FILL); //FILL

}

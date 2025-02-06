const std = @import("std");
const sdl = @import("zsdl");
const zmt = @import("zmath");
const cam = @import("camera.zig");
const mse = @import("mouse.zig");
const alc = @import("allocator.zig");

pub var windows: []Window = undefined;

pub const Window = struct {
    sdl_window: *sdl.Window,
    gl_context: ?sdl.gl.Context = null,
    bounds: @Vector(4, i32) = undefined,
    camera: cam.Camera = .{},
    mouse: mse.Mouse = .{},

    pub fn proc(self: *Window) void {
        sdl.Window.getPosition(
            self.sdl_window,
            &self.bounds[0],
            &self.bounds[1],
        ) catch unreachable;
        sdl.Window.getSize(
            self.sdl_window,
            &self.bounds[2],
            &self.bounds[3],
        ) catch unreachable;
        self.mouse.procMouse(self.*);
    }
};

const WindowOptions = struct {
    title: [:0]const u8 = undefined,
    x: i32 = 320,
    y: i32 = 240,
    w: i32 = 640,
    h: i32 = 480,
    flags: sdl.Window.Flags = .{
        .opengl = true,
        .resizable = true,
    },
};

fn create(options: WindowOptions) !Window {
    return .{
        .sdl_window = try sdl.Window.create(
            options.title,
            options.x,
            options.y,
            options.w,
            options.h,
            options.flags,
        ),
    };
}

fn destroy(window: *Window) void {
    if (window.sdl_render) |*renderer|
        sdl.Renderer.destroy(renderer);
    sdl.Window.destroy(window);
}

pub fn init(num_windows: u8, options: WindowOptions) !void {
    windows = try alc.gpa.alloc(Window, num_windows);
    for (0..num_windows) |i| {
        windows[i] = try create(options);
    }
}

pub fn deinit() void {
    alc.gpa.free(windows);
}

pub fn getWindows() []Window {
    return windows;
}

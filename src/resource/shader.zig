const std = @import("std");
const alc = @import("../allocator.zig");
const rsc = @import("resourcecollection.zig");
const ren = @import("../render/rendersystem.zig");
const thm = @import("../threading/threadmanager.zig");

const zgl = ren.zgl;

const shd_ui_v: [:0]const u8 = @embedFile("../internalassets/ui_v.shader");
const shd_ui_g: [:0]const u8 = @embedFile("../internalassets/ui_g.shader");
const shd_ui_f: [:0]const u8 = @embedFile("../internalassets/ui_f.shader");

pub var shaders = rsc.resourceCollection(Shader, create, destroy){};

pub fn init(allocator: std.mem.Allocator) !void {
    try shaders.init(allocator);
}

pub fn deinit() void {
    shaders.deinit();
}

pub const Shader = struct {
    program: u32 = 0,

    bse_name: i32 = -1, // "base"
    str_name: i32 = -1, // "stride"
    ind_name: i32 = -1, // "index"
    ran_name: i32 = -1, // "range"
    rot_name: i32 = -1, // "rotation"
    cra_name: i32 = -1, // "colorA"
    crb_name: i32 = -1, // "colorB"
    mtx_name: i32 = -1, // "matrix"
    cam_name: i32 = -1, // "camera"
    mdl_name: i32 = -1, // "model"

};

pub const ShaderMeta = struct {
    vertex: [:0]const u8 = undefined,
    geometry: [:0]const u8 = undefined,
    fragment: [:0]const u8 = undefined,
};

fn LoadShaderMeta(id: u32) !ShaderMeta {
    const base_name = "0000-sh.json";
    var meta = .{};
    var name = try alc.fba.alloc(u8, base_name.len);
    for (0..4) |i|
        name[i] = ((id / (std.math.pow(10, 3 - i))) % 10) + '0';
    _ = &meta;
    return meta;
}

fn create(r_ids: []const rsc.ResourceID) ?Shader {
    const shader: Shader = .{};
    thm.render_thread.queue.put(thm.Job{
        .task = &loadShaderProgram,
        .payload = r_ids[0].toRaw(),
    }) catch |err|
        {
        std.log.err("Shader job could not be enqueued {!}", .{err});
    };
    return shader;
}

fn destroy(shader: *Shader) void {
    _ = shader;
}

pub fn loadShaderProgram(id: ?u32) void {
    thm.checkPID(.render);

    const debug_shader: ShaderMeta = .{
        .vertex = "",
        .geometry = "",
        .fragment = "",
    };

    if (id) |shader_id| {
        const r_id = rsc.ResourceID.fromRaw(shader_id);
        const ms = shaders.peekByID(r_id);
        if (ms) |metastruct| {

            // careful, it's a copy
            const shader: *Shader = &metastruct.value;
            const program = zgl.createProgram();

            // TODO figure out how to better streamline this process

            const meta: ShaderMeta = switch (r_id.uid) {
                1 => .{
                    .vertex = shd_ui_v,
                    .geometry = shd_ui_g,
                    .fragment = shd_ui_f,
                },
                else => debug_shader,
            };

            // assignments should be the id-specific onboards
            // identified as separate files or file-packs
            const v_shader: [:0]const u8 = meta.vertex;
            const g_shader: [:0]const u8 = meta.geometry;
            const f_shader: [:0]const u8 = meta.fragment;

            // Load and compile shader modules from a provided source. Sources will need to be generally retrieved.
            const vert_module = loadShaderModule(v_shader, program, zgl.VERTEX_SHADER);
            defer zgl.deleteShader(vert_module);
            std.log.info("Compiling Vertex Shader: {}", .{vert_module});

            const geom_module = loadShaderModule(g_shader, program, zgl.GEOMETRY_SHADER);
            defer zgl.deleteShader(geom_module);
            std.log.info("Compiling Geometry Shader: {}", .{geom_module});
            const frag_module = loadShaderModule(f_shader, program, zgl.FRAGMENT_SHADER);
            defer zgl.deleteShader(frag_module);
            std.log.info("Compiling Fragment Shader: {}", .{frag_module});

            // Link shader program.
            zgl.linkProgram(program);
            ren.checkGLError("Link Program");

            if (checkShaderError(program, zgl.LINK_STATUS, zgl.getProgramiv, zgl.getProgramInfoLog))
                return;
            std.log.info("Linked Shader Program: {}", .{program});

            shader.program = program;

            // if all went well, assign program to returned struct and grab shader uniforms
            zgl.useProgram(shader.program);

            ren.checkGLError("Use Shader");

            shader.bse_name = zgl.getUniformLocation(shader.program, @as([*c]const u8, @ptrCast("base\x00")));
            shader.str_name = zgl.getUniformLocation(shader.program, @as([*c]const u8, @ptrCast("stride\x00")));
            shader.ind_name = zgl.getUniformLocation(shader.program, @as([*c]const u8, @ptrCast("index\x00")));
            shader.ran_name = zgl.getUniformLocation(shader.program, @as([*c]const u8, @ptrCast("range\x00")));
            shader.rot_name = zgl.getUniformLocation(shader.program, @as([*c]const u8, @ptrCast("rotation\x00")));
            shader.cra_name = zgl.getUniformLocation(shader.program, @as([*c]const u8, @ptrCast("colorA\x00")));
            shader.crb_name = zgl.getUniformLocation(shader.program, @as([*c]const u8, @ptrCast("colorB\x00")));
            shader.mtx_name = zgl.getUniformLocation(shader.program, @as([*c]const u8, @ptrCast("matrix\x00")));
            shader.cam_name = zgl.getUniformLocation(shader.program, @as([*c]const u8, @ptrCast("camera\x00")));
            shader.mdl_name = zgl.getUniformLocation(shader.program, @as([*c]const u8, @ptrCast("model\x00")));
        } else {
            std.log.err("Shader system could not access shader resource for shader generation/compilation! Likely race condition?", .{});
        }
    } else std.log.warn("Supplied shader ID was null, rejecting...", .{});
}

fn loadShaderModule(shader_source: [:0]const u8, program: u32, module_type: u32) u32 {
    const module: u32 = zgl.createShader(module_type);
    zgl.shaderSource(module, 1, @as([*c]const [*c]const u8, &@as([*c]const u8, shader_source)), null);
    zgl.compileShader(module);
    zgl.attachShader(program, module);

    ren.checkGLError("Module Processing");
    _ = checkShaderError(module, zgl.COMPILE_STATUS, zgl.getShaderiv, zgl.getShaderInfoLog);

    return module;
}

pub fn checkShaderError(
    module: u32,
    status: u32,
    getIV: *const fn (c_uint, c_uint, [*c]c_int) callconv(.C) void,
    getIL: *const fn (c_uint, c_int, [*c]c_int, [*c]u8) callconv(.C) void,
) bool {
    var is_error = false;
    var result: i32 = 0;
    var length: i32 = 0;
    var info_log: []u8 = undefined;

    getIV(module, status, &result);
    getIV(module, zgl.INFO_LOG_LENGTH, &length);

    if (length > 0) {
        is_error = true;
        info_log = alc.fba.alloc(u8, @intCast(length + 1)) catch |err| {
            std.log.err("Shader module compilation failed with error, could not retrieve error: {!}", .{err});
            return is_error;
        };
        defer alc.fba.free(info_log);
        getIL(module, length, null, @as([*c]u8, @ptrCast(&info_log[0])));
        std.log.err("Shader compilation failure: {s}", .{info_log});
    }

    return is_error;
}

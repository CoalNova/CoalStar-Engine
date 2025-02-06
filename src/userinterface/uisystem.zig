const std = @import("std");
const sdl = @import("zsdl");
const mth = @import("zmath");
const alc = @import("../allocator.zig");
const msh = @import("../resource/mesh.zig");
const mat = @import("../resource/material.zig");
const tex = @import("../resource/texture.zig");
const shd = @import("../resource/shader.zig");
const rsc = @import("../resource/resourcecollection.zig");
const thm = @import("../threading/threadmanager.zig");
const ren = @import("../render/rendersystem.zig");
const zgl = ren.zgl;

pub const BoxState = enum {
    active,
    empty,
    disabled,
    highlighted,
    depressed,
    fired,
};

pub const UIBox = struct {
    state: BoxState = .active,
    contents: ?[]const u8 = null,
    children: [4]?u32 = [4]?u32{ null, null, null, null },
    dimensions: @Vector(4, f32) = .{ 0.5, 0.5, 0.5, 0.5 },
    color: @Vector(4, f32) = .{ 0.5, 0.5, 0.5, 1 },
};

var master: u32 = 0;
pub var mesh_index: u32 = 0;
pub var loaded = false;

pub fn init() !void {
    const r_ids = [_]rsc.ResourceID{
        rsc.ResourceID{
            .r_enum = .mesh,
            .uid = 0, // 0 is point
        },
        .{
            .r_enum = .material,
            .uid = 1, // 1 is for UI
        },
        .{
            .r_enum = .texture,
            .uid = 1, // 1 is for UI texture
        },
        .{
            .r_enum = .shader,
            .uid = 1, // 1 is for UI Shader
        },
    };
    //TODO feex
    mesh_index = try msh.meshes.fetch(&r_ids);
    loaded = true;
}

pub fn deinit() void {
    loaded = false;
    //msh.meshes.release(std.math.maxInt(u32)) catch unreachable;
}

pub fn proc() void {
    //get mouse position and function dependant on state
}

pub fn rend() void {
    if (!loaded)
        return;
    const box = &boxes[master];
    const box_bounds: @Vector(4, f32) = .{ -1.0, -1.0, 1.0, 1.0 };
    renderBox(box, box_bounds, 0);
}

fn renderBox(box: *const UIBox, bounds: @Vector(4, f32), layer: u8) void {
    const box_bounds = bounds * box.dimensions;

    thm.checkPID(.render);

    const mesh = msh.meshes.peek(mesh_index).value;

    if (mesh.material_index[0]) |mat_index| {
        const material: mat.Material = mat.materials.peek(mat_index).value;
        //const texture = tex.textures.peek(material.texture_index);
        const shader = shd.shaders.peek(material.shader_index).value;

        const uv: @Vector(4, f32) = .{ 0, 0, 0, 0 };

        if (ren.assumed_gpu_states.program != shader.program) {
            zgl.useProgram(shader.program);
            ren.checkGLError("Use UI shader program");
            ren.assumed_gpu_states.program = shader.program;
        }
        if (ren.assumed_gpu_states.vao != mesh.vao) {
            zgl.bindVertexArray(mesh.vao);
            ren.checkGLError("Bind UI vao");
            ren.assumed_gpu_states.vao = mesh.vao;
        }

        zgl.uniform4fv(shader.bse_name, 1, @ptrCast(&box_bounds));
        zgl.uniform4fv(shader.cra_name, 1, @ptrCast(&box.color));
        zgl.uniform4fv(shader.str_name, 1, @ptrCast(&uv));
        zgl.uniform1f(shader.ind_name, -0.9 - (@as(f32, @floatFromInt(layer)) * 0.01));
        ren.checkGLError("Assign UI Uniforms");

        zgl.drawElements(
            mesh.drawstyle_enum,
            mesh.num_elements,
            zgl.UNSIGNED_INT,
            null,
        );
        ren.checkGLError("Draw UI Elements");

        for (box.children) |child|
            if (child) |c|
                renderBox(
                    &boxes[c],
                    box_bounds,
                    layer + 1,
                );
    } else std.log.err("UI box material is null id: {any}", .{mesh.material_index[0]});
}

const boxes = [_]UIBox{
    UIBox{ .children = [4]?u32{ 1, null, null, null } },
    UIBox{
        .dimensions = .{ 0.5, 0.75, 0.8, 0.9 },
        .color = .{ 0.7, 0.7, 0.7, 1.0 },
    },
};

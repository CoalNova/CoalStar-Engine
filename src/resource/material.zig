const std = @import("std");
const rsc = @import("resourcecollection.zig");
const shd = @import("shader.zig");
const tex = @import("texture.zig");
const sys = @import("../system.zig");

pub const Material = struct {
    shader_index: u32 = 0,
    texture_indices: [8]?u32 = [_]?u32{null} ** 8,
};

pub var materials = rsc.resourceCollection(Material, create, destroy){};

pub fn init(allocator: std.mem.Allocator) !void {
    try materials.init(allocator);
}

pub fn deinit() void {
    materials.deinit();
}

fn create(r_ids: []const rsc.ResourceID) ?Material {
    var mat: Material = .{};
    //count textures
    var numtex: u8 = 0;
    initial_block: for (r_ids[1..], 0..) |r_id, i| {
        switch (r_id.r_enum) {
            .texture => {
                if (numtex > mat.texture_indices.len) {
                    numtex -= 1;
                    if (sys.DEBUG_MODE)
                        std.log.err(
                            "Material resource listing requests too many textures (does engine require update?)",
                            .{},
                        );
                    mat.texture_indices[numtex] = tex.stack.fetch(r_ids[i..]);
                    numtex += 1;
                }
            },
            .shader => {
                const shader_index = shd.shaders.fetch(r_ids[i..]) catch |err| {
                    std.log.err("Acquiring shader index failed: {!}", .{err});
                    return null;
                };

                mat.shader_index = shader_index;
            },
            else => {
                break :initial_block;
            },
        }
    }

    return mat;
}

fn destroy(material: *Material) void {
    shd.shaders.release(shd.shaders.peek(material.shader_index).r_id);

    for (material.texture_indices) |tex_index| {
        if (tex_index) |index|
            tex.stack.release(index) catch |err| {
                std.log.err("Texture release failed: {!}", .{err});
            };
    }
}

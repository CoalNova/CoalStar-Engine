const std = @import("std");
const rsc = @import("resourcecollection.zig");
const zgl = @import("zopengl");
const alc = @import("../allocator.zig");
const thm = @import("../threading/threadmanager.zig");
const ren = @import("../render/rendersystem.zig");
const uis = @import("../userinterface/uisystem.zig");
const mat = @import("material.zig");
const fio = @import("../system/fileio.zig");
pub var meshes = rsc.resourceCollection(
    Mesh,
    create,
    destroy,
){};

pub fn init(allocator: std.mem.Allocator) !void {
    try meshes.init(allocator);
}

pub fn deinit() void {
    meshes.deinit();
}

pub const Mesh = struct {
    vao: u32 = 0,
    vbo: u32 = 0,
    ibo: u32 = 0,
    vio: u32 = 0,
    num_elements: i32 = 0,
    material_index: [4]?u32 = [_]?u32{ null, null, null, null },
    drawstyle_enum: u32 = 0,
    raw_resource_data: ?[]u8 = null,
};

fn create(r_ids: []const rsc.ResourceID) ?Mesh {
    // if failure occurs, return null

    var mesh: Mesh = .{};
    if (r_ids[0].r_enum != .mesh) {
        std.log.err("Assigned mesh resource ID was not a mesh", .{});
    }

    mat_block: for (r_ids[1..], 0..) |r_id, index| {
        var num_mat: u32 = 0;
        if (r_id.r_enum == .material) {
            mesh.material_index[num_mat] = mat.materials.fetch(r_ids[index + 1 ..]) catch |err| {
                std.log.err("failure fetching material index: {!}", .{err});
                return null;
            };
            num_mat += 1;
        } else if (r_id.r_enum == .mesh)
            break :mat_block;
    }

    // parse resource data and attach to Mesh object
    thm.render_thread.queue.put(thm.Job{
        .payload = r_ids[0].toRaw(),
        .task = meshToGPU,
    }) catch |err|
        {
        std.log.err("Render queue rejected put: {}", .{err});
        return null;
    };

    return mesh;
}

fn destroy(mesh: *Mesh) void {
    for (mesh.material_index) |mat_i| {
        if (mat_i) |index|
            mat.materials.release(mat.materials.peek(index).r_id);
    }
}

pub fn parseFBXASCII(raw_data: []const u8) !MeshResource {
    _ = raw_data;
}

pub fn parseFBXSerial(raw_data: []const u8) !MeshResource {
    _ = raw_data;
}

pub fn meshToGPU(payload: ?u32) void {
    // get mesh ref
    if (payload) |id| {
        const r_id = rsc.ResourceID.fromRaw(id);
        var mesh: *Mesh = undefined;

        if (meshes.peekByID(r_id)) |source_mesh| {
            mesh = &source_mesh.value;
        } else {
            std.log.err("Source mesh is busted, resource ID of {} returns null.", .{r_id});
            return;
        }

        // get mesh resource
        var m_r: MeshResource = .{};

        const debug_mesh_data = [_]u8{ 0, 0, 0, 1, 0, 0, 0, 1, 0, 0, 0, 0, 0, 0, 0, 1, 0, 0, 0, 0 };
        // apply mesh resource if applicable
        if (mesh.raw_resource_data == null) {
            const r_r_d = alc.mesh_allocator.alloc(u8, debug_mesh_data.len) catch |err| {
                std.log.err("Generation of memory for debug mesh data failed: {!}", .{err});
                return;
            };
            @memcpy(r_r_d, &debug_mesh_data);
            mesh.raw_resource_data = r_r_d;
        }

        defer {
            alc.mesh_allocator.free(mesh.raw_resource_data.?);
            mesh.raw_resource_data = null;
        }

        if (mesh.raw_resource_data) |raw_resource_data| {
            const vertex_len =
                (@as(u32, @intCast(raw_resource_data[0])) << 24) +
                (@as(u32, @intCast(raw_resource_data[1])) << 16) +
                (@as(u32, @intCast(raw_resource_data[2])) << 8) +
                raw_resource_data[3];
            const element_len =
                (@as(u32, @intCast(raw_resource_data[4])) << 24) +
                (@as(u32, @intCast(raw_resource_data[5])) << 16) +
                (@as(u32, @intCast(raw_resource_data[6])) << 8) +
                raw_resource_data[7];
            const attribs_len =
                (@as(u32, @intCast(raw_resource_data[8])) << 24) +
                (@as(u32, @intCast(raw_resource_data[9])) << 16) +
                (@as(u32, @intCast(raw_resource_data[10])) << 8) +
                raw_resource_data[11];
            m_r = .{
                .raw_vertex_data = if (vertex_len > 0)
                    raw_resource_data[12 .. 12 + vertex_len]
                else
                    null,
                .raw_element_data = if (element_len > 0)
                    raw_resource_data[12 + vertex_len .. 12 + vertex_len + element_len]
                else
                    null,
                .raw_vertices_attribs = if (attribs_len > 0)
                    raw_resource_data[12 + vertex_len + element_len .. 12 + vertex_len + element_len + attribs_len]
                else
                    null,
            };
            mesh.num_elements = @intCast(element_len);
            mesh.drawstyle_enum = 0;
        }

        // mesh resource is built by someone in the resource department

        ren.zgl.genVertexArrays(1, &mesh.vao);
        ren.checkGLError("Gen Vertex Array");
        ren.zgl.bindVertexArray(mesh.vao);
        ren.checkGLError("Bind Vertex Array");

        ren.zgl.genBuffers(1, &mesh.vbo);
        ren.checkGLError("Gen Vertex Buffer Object");
        ren.zgl.bindBuffer(ren.zgl.ARRAY_BUFFER, mesh.vbo);
        ren.checkGLError("Bind Vertex Buffer Object");

        if (m_r.raw_vertex_data) |v_data|
            ren.zgl.bufferData(ren.zgl.ARRAY_BUFFER, @intCast(v_data.len), v_data.ptr, ren.zgl.STATIC_DRAW)
        else
            ren.zgl.bufferData(ren.zgl.ARRAY_BUFFER, 1, null, ren.zgl.STATIC_DRAW);

        ren.zgl.genBuffers(1, &mesh.ibo);
        ren.checkGLError("Gen Element Buffer Object");
        ren.zgl.bindBuffer(ren.zgl.ELEMENT_ARRAY_BUFFER, mesh.ibo);
        ren.checkGLError("Bind Element Buffer Object");

        if (m_r.raw_element_data) |e_data|
            ren.zgl.bufferData(ren.zgl.ELEMENT_ARRAY_BUFFER, @intCast(e_data.len), e_data.ptr, ren.zgl.STATIC_DRAW)
        else
            ren.zgl.bufferData(ren.zgl.ELEMENT_ARRAY_BUFFER, 1, null, ren.zgl.STATIC_DRAW);

        ren.zgl.genBuffers(1, &mesh.vio);
        ren.checkGLError("Gen Vertex Instance Object");
        // VIO is processed and updated real-time, when applicable

        if (m_r.raw_vertices_attribs) |rva_array| {
            const att_size = @sizeOf(MeshResourceAttribute);
            const rva_quant = rva_array.len / att_size;

            for (0..rva_quant) |rva| {
                const mra = makeMeshResourceAttribute(rva_array[rva * att_size ..]);
                ren.zgl.enableVertexAttribArray(mra.index);
                ren.zgl.vertexAttribPointer(
                    mra.index,
                    mra.size,
                    mra.vert_type,
                    mra.normalized,
                    mra.stride,
                    @ptrFromInt(mra.pointer),
                );
            }
        } else {
            ren.zgl.enableVertexAttribArray(1);
            ren.zgl.vertexAttribPointer(
                1, //name: Uint,
                4, //vertex data type size: Int,
                ren.zgl.FLOAT, //vertex type enum: Enum,
                ren.zgl.FALSE, //normalize inputs: Boolean,
                4, //stride: Sizei,
                null, // starting position as pointer: ?*const anyopaque,
            );
        }
    } else std.log.err(
        "A requested mesh to GPU operation did not contain any ID (was null)",
        .{},
    );
}

pub fn makeMeshResourceAttribute(slice: []u8) MeshResourceAttribute {
    return .{
        .index = fio.intFromByteSlice(u32, slice[0..4]),
        .size = fio.intFromByteSlice(i32, slice[4..8]),
        .vert_type = fio.intFromByteSlice(u32, slice[8..12]),
        .normalized = slice[12],
        .stride = fio.intFromByteSlice(i32, slice[13..17]),
        .pointer = if (@sizeOf(usize) == @sizeOf(u32))
            fio.intFromByteSlice(u32, slice[17..21])
        else if (@sizeOf(usize) == @sizeOf(u64))
            fio.intFromByteSlice(u64, slice[17..25]),
    };
}

pub const MeshResourceAttribute = struct {
    index: u32 = 1,
    size: i32 = 4,
    vert_type: ren.zgl.Enum = ren.zgl.FLOAT,
    normalized: ren.zgl.Boolean = ren.zgl.FALSE,
    stride: i32 = 4,
    pointer: usize = 0,
};

pub const MeshResource = struct {
    raw_vertex_data: ?[]u8 = null,
    raw_element_data: ?[]u8 = null,
    raw_vertices_attribs: ?[]u8 = null,
};

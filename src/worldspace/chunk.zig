const std = @import("std");
const prp = @import("prop.zig");
const cfg = @import("../system/configuration.zig");
const alc = @import("../allocator.zig");
const pos = @import("../position.zig");
const pct = @import("propoctree.zig");

pub const Chunk = struct {
    index: @Vector(2, u32) = .{ 0, 0 },
    height_offset: []?u8 = null,
    heights: []?[512 * 512]u16 = null,
    static_props: []?pct.PropOctree = undefined,
    //actors?
};

pub var chunk_allocator: std.mem.Allocator = undefined;
pub var chunks: []Chunk = undefined;

pub fn init(config: cfg.GameConfig, allocator: std.mem.Allocator) !void {
    chunk_allocator = allocator;
    chunks = allocator.alloc(Chunk, config.world_size[0] * config.world_size[1]);
}

pub fn loadChunk(chunkdata: []const u8) void {}

pub fn saveChunk(chunk: Chunk) void {}

pub fn deinit() void {}

pub fn getHeight(position: pos.Position) f32 {
    const minor_mask = (1 << pos.Position.divisor_bit_len) - 1;
    const major_mask = ((1 << pos.Position.axis_bit_len) - 1) << pos.Position.divisor_bit_len;
    const index_mask = ((1 << pos.Position.index_bit_len) - 1) <<
        (pos.Position.axis_bit_len + pos.Position.divisor_bit_len);
    const index: u32 =
        @as(u32, @intCast((position.x & index_mask))) >>
        (pos.Position.axis_bit_len + pos.Position.divisor_bit_len) +
        @as(u32, @intCast((position.x & index_mask))) >>
        (pos.Position.axis_bit_len + pos.Position.divisor_bit_len - 16);
    const axial = position.getAxial();

    if (chunks.peekByID(index)) |chunk| {
        // if chunk loaded
        if (chunk.value.heights) |chunk_heights| {
            // if chunk heights loaded
            if (chunk_heights[@intCast(position.z_index)]) |heights| {
                // if axial value is range
                if ((position.x & minor_mask) > 0 or (position.y & minor_mask) > 0) {
                    // get cross product
                    return getHeight(pos.Position.init(
                        position.getIndex(),
                        .{
                            @floor(axial[0]),
                            @floor(axial[1]),
                            @floor(axial[2]),
                        },
                    ));
                }

                const major_x = (position.x & major_mask) >> pos.Position.divisor_bit_len;
                const major_y = (position.y & major_mask) >> pos.Position.divisor_bit_len;
                const height_index = (major_x >> 1) + ((major_y >> 1) * 512);
                std.debug.assert(height_index < 512 * 512);
                const chunk_index = position.getIndex();

                if ((position.x & 1) > 0 and (position.y & 1) > 0) {
                    return (getHeight(pos.Position.init(chunk_index, axial + .{ 1, 1, 0 })) +
                        getHeight(pos.Position.init(chunk_index, axial + .{ 1, -1, 0 })) +
                        getHeight(pos.Position.init(chunk_index, axial + .{ -1, 1, 0 })) +
                        getHeight(pos.Position.init(chunk_index, axial + .{ -1, -1, 0 }))) * 0.25;
                }

                if ((position.x & 1) > 0)
                    return (getHeight(pos.Position.init(chunk_index, axial + .{ -1, 0, 0 })) +
                        getHeight(pos.Position.init(chunk_index, axial + .{ 1, 0, 0 }))) * 0.5;

                if ((position.y & 1) > 0)
                    return (getHeight(pos.Position.init(chunk_index, axial + .{ 0, -1, 0 })) +
                        getHeight(pos.Position.init(chunk_index, axial + .{ 0, 1, 0 }))) * 0.5;

                return @as(f32, @floatFromInt(heights[height_index])) * 0.1 +
                    if (chunk.value.height_offset[@intCast(position.z_index)]) |offset|
                    (offset * 1024.0)
                else
                    0.0;
            }
        }
    }

    return 0.0;
}

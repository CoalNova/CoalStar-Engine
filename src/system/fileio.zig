const std = @import("std");
const alc = @import("../allocator.zig");
const msh = @import("../resource/mesh.zig");
const mat = @import("../resource/material.zig");
const tex = @import("../resource/texture.zig");
//const aud = @import("../resource/audio.zig");
const shd = @import("../resource/shader.zig");

const MaxLoadFileSize = 1 << 24;

pub const stdout_file = std.io.getStdOut().writer();
pub var bw = std.io.bufferedWriter(stdout_file);
pub const stdout = bw.writer();

pub fn init() !void {
    //load manifests
    //link manifests
    //error check manifest links
}

pub fn deinit() void {
    //clear manifest data
}

pub inline fn print(comptime format: []const u8, args: anytype) !void {
    try stdout.print(format, args);
    try bw.flush();
}

pub inline fn loadFile(rel_path: []const u8) !std.fs.File {
    var cwd = std.fs.cwd();
    return cwd.openFile(rel_path, .{});
}

pub fn loadAllocFile(
    rel_path: [:0]const u8,
    allocator: std.mem.Allocator,
) ![]u8 {
    var file = try loadFile(rel_path);
    defer file.close();
    return file.readToEndAlloc(allocator, 1 << 24);
}

pub fn procResourceFile(file: std.fs.File) !void {
    _ = file;
    //
}

pub fn loadArchive() !void {}

pub fn stackResourceManifest() !void {}

/// Endianless transferal until I remember where it is in the standard library
pub inline fn intFromByteSlice(comptime T: type, slice: []u8) T {
    if (slice.len == @sizeOf(T))
        switch (T) {
            u64 => return @as(T, slice[0]) + (@as(T, slice[1]) << 8) + (@as(T, slice[2]) << 16) + (@as(T, slice[3]) << 24) +
                (@as(T, slice[4]) << 32) + (@as(T, slice[5]) << 40) + (@as(T, slice[6]) << 48) + (@as(T, slice[7]) << 56),
            u32 => return @as(T, slice[0]) + (@as(T, slice[1]) << 8) + (@as(T, slice[2]) << 16) + (@as(T, slice[3]) << 24),
            u24 => return @as(T, slice[0]) + @as(T, slice[1] << 8) + @as(T, slice[2] << 16),
            u16 => return @as(T, slice[0]) + @as(T, slice[1] << 8),
            i64 => return @as(T, @bitCast(@as(u64, slice[0]) + @as(u64, slice[1] << 8) + @as(u64, slice[2] << 16) +
                @as(u64, slice[3] << 24) + @as(u64, slice[4] << 32) + @as(T, slice[5] << 40) +
                @as(u64, slice[6] << 48) + @as(u64, slice[7] << 56))),
            i32 => return @as(T, @bitCast(@as(u32, slice[0]) + (@as(u32, slice[1]) << 8) + (@as(u32, slice[2]) << 16) + (@as(u32, slice[3]) << 24))),
            i24 => return @as(T, @bitCast(@as(u24, slice[0]) + @as(u24, slice[1] << 8) + @as(u24, slice[2] << 16))),
            i16 => return @as(T, @bitCast(@as(u16, slice[0]) + @as(u16, slice[1] << 8))),
            else => std.log.err("Conversion for type {} not yet implemented", .{T}),
        };
    @panic("Error in integral slice conversion");
}

const std = @import("std");
const jsn = std.json;
const alc = @import("../allocator.zig");

pub const GameConfig = struct {
    title: []const u8 = undefined,
    entry: []const u8 = undefined,
    world_size: @Vector(2, u32) = undefined,
};

pub const GraphicsConfig = struct {
    fullscreen: bool = false,
    borderless: bool = false,
    wireframe: bool = false,
};

pub var game_cfg: ?GameConfig = null;
pub var graphics_cfg: ?GraphicsConfig = null;

pub fn init(allocator: std.mem.Allocator) !void {
    game_cfg = .{};
    try game_cfg.?.init(allocator);
}

pub fn deinit() void {
    if (game_cfg) |cfg|
        cfg.deinit();
}

/// Parses Game Configuration
/// Resultant value must call deinit()
pub fn parseGameConfig(raw_cfg: []const u8, allocator: std.mem.Allocator) !GameConfig {
    // for now, duplicate data
    const parsed = try jsn.parseFromSlice(
        GameConfig,
        allocator,
        raw_cfg,
        .{ .allocate = .alloc_always },
    );
    defer parsed.deinit();

    var game_config: GameConfig = .{};
    try game_config.initFrom(parsed.value, allocator);

    return game_config;
}

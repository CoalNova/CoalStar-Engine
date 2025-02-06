const std = @import("std");
const fio = @import("../system/fileio.zig");
const cfg = @import("../system/configuration.zig");

pub fn resourceThreadLoop(game_cfg_path: []const u8, allocator: std.mem.Allocator) !void {
    // firstly load game config
    // reloading config considered too intensive for the engine currently
    const config_data = try fio.loadAllocFile(game_cfg_path, allocator);
    if (cfg.game_cfg) |game_cfg|
        game_cfg.deinit()
    else
        cfg.game_cfg = .{};
    cfg.game_cfg = cfg.parseGameConfig(config_data, allocator);

    // from there, load resource archives
    // then load relevant resources
}

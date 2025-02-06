const std = @import("std");
const fio = @import("system/fileio.zig");
const cfg = @import("system/configuration.zig");

/// Initializes gamedata resources and loads gamedata.cfg
pub fn init() !void {}

/// Deinitializes config and resource data
pub fn deinit() void {}

/// Loads game config file based on set/unset game config global
pub fn loadGameConfig() !void {
    if (game_config_path) |path| {
        try fio.loadFile(path);
    } else {
        try fio.loadFile("default_game.cfg");
    }
}

pub var game_config_path: ?[:0]u8 = null;

const std = @import("std");
const zau = @import("zaudio");
const alc = @import("../allocator.zig");
const sys = @import("../system.zig");

var music: *zau.Sound = undefined;
var engine: *zau.Engine = undefined;

pub fn init() !void {
    zau.init(alc.gpa);
    engine = try zau.Engine.create(null);

    music = try engine.createSoundFromFile(
        "./assets/audios/peepers.mp3",
        .{ .flags = .{ .stream = true } },
    );
    try music.start();
    sys.setStateOn(.audio);
}

pub fn deinit() void {
    music.destroy();
    engine.destroy();
    zau.deinit();
    sys.setStateOff(.audio);
}

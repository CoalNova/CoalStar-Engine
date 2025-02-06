const std = @import("std");
const zau = @import("zaudio");
const rsc = @import("resourcecollection.zig");

pub const Audio = struct {
    sound: zau.Sound = undefined,
};

var audios = rsc.resourceCollection(Audio, create, destroy);

var engine: zau.Engine = undefined;

pub fn init(allocator: std.mem.Allocator) !void {
    zau.init(allocator);
    engine = .{};
}

fn create(r_id: rsc.ResourceID) Audio {
    _ = r_id;
    //TODO resource loading
    return Audio{ .sound = engine.createSoundFromFile(
        "./assets/audios/peepers.mp3",
        .{ .flags = .{ .stream = true } },
    ) catch |err| {
        std.log.err("Error ini audio generation: {!}", .{err});
        engine.createSound(.{});
    } };
}

fn destroy(audio: *Audio) void {
    audio.sound.destroy();
}

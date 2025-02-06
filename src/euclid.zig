const zmt = @import("zmath");
const pos = @import("position.zig");

/// The Combination of Position, Rotation, and Scale
pub const Euclid = struct {
    scale: u16 = (5 << 8) + (5 << 4) + 5,
    position: pos.Position = .{},
    rotation: zmt.Quat = zmt.Quat{ 0.0, 0.0, 0.0, 1.0 },
    pub inline fn getScaleVector(self: Euclid) zmt.F32x4 {
        return zmt.f32x4(
            @as(f32, @floatFromInt((self.scale >> 8) & 15)),
            @as(f32, @floatFromInt((self.scale >> 4) & 15)),
            @as(f32, @floatFromInt((self.scale) & 15)),
            1.0,
        );
    }
};

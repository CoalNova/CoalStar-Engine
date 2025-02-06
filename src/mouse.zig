const std = @import("std");
const zdl = @import("zsdl");
const wnd = @import("window.zig");
const evt = @import("event.zig");

pub const Mouse = struct {
    abs_position: @Vector(2, i32) = .{ 0, 0 },
    rel_position: @Vector(2, f32) = .{ 0, 0 },
    button_state: [32]evt.InputState = [_]evt.InputState{.left} ** 32, // for excessive mice
    pub fn procMouse(self: *Mouse, window: wnd.Window) void {
        _ = zdl.getMouseState(&self.abs_position[0], &self.abs_position[1]);

        const fmx = @as(f32, @floatFromInt(self.abs_position[0]));
        const fmy = @as(f32, @floatFromInt(self.abs_position[1]));
        const fwy = @as(f32, @floatFromInt(window.bounds[2]));
        const fwz = @as(f32, @floatFromInt(window.bounds[3]));

        self.rel_position = @Vector(2, f32){
            ((fmx - fwy / 2.0) / fwy) * 2.0,
            -(((fmy - fwz / 2.0) / fwz) * 2.0),
        };
    }
    pub fn procInputs(self: *Mouse) void {
        const input_bits = zdl.getMouseState(null, null);

        for (&self.button_state, 0..) |*state, i| {
            const b: bool = (((@as(u32, 1) << @intCast(i)) & input_bits) > 0);
            state.* = switch (state.*) {
                evt.InputState.none => if (b) .down else .none,
                evt.InputState.down => if (b) .stay else .left,
                evt.InputState.stay => if (b) .stay else .left,
                evt.InputState.left => if (b) .down else .none,
            };
        }
    }
};

const std = @import("std");

pub const Position = struct {
    pub const divisor_bit_len = 11; //0.00048828125 steps, 1/2mm
    pub const axis_bit_len = 10; //0-1,024 meters
    pub const z_axis_bit_len = 20; //0-1,048,576 meters
    pub const index_bit_len = 10; //0-1024

    x: i32 = 512 << divisor_bit_len,
    y: i32 = 512 << divisor_bit_len,
    z: i32 = 512 << divisor_bit_len,
    z_index: i32 = 0,

    pub fn getAxial(self: Position) @Vector(3, f32) {
        return @Vector(3, f32){
            @as(f32, @floatFromInt(self.x & (divisor_bit_len + axis_bit_len))) / (1 << divisor_bit_len),
            @as(f32, @floatFromInt(self.y & (divisor_bit_len + axis_bit_len))) / (1 << divisor_bit_len),
            @as(f32, @floatFromInt(self.z & (divisor_bit_len + z_axis_bit_len))) / (1 << divisor_bit_len),
        };
    }
    pub fn addAxial(self: *Position, axial: @Vector(3, f32)) void {
        self.x += @as(i32, @intFromFloat(axial[0] * (1 << divisor_bit_len)));
        self.y += @as(i32, @intFromFloat(axial[1] * (1 << divisor_bit_len)));
        self.z += @as(i32, @intFromFloat(axial[2] * (1 << divisor_bit_len)));
    }
    pub fn getIndex(self: Position) @Vector(3, i32) {
        return @Vector(3, i32){
            self.x >> (divisor_bit_len + axis_bit_len),
            self.y >> (divisor_bit_len + axis_bit_len),
            self.z_index,
        };
    }
    pub fn addIndex(self: *Position, index: @Vector(3, i32)) void {
        self.x += index[0] << (divisor_bit_len + axis_bit_len);
        self.y += index[1] << (divisor_bit_len + axis_bit_len);
        self.z_index += index[2];
    }
    pub fn init(self: *Position, index: @Vector(3, i32), axial: @Vector(3, f32)) void {
        self.x = (index[0] << (divisor_bit_len + axis_bit_len)) +
            @as(i32, @intFromFloat(axial[0] * (1 << divisor_bit_len)));
        self.y = (index[1] << (divisor_bit_len + axis_bit_len)) +
            @as(i32, @intFromFloat(axial[1] * (1 << divisor_bit_len)));
        self.z = @as(i32, @intFromFloat(axial[2] * (1 << divisor_bit_len)));
        self.z_index = index[2];
    }
};

test "position set" {
    const a = @Vector(3, f32){ 1.0, 4.0, 3.0 };
    const i = @Vector(3, i32){ 0, 0, 5 };
    const p: Position = .{}.init(a, i);
    std.debug.assert(p.getAxial() == a and p.getIndex() == i);
}

test "position add" {
    const a = @Vector(3, f32){ 1.0, 4.0, 3.0 };
    var p: Position = .{};
    p.addAxial(a);
    p.addAxial(a);
    std.debug.assert(p.getAxial() == a + a);
}

test "position add index" {
    const a = @Vector(3, f32){ 1.0, 4.0, 3.0 };
    const i = @Vector(3, i32){ 0, 0, 5 };
    const i_2 = @Vector(3, i32){ 4, 5, 0 };
    const p: Position = .{}.init(a, i);
    p.addIndex(i_2);
    std.debug.assert(p.getAxial() == a and p.getIndex() == i + i_2);
}

const std = @import("std");
const mth = @import("zmath");
const csm = @import("system/csmath.zig");
const euc = @import("euclid.zig");
const wnd = @import("window.zig");

pub const Camera = struct {
    euclid: euc.Euclid = .{},
    field_of_view: f32 = 90.0,
    near_plane: f32 = 0.01,
    far_plane: f32 = 10000.0,
    forward: mth.F32x4 = undefined,
    upward: mth.F32x4 = undefined,
    view_matrix: mth.Mat = undefined,
    projection_matrix: mth.Mat = undefined,
    horizon_matrix: mth.Mat = undefined,
    rotation_matrix: mth.Mat = undefined,
    vp_matrix: mth.Mat = undefined,

    /// Calculates View and Projection Matrices
    pub fn calculateMatrices(self: *Camera, window: *wnd.Window) void {
        const tmp_pos = self.euclid.position.getAxial();
        const cam_pos = mth.f32x4(tmp_pos[0], tmp_pos[1], tmp_pos[2], 1);
        const cam_eul = csm.vec3ToH(csm.convQuatToEul(self.euclid.rotation));
        self.forward = mth.normalize4(mth.mul(mth.quatToMat(self.euclid.rotation), mth.f32x4(0, 1, 0, 1)));
        const right = mth.normalize4(mth.mul(mth.quatToMat(self.euclid.rotation), mth.f32x4(1, 0, 0, 1)));
        self.upward = mth.normalize4(mth.cross3(right, self.forward));

        self.horizon_matrix = csm.convQuatToMat4(csm.convEulToQuat(csm.Vec3{ 0, 0, (cam_eul[2] + 90) * std.math.pi / 180 }));
        self.rotation_matrix = csm.convQuatToMat4(csm.convEulToQuat(csm.Vec3{ (cam_eul[0]) * std.math.pi / 180, 0, (cam_eul[2] + 90) * std.math.pi / 180 }));

        self.view_matrix = mth.lookAtRh(
            cam_pos,
            cam_pos + self.forward,
            self.upward,
        );

        self.projection_matrix =
            mth.perspectiveFovRhGl(
            self.field_of_view,
            @as(f32, @floatFromInt(window.bounds[2])) / @as(f32, @floatFromInt(window.bounds[3])),
            self.near_plane,
            self.far_plane,
        );

        self.vp_matrix = mth.mul(self.view_matrix, self.projection_matrix);
    }
};

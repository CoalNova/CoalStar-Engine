//! An extension of ZMath
//! Contains a few helpfull utilities that I've added as needs arise
//! Not all of it functions well, or at all

const std = @import("std");
const zmt = @import("zmath");
const zph = @import("zphysics");

pub const Mat4 = [4]@Vector(4, f32);
pub const Quat = @Vector(4, f32); // x,y,z,w
pub const Vec4 = @Vector(4, f32); // w,x,y,z?
pub const Vec3 = @Vector(3, f32); // x,y,z

/// Take Quaternion, Make Euler
/// Mind the Radians, they're sharp.
pub fn convQuatToEul(q: @Vector(4, f32)) @Vector(3, f32) {
    var angles = @Vector(3, f32){ 0, 0, 0 }; //yaw pitch roll
    const x = q[0];
    const y = q[1];
    const z = q[2];
    const w = q[3];

    // roll (x-axis rotation)
    const sinr_cosp = 2 * (w * x + y * z);
    const cosr_cosp = 1 - 2 * (x * x + y * y);
    angles[0] = std.math.atan2(sinr_cosp, cosr_cosp);

    // pitch (y-axis rotation)
    const sinp: f32 = 2 * (w * y - z * x);
    if (@abs(sinp) >= 1) {
        angles[1] = std.math.copysign(@as(f32, std.math.pi / 2.0), sinp); // use 90 degrees if out of range
    } else angles[1] = std.math.asin(sinp);

    // yaw (z-axis rotation)
    const siny_cosp = 2 * (w * z + x * y);
    const cosy_cosp = 1 - 2 * (y * y + z * z);
    angles[2] = std.math.atan2(siny_cosp, cosy_cosp);
    return angles;
}

/// Take Euler, Make Quaternion
pub fn convEulToQuat(vec: Vec3) Quat {
    // Abbreviations for the various angular functions

    const cr: f32 = std.math.cos(vec[1] * 0.5);
    const sr: f32 = std.math.sin(vec[1] * 0.5);
    const cp: f32 = std.math.cos(vec[0] * 0.5);
    const sp: f32 = std.math.sin(vec[0] * 0.5);
    const cy: f32 = std.math.cos(vec[2] * 0.5);
    const sy: f32 = std.math.sin(vec[2] * 0.5);

    return Quat{
        sr * cp * cy - cr * sp * sy,
        cr * sp * cy + sr * cp * sy,
        cr * cp * sy - sr * sp * cy,
        cr * cp * cy + sr * sp * sy,
    };
}

/// Oblivion Dialogue, but with more math
pub fn lookat(right: Vec3, up: Vec3, forward: Vec3, position: Vec3) Mat4 {
    return Mat4{
        Vec4{ right[0], right[1], right[2], vec3Dot(position, right) },
        Vec4{ up[0], up[1], up[2], vec3Dot(position, up) },
        Vec4{ forward[0], forward[1], forward[2], vec3Dot(position, forward) },
        Vec4{ 0, 0, 0, 1 },
    };
}

/// Quaternion to Matrix
pub fn convQuatToMat4(q: Quat) Mat4 {
    const x = q[0];
    const y = q[1];
    const z = q[2];
    const w = q[3];

    return Mat4{
        Vec4{ 1 - 2 * y * y - 2 * z * z, 2 * x * y - 2 * w * z, 2 * x * z + 2 * w * y, 0 },
        Vec4{ 2 * x * y + 2 * w * z, 1 - 2 * x * x - 2 * z * z, 2 * y * z - 2 * w * x, 0 },
        Vec4{ 2 * x * z - 2 * w * y, 2 * y * z + 2 * w * x, 1 - 2 * x * x - 2 * y * y, 0 },
        Vec4{ 0, 0, 0, 1 },
    };
}

/// Radians From Degrees
pub fn radians(degrees: f32) f32 {
    const adj_d = degrees - (degrees / 180.0) * 180.0;
    return (adj_d / 180) * std.math.pi;
}

/// dot product of a Vector3
pub inline fn vec3Dot(fst: Vec3, scd: Vec3) f32 {
    const thd = fst * scd;
    return thd[0] + thd[1] + thd[2];
}

/// Adds 1 to the end for homogeneous coordinate transformations
pub inline fn vec3ToH(vec: Vec3) Vec4 {
    return Vec4{ vec[0], vec[1], vec[2], 1 };
}

/// Only 3 Do We Need?
pub inline fn vec4to3(vec: Vec4) Vec3 {
    return Vec3{ vec[0], vec[1], vec[2] };
}

/// Don't Ask, it worked
pub inline fn badCross(vec_a: Vec3, vec_b: Vec3) Vec3 {
    return Vec3{
        vec_a[1] * vec_b[2] - vec_a[2] * vec_b[1],
        vec_a[2] * vec_b[0] - vec_a[0] * vec_b[2],
        vec_a[1] * vec_b[0] - vec_a[0] * vec_b[1],
    };
}

/// Cross Product
pub inline fn cross(vec_a: Vec3, vec_b: Vec3) Vec3 {
    return Vec3{
        vec_a[1] * vec_b[2] - vec_a[2] * vec_b[1],
        vec_a[2] * vec_b[0] - vec_a[0] * vec_b[2],
        vec_a[0] * vec_b[1] - vec_a[1] * vec_b[0],
    };
}

/// Ray Plane intersction
/// TODO make work
pub inline fn rayPlane(
    plane_origin: Vec3,
    plane_normal: Vec3,
    ray_origin: Vec3,
    ray_direction: Vec3,
    ray_length: *f32,
) bool {

    // assuming vectors are all normalized
    const denom = vec3Dot(plane_normal, ray_direction);
    if (std.math.fabs(denom) > 1e-6) {
        ray_length.* = vec3Dot(plane_origin - ray_origin, plane_normal) / denom;
        return (ray_length.* >= 0.0);
    }

    return false;
}

pub inline fn normalizeVec3(vec3: Vec3) Vec3 {
    const sum = @abs(vec3[0]) + @abs(vec3[1]) + @abs(vec3[2]);
    return Vec3{ vec3[0] / sum, vec3[1] / sum, vec3[2] / sum };
}

/// Print Matrix using debug.print
pub fn printMatrix(matrix: zmt.Mat) void {
    std.debug.print(
        \\mat:
        \\[{d:.3},{d:.3},{d:.3},{d:.3}]
        \\[{d:.3},{d:.3},{d:.3},{d:.3}]
        \\[{d:.3},{d:.3},{d:.3},{d:.3}]
        \\[{d:.3},{d:.3},{d:.3},{d:.3}]
        \\
    , .{
        matrix[0],
        matrix[3],
        matrix[6],
        matrix[0][3],
        matrix[1],
        matrix[4],
        matrix[7],
        matrix[1][3],
        matrix[2],
        matrix[5],
        matrix[8],
        matrix[2][3],
        matrix[3][0],
        matrix[3][1],
        matrix[3][2],
        matrix[3][3],
    });
}

pub fn QuadTree(comptime T: type) type {
    return struct {
        const Self = @This();
        const SubNode = union { branch: *QuadNode, leaf: T };
        pub const QuadNode = struct {
            parent: ?*QuadNode = null,
            children: [4]?SubNode = [4]?SubNode{ null, null, null, null },
        };
        root: QuadNode = .{},
        allocator: std.mem.Allocator = undefined,
        pub fn init(self: *Self, allocator: std.mem.Allocator) !void {
            self.allocator = allocator;
        }
    };
}

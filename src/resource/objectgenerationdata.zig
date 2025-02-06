//! The OGD is the mainstay type to handle placement of all objects in the worldspace
//! This includes actors, props, emitters, and other effects. The guidelines for generation
//! are that the OGD exists in a packed and unpacked state.
//!
//!
const euc = @import("../euclid.zig");

pub const PackedOGD = struct {
    ///process   <1> [1] 0 = packed OGD, 1 = Different process
    ///enabled   <1> [2] 0 = disabled, 1 = enabled
    ///static    <1> [3] 0 = dynamic , 1 = static
    ///type      <3> [4] {prop, actor, emitter, field, force, override}
    ///type spec <58>[5] ...
    ///      prop ID <32>
    ///      prop state <8>
    ///      prop script <18>
    item_data: u64,

    ///pos_x     <7> [a] * (1/127) = {0 .. 1.0}
    ///pos_y     <7> [b] * (1/127) = {0 .. 1.0}
    ///pos_z     <17>[c] * (1/127) - 516 = {-516 .. 516}
    ///sca_x     <4> [d] * 0.2 = {0 .. 3.0}
    ///sca_y     <4> [e] * 0.2 = {0 .. 3.0}
    ///sca_z     <4> [f] * 0.2 = {0 .. 3.0}
    ///rot_x     <7> [g] * (2/127) {0 .. 2 Radians PI}
    ///rot_y     <7> [h] * (2/127) {0 .. 2 Radians PI}
    ///rot_z     <7> [i] * (2/127) {0 .. 2 Radians PI}
    euclid_data: u64,
};

pub const GenType = enum(u3) {
    prop = 0,
    actor = 1,
    emitter = 2,
    field = 3,
    force = 4,
    override = 5,
    modification = 6,
    unused = 7,
};

pub const OGD = struct {
    chunk_index: @Vector(2, u32) = .{ 0, 0 },
    uid: u64 = 0,
    gentype: GenType = .unused,
    enabled: bool = true,
    //generation: union{prop:},
    euclid: euc.Euclid = .{},
};

const std = @import("std");
const euc = @import("../euclid.zig");
const msh = @import("../resource/mesh.zig");
const ogd = @import("../resource/objectgenerationdata.zig");
const rsc = @import("../resource/resourcecollection.zig");

pub const Prop = struct {
    enabled: bool = true,
    static: bool = true,
    mesh_index: u32 = 0,
    script_index: u32 = 0,
    euclid: euc.Euclid = .{},
};

pub fn constructionalize(euclid: euc.Euclid, is_enabled: bool, is_static: bool, r_ids: []rsc.ResourceID) Prop {
    var prop: Prop = .{
        .enabled = is_enabled,
        .euclid = euclid,
        .static = is_static,
    };
    for (r_ids) |r_id| {
        if (r_id.r_enum == .mesh) {
            prop.mesh_index = 0;
        }
        if (r_id.r_enum == .script) {}
    }
    return prop;
}

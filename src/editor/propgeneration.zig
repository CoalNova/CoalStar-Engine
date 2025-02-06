const prp = @import("../worldspace/prop.zig");
const euc = @import("../euclid.zig");
const chk = @import("../worldspace/chunk.zig");

pub fn generateProp(euclid: euc.Euclid, prop: prp.Prop) !void {
    _ = euclid;
    chk.chunks[0].static_props[0].?.put(prop);
}

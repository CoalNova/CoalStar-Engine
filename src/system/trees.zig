const std = @import("std");

pub const QuadTree = struct {
    pub const Node = struct {
        pub const Child = union {
            branch: *Node,
            leaf: []u24,
        };
        parent: ?*Node,
        child: [4]?*Child,
    };
    allocator: std.mem.allocator = undefined,
};

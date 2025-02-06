const std = @import("std");
const prp = @import("prop.zig");
const sys = @import("../system.zig");

pub const PropOctree = struct {
    pub const BranchTags = enum {
        branches,
        leaves,
    };

    pub const BranchUnion = union(BranchTags) {
        branches: [8]u32,
        leaves: [8]u32,
    };

    pub const Branch = struct {
        count: u8 = 0,
        root: u32 = 0,
        children: ?BranchUnion = null,
    };

    allocator: std.mem.Allocator = undefined,
    prop_list: []prp.Prop = undefined,
    branch_list: []Branch = undefined,
    prop_count: usize = 0,
    branch_count: usize = 0,

    pub fn init(self: *PropOctree, allocator: std.mem.Allocator) !void {
        self.allocator = allocator;
        self.prop_list = try allocator.alloc(prp.Prop, 256);
        self.branch_list = try allocator.alloc(Branch, 256);
        for (self.branch_list.len) |i|
            self.branch_list[i] = .{};
    }

    pub fn deinit(self: *PropOctree) void {
        self.allocator.free(self.prop_list);
        self.allocator.free(self.branch_list);
        self.prop_count = 0;
        self.branch_count = 0;
    }

    pub fn put(self: *PropOctree, prop: prp.Prop) !void {
        // resize if necessary
        if (self.prop_count + 1 > self.prop_list) {
            const old_list = self.prop_list;
            var new_list = try self.allocator.alloc(prp.Prop, self.prop_list.len * 2);
            @memcpy(new_list[0..old_list.len], old_list);
            self.prop_list = new_list;
            self.allocator.free(old_list);
        }
        defer self.prop_count += 1;
        self.prop_list[self.prop_count] = prop;

        self.emplace(prop, 10);
    }

    fn emplace(self: *PropOctree, prop: prp.Prop, offset: u32, branch_index: u32) !void {
        const branch = &self.branch_list[branch_index];
        if (branch.children) |children| {
            switch (children) {
                // if branches already exist, cascade
                .branches => {
                    const pos = prop.euclid.position;
                    const index = ((pos.x >> offset) & 1) +
                        (((pos.y >> offset) & 1) << 1) +
                        (((pos.z >> offset) & 1) << 2);
                    if (sys.DEBUG_MODE) {
                        if (index > 8)
                            std.log.err(
                                "derived Positional axis index greater than 8 for octree, {d} at position {d}",
                                .{ index, prop.oct_index },
                            );
                    }
                    self.emplace(prop, offset - 1, index);
                    return;
                },
                // if branch has leaves
                .leaves => {
                    // and leaf count isn't maxed
                    if (branch.count < children.leaves.len) {
                        branch.children.?.leaves[branch.count] = prop.oct_index;
                        branch.count += 1;
                        return;
                    }
                    // and if branch isn't at the limit
                    if (offset == 0) {
                        // break for now
                        @panic("Too many overlapping props!");
                    }
                    // else blow down leaves
                    const leaves = children.leaves;
                    // grow a branch in place of the leave
                    // resize if necessary
                    if (self.branch_count + 8 > self.branch_list) {
                        const old_list = self.branch_list;
                        var new_list = try self.allocator.alloc(Branch, old_list.len * 2);
                        for (0..new_list.len) |i| new_list[i] = if (i < old_list.len) old_list[i] else .{};
                        self.branch_list = new_list;
                        self.allocator.free(old_list);
                    }
                    branch.children = BranchUnion{
                        .branches = []u32{ 0, 0, 0, 0, 0, 0, 0, 0 },
                    };

                    for (0..8) |i| {
                        self.branch_list[self.branch_count].root = branch_index;
                        branch.children.?.branches[i] = self.branch_count;
                        self.branch_count += 1;
                    }

                    for (leaves) |l| self.emplace(self.prop_list[l], offset, branch_index);
                },
            }
        }
        // else grow this branch outwards
        branch.children = BranchUnion{
            .leaves = .{ prop.oct_index, 0, 0, 0, 0, 0, 0, 0 },
        };
        branch.count = 1;
    }
};

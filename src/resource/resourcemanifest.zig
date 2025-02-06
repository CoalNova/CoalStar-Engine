const std = @import("std");

pub const ResourceType = enum(u3) {
    text,
    chunk,
    audio,
    texture,
    mesh,
    animation,
    script,
    shader,
};

pub const ResourceManifest = struct {
    resource_list: std.ArrayHashMap(u32, ResourceEntry) = undefined,
    allocator: std.mem.Allocator = undefined,
    pub fn init(self: *ResourceManifest, allocator: std.mem.Allocator) !void {
        self.resource_list = std.AutoArrayHashMap(u32, ResourceEntry).init(allocator);
        self.allocator = allocator;
    }
    pub fn deinit(self: *ResourceManifest) void {
        self.resource_list.deinit();
    }
    pub fn parseFromList(self: *ResourceManifest, raw_list: []const u8) !void {
        var i: usize = 4;
        //list_len(4)
        const len: u32 =
            @as(u32, @intCast(raw_list[0])) +
            (@as(u32, @intCast(raw_list[1])) << 8) +
            (@as(u32, @intCast(raw_list[2])) << 16) +
            (@as(u32, @intCast(raw_list[3])) << 24);

        for (len) |_| {
            //id(4)
            const id : u32 = 
                @as(u32, @intCast(raw_list[ i])) +
                (@as(u32, @intCast(raw_list[i + 1])) << 8) +
                (@as(u32, @intCast(raw_list[i + 2])) << 16) +
                (@as(u32, @intCast(raw_list[i + 3])) << 24);
                i += 4;
            //location_len(4)
            const len = 
                @as(u32, @intCast(raw_list[ i])) +
                (@as(u32, @intCast(raw_list[i + 1])) << 8) +
                (@as(u32, @intCast(raw_list[i + 2])) << 16) +
                (@as(u32, @intCast(raw_list[i + 3])) << 24);
                i += 4;
            //location
                const location = 
            const entry = ResourceEntry{
            
            //offset(4)
            //size x(4)
            //size y(4)
            //proc v(1)
            //native_layout(1)

            };

            self.resource_list.put(id, )
        }
    }
    pub fn toList(self: *ResourceManifest, allocator: std.mem.Allocator) ![]const u8 {}

    /// Adds another Resource Manifest to this one, existing key values are overwritten
    /// It's klobbering time
    pub fn addOnto(self: *ResourceManifest, other: *ResourceManifest) !void {
        var iter = other.resource_list.iterator();
        while (iter.next()) |i|
            try self.resource_list.put(i.key_ptr.*, i.value_ptr.*);
    }
};

pub const ResourceEntry = struct {
    location: []const u8 = undefined,
    offset: usize = 0,
    size: usize = 0,
    proc_version: u8 = 0,
    native_layout: bool = false,
};

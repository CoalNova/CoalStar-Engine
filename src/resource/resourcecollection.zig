const std = @import("std");
const sys = @import("../system.zig");

/// Resource Enum is the type of the resource being used.
pub const ResourceEnum = enum(u8) {
    text,
    shader,
    material,
    texture,
    audio,
    script,
    mesh,
};

/// Resource ID is a UID that is entirely unique. It is translatable to u32 using the
/// internal function toRaw(), but memory layout is opaque. I.E. direct casting to u32 is UB.
pub const ResourceID = packed struct {
    r_enum: ResourceEnum,
    uid: u24,
    pub inline fn toRaw(self: ResourceID) u32 {
        return (@as(u32, @intFromEnum(self.r_enum)) << 24) + self.uid;
    }
    pub inline fn fromRaw(raw: u32) ResourceID {
        return .{
            .r_enum = @as(ResourceEnum, @enumFromInt(@as(u8, @intCast(raw >> 24)))),
            .uid = @intCast(raw & ((1 << 24) - 1)),
        };
    }
};

/// Resource Collection is for tracking and managing the loading/unloading of resources used by the engine.
pub fn resourceCollection(
    comptime T: type,
    comptime create: fn (r_ids: []const ResourceID) ?T,
    comptime destroy: fn (resource: *T) void,
) type {

    // T, with metadata
    const MetaStruct = struct {
        lock: std.Thread.Mutex = .{},
        r_id: ResourceID = .{ .r_enum = .text, .uid = 0 },
        subscribers: u32 = 0,
        value: T = undefined,
    };

    // Ensure that resource and meta are cacheline sized or smaller
    comptime std.debug.assert(@sizeOf(MetaStruct) <= std.atomic.cache_line);

    return struct {
        const Self = @This();
        _collection: []MetaStruct = undefined,
        _allocator: std.mem.Allocator = undefined,
        _count: usize = 0,
        comptime _create: fn (r_ids: []const ResourceID) ?T = create,
        comptime _destroy: fn (resource: *T) void = destroy,
        _keyref: std.AutoHashMap(u32, u32) = undefined,
        _lock: std.Thread.Mutex = .{},
        pub fn init(self: *Self, allocator: std.mem.Allocator) !void {
            self._allocator = allocator;
            self._collection = try allocator.alloc(MetaStruct, 4);
            self._keyref = std.AutoHashMap(u32, u32).init(allocator);
        }
        pub fn deinit(self: *Self) void {
            self._lock.lock();
            defer self._lock.unlock();
            for (0..self._count) |i|
                self._destroy(&self._collection[i].value);
            self._keyref.deinit();
            self._allocator.free(self._collection);
        }

        /// Retrieve a desired resource's index, based on a unique element ID
        /// Generates a new resource, using create() if one does not yet exist
        pub fn fetch(self: *Self, r_ids: []const ResourceID) !u32 {
            // return if contains
            const r_id = r_ids[0];

            if (self._keyref.get(r_id.toRaw())) |index| {
                self._collection[index].lock.lock();
                defer self._collection[index].lock.unlock();
                if (sys.DEBUG_MODE) {
                    if (self._collection[index].r_id.toRaw() != r_id.toRaw())
                        @panic("Resource index does not match itself, resource breach occured!");
                }
                self._collection[index].subscribers += 1;
                return index;
            }

            // emplace, *then* build
            // else create new
            const ms = MetaStruct{
                .r_id = r_id,
                .subscribers = 1,
            };

            // where subscribers are no more
            for (self._collection[0..self._count], 0..) |*m, i| {
                if (m.subscribers < 1) {
                    m.lock.lock();
                    defer m.lock.unlock();
                    // check that we haven't over-released
                    if (sys.DEBUG_MODE)
                        std.debug.assert(m.subscribers == 0);

                    _ = self._keyref.remove(m.r_id.uid);
                    self._destroy(&m.value);
                    self._collection[i] = ms;
                    try self._keyref.put(r_id.toRaw(), @intCast(i));

                    if (self._create(r_ids)) |resource|
                        self._collection[i].value = resource
                    else
                        return error.ResourceCreationFailed;
                    return @intCast(i);
                }
            }

            // or add to end
            self._lock.lock();
            defer self._lock.unlock();
            // resize collection
            if (self._count + 1 >= self._collection.len) {
                const old_collection = self._collection;
                const new_collection = try self._allocator.alloc(
                    MetaStruct,
                    self._collection.len * 2,
                );
                @memcpy(new_collection[0..self._collection.len], self._collection);
                self._collection = new_collection;
                self._allocator.free(old_collection);
            }
            const loc = self._count;
            self._count += 1;
            self._collection[loc] = ms;
            try self._keyref.put(r_id.toRaw(), @intCast(loc));
            if (self._create(r_ids)) |resource|
                self._collection[loc].value = resource
            else
                return error.ResourceCreationFailed;
            return @intCast(loc);
        }

        /// Finalizes useage of an resource, does not immediately destroy resource
        pub fn release(self: *Self, r_id: ResourceID) void {
            if (self._keyref.get(r_id.toRaw())) |index| {
                self._collection[index].lock.lock();
                defer self._collection[index].lock.unlock();
                self._collection[index].subscribers -= 1;
            } else std.log.err("ID does not exist, or is unloaded", .{});
        }
        pub inline fn peek(self: Self, index: u32) *MetaStruct {
            return &self._collection[index];
        }
        /// Slower than peek(), useable only as a temporary if item already exists
        pub inline fn peekByID(self: Self, r_id: ResourceID) ?*MetaStruct {
            if (self._keyref.get(r_id.toRaw())) |val| {
                const ms = &self._collection[val];
                // verify data if in debug build
                if (sys.DEBUG_MODE) {
                    if (ms.r_id.toRaw() != r_id.toRaw()) {
                        std.log.err(
                            "Resource collection breach at {d} for resource id {d}, expected {d}",
                            .{ val, r_id.toRaw(), ms.r_id.toRaw() },
                        );
                        return null;
                    }
                }
                return ms;
            }
            return null;
        }
    };
}

const std = @import("std");

/// Enum to handle all types of resource data
pub const ResourceType = enum(u3) {
    text, // unicode? ascii?
    chunk, // chunk data
    audio, // compression pending
    texture, // utilize pixel format directly
    mesh, // compressed vertex data, likely secondary fallback necessary
    animation, // unknown at this time
    script, // likely raw text, could compress
    shader, // see above (reduce symbols to lut and unique character markers, simplify whitespace)
    blob, // unassociated struct blob, will need to have endian data, general fallback o7
};

/// The Resource Manifest
/// For storing an active reference table for resource IDs
pub const ResourceManifest = struct {
    resource_list: std.ArrayHashMap(u32, ResourceEntry) = undefined,
    data_locations: std.ArrayList([]u8) = undefined,
    allocator: std.mem.Allocator = undefined,
    pub fn init(self: *ResourceManifest, allocator: std.mem.Allocator) !void {
        self.resource_list = std.AutoArrayHashMap(u32, ResourceEntry).init(allocator);
        self.data_locations = std.ArrayList([]u8).init(allocator);
        self.allocator = allocator;
    }
    pub fn deinit(self: *ResourceManifest) void {
        self.resource_list.deinit();
        for (self.data_locations.items) |value|
            self.allocator.free(value);
        self.data_locations.deinit();
    }
    pub fn parseManifestFile(self: *ResourceManifest, file_data: []const u8) !void {
        //manifest file will need to have manifest data and the associated archive/loose file name for each data
        //header is always "CSRM"
        if (!std.mem.eql(u8, file_data[0..4], "CSRM"))
            return error.NotAResourceManifestFile;
        //next byte is process version, starting with 0
        //future versions will bump out to dedicated functions
        if (file_data[4] == 0) {
            const num_entries = std.mem.littleToNative(u32, @as(*u32, @ptrCast(file_data[5])));
            var entry: usize = 0;
            var i: usize = 5;
            while (entry < num_entries) : (entry += 1) {
                //get length of data location assumed 16 bit length (!MUST BE RELATIVE!)
                const loc_length = std.mem.littleToNative(u32, @as(*u32, @ptrCast(file_data[i .. i + 2])));
                i += 2;
                //get data location and check against what we have, ref or add
                const location = file_data[i .. i + loc_length];
                const entry_location_index = for (self.data_locations.items, 0..) |item, ind| {
                    if (std.mem.eql(u8, item, location))
                        break ind;
                } else {
                    //duplicate and emplace
                    const new_loc = self.allocator.alloc(u8, location.len) catch
                        unreachable; //I really don't know how to safely recover from this
                    @memcpy(new_loc, location);
                    self.data_locations.append(new_loc) catch unreachable;
                    break self.data_locations.items.len - 1;
                };
                i += loc_length;

                //TODO if number of locations exceeds 1 << 32, probably panic

                //get offset and data size
                //TODO set archives to max limit of 32bits length/4GB
                const entry_offset = std.mem.littleToNative(u32, @as(*u32, @ptrCast(file_data[i .. i + 4])));
                i += 4;

                const entry_size = std.mem.littleToNative(u32, @as(*u32, @ptrCast(file_data[i .. i + 4])));
                i += 4;

                const resource_id = std.mem.littleToNative(u32, @as(*u32, @ptrCast(file_data[i .. i + 4])));
                i += 4;

                // add to entry
                const resource_entry: ResourceEntry = .{
                    .location_index = entry_location_index,
                    .offset = entry_offset,
                    .size = entry_size,
                };

                self.resource_list.put(resource_id, resource_entry);
            }
            // if extra data exists, might be a good idea to tell someone
        }
    }

    pub fn serializeManifestFile(self: ResourceManifest, allocator: std.mem.Allocator) ![]const u8 {
        _ = allocator;
        _ = self;
    }
};

/// Resource Entry is the full metadata for resource data, associated to resource ID
pub const ResourceEntry = struct {
    location_index: u32 = 0,
    offset: u32 = 0,
    size: u32 = 0,
};

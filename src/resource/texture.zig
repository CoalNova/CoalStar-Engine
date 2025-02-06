const std = @import("std");
const sys = @import("../system.zig");
const ren = @import("../render/rendersystem.zig");
const thm = @import("../threading/threadmanager.zig");
const alc = @import("../allocator.zig");
const zgl = @import("zopengl").bindings;
const zmt = @import("zmath");
const rsc = @import("resourcecollection.zig");

const _test_texture = @embedFile("../internalassets/test.bmp");
const _sprite_sheet = @embedFile("../internalassets/spritesheet.bmp");

/// Texture metadata to align with relevant GPU data
pub const Texture = struct {
    /// The hosted binding point
    /// Corelates to stack data
    bound_point: u8 = 0,
    /// The hosted index in the bound point
    /// Corelates to stack data
    bound_index: u24 = 0,
    /// size of texture
    size: @Vector(2, u32) = .{ 256, 256 },
    /// GL format of texture data
    format: ren.GLFmtType = 0,
    /// Subscribers
    subscribers: u32 = 0,
    /// Identification
    id: u32 = 0,
    /// Optional bind for texel data
    texels: ?Texels = .{},
};

/// Intermediate texture carrier for locating placement
const Texels = struct {
    /// size of texture
    size: @Vector(2, u32) = .{ 512, 512 },
    /// GL format of texture data
    format: ren.GLFmtType = 0,
    /// Raw texel data
    texel_data: []u8 = undefined,
    /// Allocator for Texeldata
    allocator: std.mem.Allocator = undefined,
};

/// Stack sub-collection to represent GPU texture memory layout
/// It is itself the "Texture" object, with textures taking up array positions within
const Column = struct {
    /// GL name
    name: ren.GLTexName = 0,
    /// dimensions
    size: @Vector(2, u32) = .{},
    /// Compression/Pixel type
    format: ren.GLFmtType = 0,
    /// Sizeof for format
    format_sizeof: u8 = 2,
    /// How many texture arrray slots are in use
    count: u24 = 0,
    /// The Textures within the column, based on index in resource collection
    textures: []Texture = undefined,
};

///The container for bitmap data
pub const Bitmap = struct {
    ///The size of this header, in bytes (40)
    header_size: u32 = 0,
    ///The bitmap width in pixels (signed integer)
    width: u32 = 0,
    ///The bitmap height in pixels (signed integer)
    height: u32 = 0,
    ///The number of color planes (must be 1)
    color_planes: u16 = 0,
    ///The number of bits per pixel, which is the color depth of the image. Typical values are 1, 4, 8, 16, 24 and 32.
    bpp: u16 = 0,
    ///The compression method being used. See the next table for a list of possible values
    compression: u32 = 0,
    ///The image size. This is the size of the raw bitmap data; a dummy 0 can be given for BI_RGB bitmaps.
    size: u32 = 0,
    ///Image bitmap image raw data
    pixel_data: []u8 = undefined,
};

/// Options for initializing the texture stack
pub const StackOptions = struct {
    /// Initial Column size for texture metadata
    initial_size: u16 = 4,
    /// The power for the largest texture size, by axis
    /// Textures need be power of two in size, and perfectly square
    /// 9 = 512, 10 = 1024, 11 = 2048,
    required_max_magnitude: u8 = 10,
    /// The power for the smallest texture size, by axis
    required_min_magnitude: u8 = 8,
};

/// The texture stack object
/// Mirrors behavior and names of the generis ResourceCollection template
const Stack = struct {
    /// Columns for storing texture metadata
    _columns: []Column = undefined,
    /// Persistant allocator
    _allocator: std.mem.Allocator = undefined,
    ///
    _keyref: std.AutoHashMap(u32, u32) = undefined,

    pub fn init(
        self: *Stack,
        stack_options: StackOptions,
        allocator: std.mem.Allocator,
    ) !void {
        self._allocator = allocator;
        const points =
            if (ren.max_tex_binding_points < 0)
            1
        else
            @as(u32, @intCast(ren.max_tex_binding_points));

        self._columns = try self._allocator.alloc(Column, points);

        for (self._columns, 0..) |*column, i| {
            column.textures = try allocator.alloc(Texture, stack_options.initial_size);
            const mag = 1 << @max(stack_options.required_min_magnitude, stack_options.required_max_magnitude - i);
            column.size = @Vector(2, f32){ mag, mag };
            column.format_set = zgl.RGBA;
            column.format = zgl.RGB5_A1;
            try thm.render_thread.queue.put(thm.Job{
                .payload = @intCast(i),
                .task = initializeColumn,
            });
        }
        self._keyref = std.AutoHashMap(u32, u32).init(self._allocator);
    }

    pub fn deinit(self: *Stack) void {
        for (self._columns) |column| {
            zgl.deleteTextures(1, &column.name);
            self._allocator.free(column.textures);
        }
        self._allocator.free(self._columns);
    }

    /// Returns the index of a texture matching the provided index
    /// Will generate and place texture if none exists
    pub fn fetch(self: *Stack, r_ids: []const rsc.ResourceID) u32 {
        const id = r_ids[0].uid;
        // Check if exists
        if (self._keyref.get(id)) |index| {
            if (sys.DEBUG_MODE) {
                if (self.peek(index).id != id)
                    @panic("Texture index does not match itself, resource breach occured!");
            }
            self.peek(index).subscribers += 1;
            return index;
        }
        // else create new

        // TODO resource meta header will need to maintain texture size for initial stack placement
        // TODO likely will need to hold all relevant Texture details aside from offset/index
        // TODO size(2*4) + fmt(4) + ID(4) = 16 bytes per record header
        // TODO format will need to cascade downwards, though likely be maintained across all
        // TODO assumes that format and size matches one of the columns, probs should verify it
        var tex: Texture = .{ .id = id };
        defer thm.render_thread.queue.put(thm.Job{
            .payload = id,
            .task = insertTexture,
        }) catch |err| {
            std.log.err("Render thread queue could not be added to: {!}", .{err});
        };
        defer loadTexture(id);

        // find matching column for texture based on size, format and type, retaining the lowest count
        var column_index: i32 = -1;
        var count: u32 = std.math.maxInt(u32);
        for (self._columns, 0..) |*column, i|
            if (column.count < count and
                (column.size == tex.size)[0] and
                (column.size == tex.size)[1] and
                column.count < column.textures.len and
                column.format == tex.format)
            {
                column_index = @intCast(i);
                count = column.count;
            };

        if (column_index >= 0) {
            const column = &stack._columns[@intCast(column_index)];
            tex.bound_index = @intCast(column_index);
            tex.bound_point = @intCast(column.count);
            column.textures[column.count] = tex;
            column.count += 1;
            const index = (@as(u32, tex.bound_point) << 24) + @as(u32, tex.bound_index);
            // index is a sum of u8 for column index/binding point and u24 for array index/offset
            self._keyref.put(id, index) catch |err| {
                std.log.err("{!}", .{err});
            };
            return index;
        }

        // all columns full find first unused texture
        for (self._columns, 0..) |c, i| {
            // const to hold result of size equivelance
            const b = c.size == tex.size;
            if (c.format == tex.format and b[0] and b[1]) {
                for (c.textures, 0..) |t, j| {
                    if (t.subscribers < 1) {
                        if (sys.DEBUG_MODE) {
                            if (t.subscribers < 0)
                                std.log.err("Texture id:{d} breached", .{t.id});
                        }
                        tex.bound_index = @intCast(i);
                        tex.bound_point = @intCast(j);

                        c.textures[j] = tex;
                        const index = (@as(u32, tex.bound_point) << 24) + @as(u32, tex.bound_index);
                        // index is a sum of u8 for column index/binding point and u24 for array index/offset
                        _ = self._keyref.remove(t.id);
                        self._keyref.put(id, index) catch unreachable;
                        return index;
                    }
                }
            }
        }

        // finally, resize collection
        count = std.math.maxInt(u32);
        for (self._columns, 0..) |c, i| {
            const b = c.size == tex.size;
            if (c.format == tex.format and b[0] and b[1]) {
                if (c.count < count) {
                    count = c.count;
                    column_index = @intCast(i);
                }
            }
        }

        // Assume failure occured and return default value
        if (column_index < 0) {
            @panic("Column failure! Could not locate column adequate for texture in stack!");
        }

        //resize
        const column = &self._columns[@intCast(column_index)];
        const column_textures = column.textures;

        const new_column_textures = self._allocator.alloc(
            Texture,
            column_textures.len * 2,
        ) catch |err| {
            std.log.err("Texture column allocation failed: {!}", .{err});
            @panic("Unable to recover from Texture resize allocation failure");
        };
        @memcpy(new_column_textures, column_textures);
        column.textures = new_column_textures;
        self._allocator.free(column_textures);

        column.textures[count] = tex;
        const tex_index = (@as(u32, @intCast(column_index)) << 24) + count;

        thm.render_thread.queue.put(thm.Job{
            .payload = @intCast(column_index),
            .task = resizeColumn,
        }) catch |err| {
            std.log.err("Render queue failed put-ing: {!}", .{err});
        };

        self._keyref.put(id, tex_index) catch |err| {
            std.log.err("Hashmap error: {!}", .{err});
            @panic("Hashmap Failure!");
        };
        return tex_index;
    }

    pub fn release(self: *Stack, index: u32) !void {
        self._columns[index >> 24].textures[index & ((1 << 24) - 1)].subscribers -= 1;
    }

    pub fn peek(self: *Stack, index: u32) *Texture {
        const texture = &self._columns[index >> 24].textures[index & ((1 << 24) - 1)];
        if (sys.DEBUG_MODE) {
            if (texture.subscribers < 1)
                std.log.err(
                    "Texture id:{d} is accessed after losing all subscribers!",
                    .{texture.id},
                );
        }
        return texture;
    }
    pub fn peekByID(self: *Stack, id: u32) ?*Texture {
        const index = self._keyref.get(id);
        if (index) |i|
            return self.peek(i);
        return null;
    }
};

pub var stack: Stack = .{};

pub fn init(stack_options: StackOptions, allocator: std.mem.Allocator) !void {
    try stack.init(stack_options, allocator);
}

pub fn deinit() void {
    stack.deinit();
}

/// Generates a single u32 for texture indexing
inline fn stackIndex(column_index: u8, texture_index: u24) u32 {
    return (@as(u32, texture_index) << 24) + column_index;
}

pub fn initializeColumn(column_index: ?u32) !void {
    if (column_index) |index| {

        // Activate binding point
        zgl.activeTexture(zgl.TEXTURE0 + column_index);

        const column = &stack._columns[index];
        // create texture
        zgl.genTextures(1, &column.name);
        ren.checkGLError("GL genTextures Column Initialization");

        zgl.bindTexture(zgl.TEXTURE_2D_ARRAY, column.name);
        ren.checkGLError("Bind column tetxture");

        zgl.texParameteri(zgl.TEXTURE_2D, zgl.TEXTURE_MIN_FILTER, zgl.NEAREST);
        zgl.texParameteri(zgl.TEXTURE_2D, zgl.TEXTURE_MAG_FILTER, zgl.NEAREST);
        zgl.texParameteri(zgl.TEXTURE_2D, zgl.TEXTURE_WRAP_S, zgl.MIRRORED_REPEAT);
        zgl.texParameteri(zgl.TEXTURE_2D, zgl.TEXTURE_MIN_FILTER, zgl.LINEAR_MIPMAP_LINEAR);
        zgl.texParameteri(zgl.TEXTURE_2D, zgl.TEXTURE_MAG_FILTER, zgl.LINEAR);

        // generate with onboarded settings
        zgl.texImage3D(
            zgl.TEXTURE_2D_ARRAY,
            0,
            column.format_set,
            column.size[0],
            column.size[1],
            @as(isize, @intCast(column.textures.len)),
            0,
            column.format,
            column.format_type,
            null,
        );
        // pray
    }
}

pub fn loadTexture(id: ?u32) void {
    if (id) |tex_id| {
        const tex = stack.peekByID(tex_id);
        if (tex) |texture| {
            var texels: Texels = .{};

            // resolve rawdata from ID
            // TODO this, unfortunately
            // TODO resource lookup table propogated in fileio? new resource file?

            // TODO if fails, resolve back to default (0x00000000)
            const bmp = bitmapFromFile(_test_texture, alc.tsf) catch unreachable;
            defer alc.tsf.free(bmp.pixel_data);

            const format_len = resolveFormatByteSize(texture.format);

            texels.texel_data = alc.tsa.alloc(u8, bmp.size * format_len) catch |err| {
                std.log.err("Allocation for texel data failed: {!}", .{err});
                return;
            };

            // translate texture to format, if not already (or offboard?)
            const bytes_per_pixel = (bmp.bpp / 8);
            for (0..(bmp.size / bytes_per_pixel)) |i| {
                const texel_index = i * format_len;
                _ = texel_index;
            }

            // push texels to (sub) texture
        }
    }
}

pub fn resizeColumn(column_index: ?u32) void {
    if (column_index) |index| {
        const column = &stack._columns[index];

        // activate and bind texture
        zgl.activeTexture(zgl.TEXTURE0 + index);
        zgl.bindTexture(zgl.TEXTURE_2D_ARRAY, column.name);

        // get texture data
        // assume texture data is RGB5A1 == Word
        // OOM here is also unrecoverable
        const bucket = alc.tsf.alloc(
            u8,
            column.size[0] * column.size[1] * column.textures.len,
        ) catch unreachable;
        defer alc.tsf.free(bucket);

        zgl.getTexImage(
            zgl.TEXTURE_2D_ARRAY,
            0,
            column.format,
            resolveFormatType(column.format),
            bucket.ptr,
        );

        // destroy column texture array
        zgl.deleteTextures(1, &column.name);

        // make new column texture array
        zgl.genTextures(1, &column.name);

        // bind and pump
        zgl.texImage3D(
            zgl.TEXTURE_2D_ARRAY,
            0,
            resolveFormatSet(column.format),
            @intCast(column.size[0]),
            @intCast(column.size[1]),
            @intCast(column.textures.len),
            0,
            column.format,
            resolveFormatType(column.format),
            null,
        );

        zgl.texSubImage3D(
            zgl.TEXTURE_2D_ARRAY,
            0,
            0,
            0,
            0,
            @intCast(column.size[0]),
            @intCast(column.size[1]),
            @intCast(bucket.len / resolveFormatByteSize(column.format)),
            column.format,
            resolveFormatType(column.format),
            bucket.ptr,
        );
    }
}

pub fn insertTexture(id: ?u32) void {
    if (id) |_id| {

        // get texture
        const texture = stack.peekByID(_id);
        if (texture) |tex_ptr| {
            if (tex_ptr.texels) |texels| {
                const column = stack._columns[tex_ptr.bound_point];

                // bind column
                zgl.activeTexture(zgl.TEXTURE0 + @as(u32, @intCast(tex_ptr.bound_point)));
                ren.checkGLError("Activate Texture for texSubImage3D");
                zgl.bindTexture(
                    zgl.TEXTURE_2D_ARRAY,
                    column.name,
                );
                ren.checkGLError("Bind Texture for texSubImage3D");

                // pass texture as subtexture to opengl

                zgl.texSubImage3D(
                    zgl.TEXTURE_2D_ARRAY,
                    0,
                    0,
                    0,
                    tex_ptr.bound_index,
                    @intCast(tex_ptr.size[0]),
                    @intCast(tex_ptr.size[1]),
                    1,
                    texels.format,
                    resolveFormatType(texels.format),
                    texels.texel_data.ptr,
                );

                zgl.generateMipmap(zgl.TEXTURE_2D);

                // remove local texeldata
                texels.allocator.free(texels.texel_data);
                tex_ptr.texels = null;

                return;
            }
        }
        std.log.err("Texture for id:{d} requested insertion but could not be found.", .{_id});
    }
}

/// Converts a supplied bitmap into a supplied Texture
/// injecting the texel data directly
pub fn bitmapToTexels(bmp: Bitmap, format: ren.GLFmt, allocator: std.mem.Allocator) !Texels {
    const pixel_size = (bmp.bpp / 8);
    if (sys.DEBUG_MODE) {
        if (pixel_size < 1)
            return error.IncorrectBitmapBPP;
    }
    const texel_size = resolveFormatByteSize(format);

    var texels: Texels = .{
        .allocator = allocator,
        .format = format,
        .size = .{ bmp.width, bmp.height },
    };
    texels.texel_data = try allocator.alloc(u8, texel_size * texels.size);
    errdefer allocator.free(texels.texel_data);
    for (0..bmp.width * bmp.height) |p| {
        const b_i = p * pixel_size;
        const t_i = p * texel_size;
        switch (format) {
            // to GL_R8
            zgl.R8, zgl.R8UI => {
                switch (pixel_size) {
                    //A8R8G8B8
                    4 => texels.texel_data[t_i] = bmp.pixel_data[b_i + 1],
                    //R8G8B8 and Single Channel
                    3, 1 => texels.texel_data[t_i] = bmp.pixel_data[b_i],
                    else => return error.UnsuportedBitmapPixelFormat,
                }
            },
            // to GL_RG8
            zgl.RG8, zgl.RG8UI => {
                switch (pixel_size) {
                    //A8R8G8B8 to GL_R8
                    4 => {
                        texels.texel_data[t_i] = bmp.pixel_data[b_i + 1];
                        texels.texel_data[t_i + 1] = bmp.pixel_data[b_i + 2];
                    },
                    //R8G8B8 to GL_R8
                    3 => {
                        texels.texel_data[t_i] = bmp.pixel_data[b_i];
                        texels.texel_data[t_i + 1] = bmp.pixel_data[b_i + 1];
                    },
                    //Single Channel upshift?
                    1 => {
                        if (sys.DEBUG_MODE)
                            std.log.warn("Upmixing a single channel texture to dual.", .{});
                        texels.texel_data[t_i] = bmp.pixel_data[b_i];
                        texels.texel_data[t_i + 1] = bmp.pixel_data[b_i];
                    },
                    else => return error.UnsuportedBitmapPixelFormat,
                }
            },
            // to GL_RGB8
            zgl.RGB8, zgl.RGB8UI => {
                switch (pixel_size) {
                    //A8R8G8B8
                    4 => {
                        texels.texel_data[t_i] = bmp.pixel_data[b_i + 1];
                        texels.texel_data[t_i + 1] = bmp.pixel_data[b_i + 2];
                        texels.texel_data[t_i + 2] = bmp.pixel_data[b_i + 3];
                    },
                    //R8G8B8
                    3 => {
                        texels.texel_data[t_i] = bmp.pixel_data[b_i];
                        texels.texel_data[t_i + 1] = bmp.pixel_data[b_i + 1];
                        texels.texel_data[t_i + 2] = bmp.pixel_data[b_i + 2];
                    },
                    //Single Channel upshift?
                    1 => {
                        if (sys.DEBUG_MODE)
                            std.log.warn("Upmixing a single channel texture to triple.", .{});
                        texels.texel_data[t_i] = bmp.pixel_data[b_i];
                        texels.texel_data[t_i + 1] = bmp.pixel_data[b_i];
                        texels.texel_data[t_i + 2] = bmp.pixel_data[b_i];
                    },
                    else => return error.UnsuportedBitmapPixelFormat,
                }
            },
            // to RGBA8
            zgl.RGBA8, zgl.RGBA8UI => {
                switch (pixel_size) {
                    //A8R8G8B8
                    4 => {
                        texels.texel_data[t_i] = bmp.pixel_data[b_i + 1];
                        texels.texel_data[t_i + 1] = bmp.pixel_data[b_i + 2];
                        texels.texel_data[t_i + 2] = bmp.pixel_data[b_i + 3];
                        texels.texel_data[t_i + 3] = bmp.pixel_data[b_i];
                    },
                    //R8G8B8
                    3 => {
                        if (sys.DEBUG_MODE)
                            std.log.warn("Upmixing an Alphaless format to an Alpha format", .{});
                        texels.texel_data[t_i] = bmp.pixel_data[b_i];
                        texels.texel_data[t_i + 1] = bmp.pixel_data[b_i + 1];
                        texels.texel_data[t_i + 2] = bmp.pixel_data[b_i + 2];
                        texels.texel_data[t_i + 3] = 255; // default full alpha
                    },
                    //Single Channel upshift?
                    1 => {
                        if (sys.DEBUG_MODE)
                            std.log.warn("Upmixing a single channel texture to quad.", .{});
                        texels.texel_data[t_i] = bmp.pixel_data[b_i];
                        texels.texel_data[t_i + 1] = bmp.pixel_data[b_i];
                        texels.texel_data[t_i + 2] = bmp.pixel_data[b_i];
                        // default single channel to copy into alpha
                        texels.texel_data[t_i + 3] = bmp.pixel_data[b_i];
                    },
                    else => return error.UnsuportedBitmapPixelFormat,
                }
            },
            else => return error.UnsupportedTextureFormat,
        }
    }

    return texels;
}

pub fn loadDDS(raw_buffer: []u8, texture: *Texture, allocator: std.mem.Allocator) ![]u8 {
    if (!std.mem.eql(u8, "DDS ", raw_buffer[0..4])) {
        std.log.err("Provided data buffer not pf type DDS", .{});
        return error.WrongFileType;
    }

    const readInt = std.mem.readInt;

    // generating OS used little endian
    texture.dimensions = .{
        .x = readInt(i32, raw_buffer[8..12], .little),
        .y = readInt(i32, raw_buffer[12..16], .little),
    };
    const tex_size = readInt(u64, raw_buffer[16..24], .little);
    texture.px_b_size = @intCast(@divExact(tex_size, @as(
        u64,
        @intCast(texture.dimensions.x * texture.dimensions.y),
    )));

    if (raw_buffer[80] != 'D') // DXT
    {
        std.log.err("Mismatch of compression type or file corruption.", .{});
        return error.WrongCompression;
    }

    texture.tex_format = switch (raw_buffer[83]) {
        '1' => //DXT1
        zgl.COMPRESSED_RGBA_S3TC_DXT1_EXT,
        '3' => //DXT3
        zgl.COMPRESSED_RGBA_S3TC_DXT3_EXT,
        '5' => //DXT5
        zgl.COMPRESSED_RGBA_S3TC_DXT5_EXT,
        else => {
            std.log.err("Incorrect compression type for texture processing", .{});
            return error.WrongCompression;
        },
    };

    var tex_buffer = try allocator.alloc(u8, tex_size);
    for (raw_buffer[124..], 0..) |c, i| tex_buffer[c] = i;

    return tex_buffer;
}

/// Propagates Bitmap Header and data fields from a raw file as a struct
pub fn bitmapFromFile(raw_buffer: []const u8, allocator: std.mem.Allocator) !Bitmap {
    if (!std.mem.eql(u8, raw_buffer[0..2], "BM"))
        return error.InvalidBMPFile;

    const data_start: u32 = std.mem.readInt(u32, raw_buffer[10..14], .little);

    var bmp: Bitmap = .{};
    bmp.header_size = std.mem.readInt(u32, raw_buffer[14..18], .little);
    bmp.width = std.mem.readInt(u32, raw_buffer[18..22], .little);
    bmp.height = std.mem.readInt(u32, raw_buffer[22..26], .little);
    bmp.color_planes = std.mem.readInt(u16, raw_buffer[26..28], .little);
    bmp.bpp = std.mem.readInt(u16, raw_buffer[28..30], .little);
    bmp.compression = std.mem.readInt(u32, raw_buffer[30..34], .little);
    bmp.size = std.mem.readInt(u32, raw_buffer[34..38], .little);

    bmp.pixel_data = try allocator.alloc(u8, bmp.size);
    @memcpy(bmp.pixel_data, raw_buffer[data_start .. data_start + bmp.size]);
    return bmp;
}

pub inline fn resolveFormatSet(gl_format: ren.GLFmt) ren.GLFmtSet {
    return switch (gl_format) {
        zgl.R8,
        zgl.R8I,
        zgl.R8UI,
        zgl.R8_SNORM,
        zgl.R16,
        zgl.R16I,
        zgl.R16UI,
        zgl.R16F,
        zgl.R32F,
        zgl.R32I,
        zgl.R32UI,
        => zgl.RED,
        zgl.RG8,
        zgl.RG8_SNORM,
        zgl.RG8I,
        zgl.RG8UI,
        zgl.RG16,
        zgl.RG16F,
        zgl.RG16I,
        zgl.RG16UI,
        zgl.RG16_SNORM,
        zgl.RG32F,
        zgl.RG32I,
        zgl.RG32UI,
        => zgl.RG,
        zgl.RGB8,
        zgl.RGB8_SNORM,
        zgl.RGB8I,
        zgl.RGB8UI,
        zgl.RGB16,
        zgl.RGB16F,
        zgl.RGB16I,
        zgl.RGB16UI,
        zgl.RGB16_SNORM,
        zgl.RGB32F,
        zgl.RGB32I,
        zgl.RGB32UI,
        zgl.R3_G3_B2,
        zgl.RGB10_A2,
        zgl.RGB10_A2UI,
        zgl.RGB565,
        zgl.RGB9_E5,
        => zgl.RGB,
        zgl.RGBA8,
        zgl.RGBA8_SNORM,
        zgl.RGBA8I,
        zgl.RGBA8UI,
        zgl.RGBA16,
        zgl.RGBA16F,
        zgl.RGBA16I,
        zgl.RGBA16UI,
        zgl.RGBA16_SNORM,
        zgl.RGBA32F,
        zgl.RGBA32I,
        zgl.RGBA32UI,
        zgl.RGB5_A1,
        => zgl.RGBA,
        else => @panic("Cannot Resolve unlisted format!"),
    };
}

pub inline fn resolveFormatType(gl_format: ren.GLFmt) ren.GLFmtType {
    return switch (gl_format) {
        zgl.R8UI,
        zgl.RG8UI,
        zgl.RGB8UI,
        zgl.RGBA8UI,
        zgl.R8,
        zgl.R8_SNORM,
        zgl.RG8,
        zgl.RG8_SNORM,
        zgl.RGB8,
        zgl.RGB8_SNORM,
        zgl.RGBA8,
        zgl.RGBA8_SNORM,
        => zgl.UNSIGNED_BYTE,
        zgl.R16UI,
        zgl.RG16UI,
        zgl.RGB16UI,
        zgl.RGBA16UI,
        zgl.R16,
        zgl.RG16,
        zgl.RG16_SNORM,
        zgl.RGB16,
        zgl.RGB16_SNORM,
        zgl.RGBA16,
        zgl.RGBA16_SNORM,
        => zgl.UNSIGNED_SHORT,
        zgl.R32UI,
        zgl.RG32UI,
        zgl.RGB32UI,
        zgl.RGBA32UI,
        => zgl.UNSIGNED_INT,
        zgl.R8I,
        zgl.RG8I,
        zgl.RGB8I,
        zgl.RGBA8I,
        => zgl.BYTE,
        zgl.R16I,
        zgl.RG16I,
        zgl.RGB16I,
        zgl.RGBA16I,
        => zgl.SHORT,
        zgl.R32I,
        zgl.RG32I,
        zgl.RGB32I,
        zgl.RGBA32I,
        => zgl.INT,
        zgl.R16F,
        zgl.RG16F,
        zgl.RGB16F,
        zgl.RGBA16F,
        => zgl.HALF_FLOAT,
        zgl.R32F,
        zgl.RG32F,
        zgl.RGB32F,
        zgl.RGBA32F,
        => zgl.FLOAT,
        zgl.R3_G3_B2,
        => zgl.UNSIGNED_BYTE_3_3_2,
        zgl.RGB10_A2,
        zgl.RGB10_A2UI,
        => zgl.UNSIGNED_INT_10_10_10_2,
        zgl.RGB565,
        => zgl.UNSIGNED_SHORT_5_6_5,
        zgl.RGB9_E5,
        => zgl.UNSIGNED_INT_5_9_9_9_REV,
        zgl.RGB5_A1,
        => zgl.UNSIGNED_SHORT_5_5_5_1,
        else => @panic("Cannot Resolve unlisted format!"),
    };
}

pub inline fn resolveFormatByteSize(gl_format: ren.GLFmt) u32 {
    return switch (gl_format) {
        zgl.R8,
        zgl.R8I,
        zgl.R8UI,
        zgl.R8_SNORM,
        zgl.R3_G3_B2,
        => 1,
        zgl.R16,
        zgl.R16I,
        zgl.R16F,
        zgl.R16UI,
        zgl.RG8,
        zgl.RG8I,
        zgl.RG8UI,
        zgl.RG8_SNORM,
        zgl.RGB565,
        zgl.RGB5_A1,
        => 2,
        zgl.RGB8,
        zgl.RGB8I,
        zgl.RGB8UI,
        zgl.RGB8_SNORM,
        => 3,
        zgl.RGBA8,
        zgl.RGBA8I,
        zgl.RGBA8UI,
        zgl.RGBA8_SNORM,
        zgl.RG16,
        zgl.RG16I,
        zgl.RG16F,
        zgl.RG16UI,
        zgl.R32I,
        zgl.R32F,
        zgl.R32UI,
        zgl.RG16_SNORM,
        zgl.RGB10_A2,
        zgl.RGB10_A2UI,
        zgl.RGB9_E5,
        => 4,
        zgl.RGB16,
        zgl.RGB16I,
        zgl.RGB16F,
        zgl.RGB16UI,
        zgl.RGB16_SNORM,
        => 6,
        zgl.RGBA16,
        zgl.RGBA16I,
        zgl.RGBA16F,
        zgl.RGBA16UI,
        zgl.RGBA16_SNORM,
        zgl.RG32I,
        zgl.RG32F,
        zgl.RG32UI,
        => 8,
        zgl.RGB32I,
        zgl.RGB32F,
        zgl.RGB32UI,
        => 12,
        zgl.RGBA32I,
        zgl.RGBA32F,
        zgl.RGBA32UI,
        => 16,
        else => @panic("Cannot Resolve unlisted format!"),
    };
}

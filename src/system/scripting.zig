const std = @import("std");
const zlu = @import("ziglua");
const alc = @import("../allocator.zig");
const sys = @import("../system.zig");

var lua_engine: *zlu.Lua = undefined;

const LuaError = error{
    LUA_OK,
    LUA_ERRRUN,
    LUA_ERRMEM,
    LUA_ERRERR,
    LUA_ERRSYNTAX,
    LUA_YIELD,
    LUA_ERRFILE,
};

pub fn init() !void {

    // Initialize the Lua vm
    lua_engine = try zlu.Lua.init(&alc.gpa);

    lua_engine.openLibs();

    try lua_engine.doString(test_string);
    sys.setStateOn(.script);
}

pub fn deinit() void {
    lua_engine.deinit();
    sys.setStateOff(.script);
}

pub fn proc() LuaError!void {
    if (!lua_engine.gcIsRunning()) {
        lua_engine.gcCollect();
    }
}

const test_string = "print(\"Lua says: hello!\")";

fn getLuaError() !void {
    const status = lua_engine.status();
    switch (status) {
        .err_error => {
            std.log.err("Lua encountered an error with the message handler.", .{});
            return LuaError.LUA_ERRERR;
        },
        .err_memory => {
            std.log.err("Lua encountered a memory error, message handler unavailable.", .{});
            return LuaError.LUA_ERRMEM;
        },
        .err_runtime => {
            std.log.err("Lua encountered a runtime error.", .{});
            return LuaError.LUA_ERRRUN;
        },
        .err_syntax => {
            std.log.err("Lua encountered a syntax error.", .{});
            return LuaError.LUA_ERRSYNTAX;
        },
        .yield => {},
        .ok => {}, // what we always want
    }
}

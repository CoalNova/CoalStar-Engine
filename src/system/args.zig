const std = @import("std");
const fio = @import("fileio.zig");
const alc = @import("../allocator.zig");

const Flags = enum(u8) {
    none = 99,
    help = 0,
    gl = 1,
    window = 2,
};

/// A collection of Flags to denote following options
const FlagsStrings = [_][]const u8{
    "-h",
    "-H",
    "--H",
    "--h",
    "-gl",
    "-GL",
    "--gl",
    "--GL",
    "-w",
    "-W",
    "--w",
    "--W",
};

/// Returns the flag from a provided string
fn getFlagFromString(string: []const u8) Flags {
    //matches
    for (FlagsStrings, 0..) |flag, i| {
        if (std.mem.eql(u8, flag, string))
            return @as(Flags, @enumFromInt(@as(u8, @intCast(i >> 2))));
    }
    return .none;
}

pub fn parseArgs() !void {
    const args = try std.process.argsAlloc(alc.fba);
    defer std.process.argsFree(alc.fba, args);
    var flag: Flags = .none;
    args_block: for (args, 0..) |arg, i| {
        if (i == 0)
            continue :args_block;

        for (Flags) |f| {
            // check if setting flag
            if (std.mem.eql(u8, arg, FlagsStrings(f))) {
                if (f == .help) {
                    printHelp(flag);
                } else flag = f;
                std.debug.print("Yay\n", .{});
                continue :args_block;
            }

            // act upon state flag
            switch (flag) {
                .help => printHelp(flag),
                .none => printInvalidArg(arg),
                .gl => {
                    switch (arg[0]) {
                        'M' => {},
                        'm' => {},
                        'p' => {},
                        'v' => {},
                        'b' => {},
                        'c' => {},
                        'z' => {},
                    }
                },
                .window => {},
            }
        }
    }
}

pub inline fn printHelp(flag: Flags) !void {
    try fio.print(
        "{s}\n",
        .{switch (flag) {
            .help => {
                "Coalstar(.exe) Flag [Options (Options ...)] (Flag [Options (Options ...)]) \n" ++
                    "Flags:\n" ++
                    "\t-h Prints this help page\n" ++
                    "\t-gl sets gl options\n" ++
                    "\t-w sets window options\n";
            },
            .gl => {
                "\t GL Rendering Options\n" ++
                    "'M=...' integer, sets major version of GL spec (default is 3)\n" ++
                    "'m=...' integer, sets minor version of GL spec (default is 3)\n" ++
                    "'p=...' string, sets poly render mode [fill, line, point] (default is fill)\n" ++
                    "'v=...' string, sets initial vertical sync mode [none, single, double, triple] (default is single)" ++
                    "'b=...' string, sets blending mode [true, false] (default is true)" ++
                    "'c=...' string, sets culling rules [none, front, back] (default is back)" ++
                    "'z=...' string, sets depth test rules [none, front, back] (default is back)";
            },
        }},
    );
}
pub inline fn printInvalidArg(arg: [:0]u8) !void {
    try fio.print("Invalid Argument: {any}", .{arg});
}

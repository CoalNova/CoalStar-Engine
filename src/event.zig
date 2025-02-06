const std = @import("std");
const sdl = @import("zsdl");
pub const Scancode = sdl.Scancode;
const sys = @import("system.zig");
const wnd = @import("window.zig");

/// Input struct contains the possible source of the input, a value associated to ID the input,
/// and and a state for that input
pub const Input = struct {
    input_type: InputType = InputType.keyboard,
    input_id: u32 = 0,
    input_state: InputState = InputState.none,
};

/// Input State to store in the input is
pub const InputState = enum(u2) {
    /// None: input is in no way being fiddled with
    none = 0b00,
    /// Down: input is freshly depressed
    down = 0b01,
    /// Stay: input has retained a depressed state
    stay = 0b10,
    /// Left: input has been freshly relieved of pressure
    left = 0b11,
};

/// Input Type
/// This associates roughly to SDL's input options
pub const InputType = enum(u8) {
    keyboard = 0,
    mouse = 1,
    joypad = 2,
    window = 3,
    system = 4,
};

// input stack
var inputs: [64]Input = [_]Input{.{}} ** 64;

/// Process all SDL events, and update Inputs accordingly
pub fn processEvents() !void {
    // but first update the states of the keys in the stack
    // to remove expired states
    advanceInputs();
    var event: sdl.Event = undefined;
    while (sdl.pollEvent(&event)) {
        switch (event.type) {
            sdl.EventType.quit => sys.setStateOff(sys.EngineState.alive),
            sdl.EventType.keydown => {
                const input = .{
                    .input_state = InputState.down,
                    .input_type = InputType.keyboard,
                    .input_id = @intFromEnum(event.key.keysym.scancode),
                };
                updateInput(input);
            },
            sdl.EventType.keyup => {
                const input = .{
                    .input_state = InputState.left,
                    .input_type = InputType.keyboard,
                    .input_id = @intFromEnum(event.key.keysym.scancode),
                };
                updateInput(input);
            },
            else => {},
        }
    }
    // process mouse inputs
    for (wnd.windows) |*window| {
        window.mouse.procInputs();
    }
}

/// Updates states, if down then stay, if left then none
fn advanceInputs() void {
    for (&inputs) |*i| {
        if (i.input_state == InputState.left)
            i.input_state = InputState.none;
        if (i.input_state == InputState.down)
            i.input_state = InputState.stay;
    }
}

/// Updates the supplied input based on the input provided
fn updateInput(input: Input) void {
    // first see if ours already exists in the list
    for (&inputs) |*i|
        if (i.input_type == input.input_type and i.input_id == input.input_id) {
            switch (input.input_state) {
                InputState.down => {
                    switch (i.input_state) {
                        InputState.none => i.input_state = InputState.down,
                        InputState.down => i.input_state = InputState.stay,
                        InputState.stay => i.input_state = InputState.stay,
                        InputState.left => i.input_state = InputState.down,
                    }
                },
                InputState.left => {
                    switch (i.input_state) {
                        InputState.none => i.input_state = InputState.none,
                        InputState.down => i.input_state = InputState.left,
                        InputState.stay => i.input_state = InputState.left,
                        InputState.left => i.input_state = InputState.none,
                    }
                },
                else => {},
            }
            // we're done if so
            return;
        };

    // otherwise overwrite the first inactive state
    for (&inputs) |*i| {
        if (i.input_state == InputState.none) {
            i.input_state = input.input_state;
            i.input_id = input.input_id;
            i.input_type = input.input_type;
            return;
        }
    }

    //else cry becuse too many Inputs
    std.log.warn("Input stack full of active states?\n", .{});
}

/// Returns the InputState of the supplied input type and ID
pub fn getInput(input_type: InputType, input_id: u32) InputState {
    var state = InputState.none;
    input_blk: for (inputs) |i| {
        if (i.input_type == input_type and i.input_id == input_id) {
            state = i.input_state;
            break :input_blk;
        }
    }
    return state;
}

/// Returns if an provided input type and ID has a state matching "Down"
pub inline fn getInputDown(input: Input) bool {
    return (getInput(input.input_type, input.input_id) == InputState.down);
}
/// Returns if an provided input type and ID has a state matching "Left"
pub inline fn getInputLeft(input: Input) bool {
    return (getInput(input.input_type, input.input_id) == InputState.left);
}
/// Returns if an provided input type and ID has a state matching "Stay"
pub inline fn getInputStay(input: Input) bool {
    return (getInput(input.input_type, input.input_id) == InputState.stay);
}
/// Returns if an provided input type and ID has a state matching "None"
pub inline fn getInputNone(input: Input) bool {
    return (getInput(input.input_type, input.input_id) == InputState.none);
}

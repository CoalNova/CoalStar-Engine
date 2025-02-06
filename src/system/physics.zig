const std = @import("std");
const zph = @import("zphysics");
const zmt = @import("zmath");
const alc = @import("../allocator.zig");
const sys = @import("../system.zig");

// allocator appropriate for physics?

// physics containers?
const Phystainer = struct {
    physics_system: *zph.PhysicsSystem = undefined,
    broad_phase_layer_interface: *BroadPhaseLayerInterface = undefined,
    object_vs_broad_phase_layer_filter: *ObjectVsBroadPhaseLayerFilter = undefined,
    object_layer_pair_filter: *ObjectLayerPairFilter = undefined,
    contact_listener: *ContactListener = undefined,
    body_interface: *zph.BodyInterface = undefined,
    lock_interface: *const zph.BodyLockInterface = undefined,
    collision_group: zph.CollisionGroup = .{
        .group_id = @as(c_uint, 1),
        .sub_group_id = @as(c_uint, 1),
    },
};

var phys = Phystainer{};

/// Initialize Physics World and Cube Physics Template?
pub fn init() !void {
    phys.broad_phase_layer_interface = try alc.gpa.create(BroadPhaseLayerInterface);
    phys.object_vs_broad_phase_layer_filter = try alc.gpa.create(ObjectVsBroadPhaseLayerFilter);
    phys.object_layer_pair_filter = try alc.gpa.create(ObjectLayerPairFilter);
    phys.contact_listener = try alc.gpa.create(ContactListener);

    phys.broad_phase_layer_interface.* = BroadPhaseLayerInterface.init();
    phys.object_vs_broad_phase_layer_filter.* = .{};
    phys.object_layer_pair_filter.* = .{};
    phys.contact_listener.* = .{};

    try zph.init(alc.gpa_arena, .{});
    phys.physics_system = try zph.PhysicsSystem.create(
        @as(*const zph.BroadPhaseLayerInterface, @ptrCast(phys.broad_phase_layer_interface)),
        @as(*const zph.ObjectVsBroadPhaseLayerFilter, @ptrCast(phys.object_vs_broad_phase_layer_filter)),
        @as(*const zph.ObjectLayerPairFilter, @ptrCast(phys.object_layer_pair_filter)),
        .{
            .max_bodies = 1024,
            .num_body_mutexes = 0,
            .max_body_pairs = 1024,
            .max_contact_constraints = 1024,
        },
    );

    // multiplied by 1.3 for a weightier feel
    phys.physics_system.setGravity(.{ 0, 0, -9.88 * 1.3 });

    phys.physics_system.setContactListener(phys.contact_listener);

    phys.body_interface = phys.physics_system.getBodyInterfaceMut();
    phys.lock_interface = phys.physics_system.getBodyLockInterface();
    std.log.info("ZPhysics (Jolt) initialized successfully", .{});
    sys.setStateOn(.physics);
}

/// Deinitilaize Physics World
pub fn deinit() void {
    sys.setStateOff(sys.EngineState.physics);
    phys.physics_system.destroy();
    alc.gpa.destroy(phys.broad_phase_layer_interface);
    alc.gpa.destroy(phys.object_vs_broad_phase_layer_filter);
    alc.gpa.destroy(phys.object_layer_pair_filter);
    alc.gpa.destroy(phys.contact_listener);
    zph.deinit();
    sys.setStateOff(.physics);
}

/// Process Physworld
/// TODO proper timing on physics steps
pub fn proc() !void {
    //const delta_time = chr.frameDelta();
    //try phys.physics_system.update(delta_time, .{});
}

///// Generate a phys cube and add new cube to the physics blob
///// TODO figure out why no collision
//pub fn addPhysCube(cube: *cbe.Cube, index: u8) !void {
//    _ = index;
//
//    const axial = cube.euclid.position.getAxial();
//    const quat = cube.euclid.rotation;
//    const scale = cube.euclid.scale;
//
//    // half extents?
//    const box_shape_settings = try zph.BoxShapeSettings.create(.{ scale.x * 0.5, scale.y * 0.5, scale.z * 0.5 });
//    defer box_shape_settings.release();
//
//    const box_shape = try box_shape_settings.createShape();
//    defer box_shape.release();
//
//    cube.phys_body = try phys.body_interface.createAndAddBody(.{
//        .motion_type = if (cube.cube_type == cbe.CubeType.player or cube.cube_type == cbe.CubeType.enemy) .dynamic else .static,
//        .position = .{ axial.x, axial.y, axial.z, 1.0 }, // 4th element is ignored
//        .rotation = .{ quat[0], quat[1], quat[2], quat[3] },
//        .shape = box_shape,
//        .mass_properties_override = .{ .mass = 2.0 },
//        .allow_sleeping = false,
//        .collision_group = phys.collision_group,
//        .object_layer = if (cube.cube_type == cbe.CubeType.player or cube.cube_type == cbe.CubeType.enemy) object_layers.moving else object_layers.non_moving,
//        .friction = 1.0,
//        .user_data = cube.self_index,
//        .is_sensor = (cube.cube_type == cbe.CubeType.coin or cube.cube_type == cbe.CubeType.trigger),
//    }, .activate);
//
//    phys.physics_system.optimizeBroadPhase();
//}

///// Remove Physics Cube
//pub fn remPhysCube(cube: *cbe.Cube) void {
//    phys.body_interface.removeAndDestroyBody(cube.phys_body);
//    phys.physics_system.optimizeBroadPhase();
//}

///// Process
//pub fn procCube(cube: *cbe.Cube, torque: zmt.F32x4, torque_mag: f32, max_ang_mag: f32) void {
//    //TODO fix this nonesense
//
//    const cur_ang = phys.body_interface.getAngularVelocity(cube.phys_body);
//    const final_mag = torque * zmt.splat(zmt.F32x4, torque_mag) * zmt.F32x4{
//        @max(0.0, 1.0 - @abs(cur_ang[0]) / max_ang_mag),
//        @max(0.0, 1.0 - @abs(cur_ang[1]) / max_ang_mag),
//        0,
//        0,
//    };
//    const crank = @Vector(3, f32){ final_mag[0], final_mag[1], final_mag[2] };
//    phys.body_interface.addTorque(cube.phys_body, crank);
//
//    const pos = phys.body_interface.getPosition(cube.phys_body);
//    const rot = phys.body_interface.getRotation(cube.phys_body);
//
//    cube.euclid.position.setAxial(tpe.Float3{
//        .x = pos[0],
//        .y = pos[1],
//        .z = pos[2],
//    });
//    cube.euclid.rotation = zmt.Quat{
//        rot[0],
//        rot[1],
//        rot[2],
//        rot[3],
//    };
//}

/// Necessary for ZPhysics/Jolt
const BroadPhaseLayerInterface = extern struct {
    usingnamespace zph.BroadPhaseLayerInterface.Methods(@This());
    __v: *const zph.BroadPhaseLayerInterface.VTable = &vtable,

    object_to_broad_phase: [object_layers.len]zph.BroadPhaseLayer = undefined,

    const vtable = zph.BroadPhaseLayerInterface.VTable{
        .getNumBroadPhaseLayers = _getNumBroadPhaseLayers,
        .getBroadPhaseLayer = _getBroadPhaseLayer,
    };

    fn init() BroadPhaseLayerInterface {
        var layer_interface: BroadPhaseLayerInterface = .{};
        layer_interface.object_to_broad_phase[object_layers.non_moving] = broad_phase_layers.non_moving;
        layer_interface.object_to_broad_phase[object_layers.moving] = broad_phase_layers.moving;
        return layer_interface;
    }

    fn _getNumBroadPhaseLayers(_: *const zph.BroadPhaseLayerInterface) callconv(.C) u32 {
        return broad_phase_layers.len;
    }

    fn _getBroadPhaseLayer(
        iself: *const zph.BroadPhaseLayerInterface,
        layer: zph.ObjectLayer,
    ) callconv(.C) zph.BroadPhaseLayer {
        const self = @as(*const BroadPhaseLayerInterface, @ptrCast(iself));
        return self.object_to_broad_phase[layer];
    }
};

/// Necessary for ZPhysics/Jolt
const ObjectVsBroadPhaseLayerFilter = extern struct {
    usingnamespace zph.ObjectVsBroadPhaseLayerFilter.Methods(@This());
    __v: *const zph.ObjectVsBroadPhaseLayerFilter.VTable = &vtable,

    const vtable = zph.ObjectVsBroadPhaseLayerFilter.VTable{ .shouldCollide = _shouldCollide };

    fn _shouldCollide(
        _: *const zph.ObjectVsBroadPhaseLayerFilter,
        layer1: zph.ObjectLayer,
        layer2: zph.BroadPhaseLayer,
    ) callconv(.C) bool {
        return switch (layer1) {
            object_layers.non_moving => layer2 == broad_phase_layers.moving,
            object_layers.moving => true,
            else => unreachable,
        };
    }
};

/// Necessary for ZPhysics/Jolt
const ObjectLayerPairFilter = extern struct {
    usingnamespace zph.ObjectLayerPairFilter.Methods(@This());
    __v: *const zph.ObjectLayerPairFilter.VTable = &vtable,

    const vtable = zph.ObjectLayerPairFilter.VTable{ .shouldCollide = _shouldCollide };

    fn _shouldCollide(
        _: *const zph.ObjectLayerPairFilter,
        object1: zph.ObjectLayer,
        object2: zph.ObjectLayer,
    ) callconv(.C) bool {
        return switch (object1) {
            object_layers.non_moving => object2 == object_layers.moving,
            object_layers.moving => true,
            else => unreachable,
        };
    }
};

/// Necessary for ZPhysics/Jolt
const ContactListener = extern struct {
    usingnamespace zph.ContactListener.Methods(@This());
    __v: *const zph.ContactListener.VTable = &vtable,
    //system: *phys. SystemState,

    const vtable = zph.ContactListener.VTable{
        .onContactValidate = _onContactValidate,
        .onContactAdded = _onContactAdded,
    };

    fn _onContactValidate(
        iself: *zph.ContactListener,
        body1: *const zph.Body,
        body2: *const zph.Body,
        base_offset: *const [3]zph.Real,
        collision_result: *const zph.CollideShapeResult,
    ) callconv(.C) zph.ValidateResult {
        _ = iself;
        _ = body1;
        _ = body2;
        _ = base_offset;
        _ = collision_result;
        return .accept_all_contacts;
    }

    fn _onContactAdded(
        iself: *zph.ContactListener,
        body1: *const zph.Body,
        body2: *const zph.Body,
        manifold: *const zph.ContactManifold,
        settings: *zph.ContactSettings,
    ) callconv(.C) void {
        _ = settings;
        _ = manifold;
        const self = @as(*const ContactListener, @ptrCast(iself));
        _ = self;
        _ = body1;
        _ = body2;
        //const cube_1 = &lvl.active_level.cubes.items[body1.user_data];
        //const cube_2 = &lvl.active_level.cubes.items[body2.user_data];

        //const type_1 = cube_1.cube_type;
        //const type_2 = cube_2.cube_type;

        //if (type_1 == cbe.CubeType.player or type_2 == cbe.CubeType.player) {
        //    var a: *cbe.Cube = undefined;
        //    var b: *cbe.Cube = undefined;
        //    if (type_1 == cbe.CubeType.player) {
        //        a = cube_1;
        //        b = cube_2;
        //    } else {
        //        a = cube_2;
        //        b = cube_1;
        //    }

        //    switch (b.cube_type) {
        //        cbe.CubeType.enemy => {
        //            lvl.setActiveState(.failed);
        //        },
        //        cbe.CubeType.coin => {
        //            if (b.cube_state == 3) {
        //                b.cube_state = 0;
        //                lvl.active_level.cur_score += 1;
        //            }
        //        },
        //        cbe.CubeType.endgate => {
        //            lvl.setActiveState(.succeeded);
        //        },

        //        else => {},
        //    }
        //}
    }
};

const object_layers = struct {
    const non_moving: zph.ObjectLayer = 0;
    const moving: zph.ObjectLayer = 1;
    const len: u32 = 2;
};

const broad_phase_layers = struct {
    const non_moving: zph.BroadPhaseLayer = 0;
    const moving: zph.BroadPhaseLayer = 1;
    const len: u32 = 2;
};

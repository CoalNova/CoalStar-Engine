# CoalStar-Engine
#### A video game engine focused on facilitating supermassive open-world gameplay.

CoalStar is being produced alongside a game to guide focus and give a hard line to expected mechanics and functionality. CoalStar, thusly, has a few specific mechanical goals. These are broken down into levels of necessity.

CoalStar is written in the [Zig](https://ziglang.org/) programming language. CoalStar uses elements from [Zig-Gamedev](https://github.com/zig-gamedev/zig-gamedev) to access [Jolt Physics](), [SDL](https://www.libsdl.org/), and [OpenGL](https://www.opengl.org/). The scripting engine of choice will be [LUA](https://www.lua.org/), facilitated through [ZigLUA](https://github.com/natecraddock/ziglua). And any code used or referenced is subject to those licenses therein.

Other resources are being researched, and this will be updated to reflect those changes.

## Primary Goals

The primary goals of the CoalStar Engine are:

#### Supermassive open world terrain and traversal. 
The world is able to display, even in limited fidelity, a worldspace spanning multiple hundreds or thousands of square kilometers. The player, or focus, should be able to traverse this land directly, and at relatively high speeds. Current goal is ~100km/h, though that is a lower bound.

#### Threading and asynchronous rendering.
The engine will isolate workloads discretely, placing relevant functions into threads dedicated to those tasks. The renderer will hold possession only of information it requires for smooth functionality, and run independently of logic threads.

#### Widely adoptable platform usage.
The engine should be able to perform adequately on a wide range of user devices. This does not simply mean across multiple operating systems, but includes older, less powerful hardware. The only restriction at this time is OpenGL 3.2. This may change to go as far back as 3.0 or perhaps 2.1, depending on required technology.

#### Compression-by-design of game data to reduce install size.

Utilize progressive data layout to allow for smaller size. It is intended to reduce the necessary size-on-disk for users, and prevent the game's installation as being a burden in and of itself.

#### ProcGen of mundane assets.

Natural and other mundane assets will dynamically be placed by a deterministic rule-based formula. A separate override system will modify or remove assets. This will allow for more rapid world creation, and still allow for the feeling of a hand-crafted worldspace.

#### External (LUA) script integration.

LUA is the primary scripting language for exposing engine functions for game use. Utilization and what things will be exposed is still tbd. 

#### Inter and Intradimensional Projections.
The engine uses Interdimensional projections to support the supermassive worldspace. Intradimensional worldspaces are used for interiors and other such areas.

## Secondary Goals

#### Focused player character movement.

Character movement reflects expected results. Dynamic vaulting, crouch/crawling, and sprinting behaving as they would be expected to. This will help players feel more connected with their character, and the worldspace as a whole.

#### Simulation of Worldspace.

Simulations of weather patterns, and their affects on the world will result in a more cohesive and living world. Simulating populations and actors through economy and group movements are still being researched, pending how deeply these simulations should interact.

#### In-game manipulation of terrain and static objects.

Players will be able to modify terrain and place/remove static objects to create their own homes/homesteads. This will likely requires limits within the game itself for allowance of editable area.

## Tertiary Goals

#### External resource and data overrides.

Allowing modification of manifests, override tables, scripts, and resources will allow for game mods. This can increase desirability by allowing any community to manipulate the game as to make it their own.

---

# State of Development

The production of the engine exists in various Phases. Each Phase is an abstract collection of functions and mechanics grouped to meter development progress.

Some parts of any given Phase may need to be delayed due to requiring features of a subsequent Phase.

### Phases:

- Phase 1: SDL/GL Implementation ✔
    - Linking and layout of SDL library interface ✔
    - Creation of an event system based on SDL inputs ✔
    - Creation of engine system flags to determine engine state ✔
- Phase 2: Basic Types ✔
    - Creation of types conducive to multi-dimensional location ✔
- Phase 3: Resource types and Collection ✔
    - Creation of resource categorization ✔
    - Creation of unique resource subscription collection ✔
    - Creation of texture stack ✔
- Phase 4: Dedicated Multithreading ✔
    - Isolation of jobs into discrete categories ✔
    - Creation of thread manager to create/manage ✔
    - Creation of unsynchronized render system ✔
- Phase 5: Resource Manifest and Onboarding ⬅
    - Creation of Manifest layout
    - Creation of functions to convert resource types
    - Creation of functions to inject resources through Manifest
    - Resolution of Manifest from multiple adds/deletes
    - Exporting/Importing of Manifest for read or edit
- Phase 6: Basic Shaders and Optional Externalization
    - Basic dynamic prop shader
    - Basic static prop shader
    - Basic terrain shader
    - Creation of Static batching through instancing
        - Mesh aggregation as a back-up for GL <3.2
    - Basic UI system
- Phase 7: World Editing and Terrain Generation
    - Editor UI blockout
        - resource previewer
    - System based file search
    - Resource linkage
    - Worldspace placement of Props
    - Importing/Exporting of worldspace
    - Terrain generation from BMP
- Phase 8: Zoning and Prop collections
    - Assigned area Zoning
    - Deterministic Propagation of Props based on Zoning rules
    - Modification of procgen'd props saved to override table
- Phase 9: Intradimensional Projections and Traversal
    - Translation of position and rotation between portals
    - Preculled/stenciled portal rendering
    - Selective render cascades
- Phase 10: Basic Actor Movement and Interactions
    - Physical player blocking
    - Crouching, Jumping, Vaulting
    - Activation of objects and events through player input
    - Mounts and furniture
- Phase 11: Dynamic Actor Generation
    - Create Actor generation rules for zones to an initial state
- Phase 12: Basic AI and Actor Simulations
    - Daily needs and occupational routines
    - Reaction to player behavior tracking
- Phase 13: Basic Environmental Simulations
    - Day/Night cycle with exposed ToD data
    - Date of year with seasonal changes and exposed ToY data
    - Basic weather pattern tree with conditional effects exposed
- Phase 14: Complex Shaders and Occlusion Solutions
    - Creation of LOD management system
    - Creation of Dynamic Occlusion Rules
    - Shadow Solution
    - Weather-based shader solutions
- Phase 15: Complex Movement and Interactions
    - Mounts and Furniture
    - Non-static public transit movement
    - Inventory management
        - Buying, selling, and trading
- Phase 16: Complex Population Simulations and Ownership
    - Local and global scale economy
    - Economic reactions (pending) 
    - Macropathing
- Phase 17: Complex Environmental Simulations
    - Localized weather patterns based on environmental LUT 
    - Weather pattern movement
    - Deterministic lookup of weather effects for prior weather patterns
- Phase 18: Complex AI Behavior
    - Recognition of player behaviors through actions
        - Sneaking based on observance of individual or behavior
    - Actor to Actor interactions, with clear and observable results
- Phase 19: Scripting behaviors
    - Exposing functions and data to LUA for scripting
- Phase 20: Save Function
    - Capturing and storing serialized data 
    - Application of serialized data to base game data for loading

---

# Game Inclusion

The game produced alongside is unnamed, but is the focus of the engine production. The engine needn't function specifically on this title. Many other games could be produced based on this engine, pending its completion.

The basic themes are:
- Medieval Fantasy
- First/Third person RPG
- Generalized gameplay focus, not exclusively combat oriented
- An attempt at a CRPG with fewer layers of abstraction to the player

The game is not intended as a graphically demanding experience, instead opting to focus on grander scale instead of minute details. Much of the details surrounding the game are work in progress and subject to wild and varied changes on a whim. More information will be released when finalized.
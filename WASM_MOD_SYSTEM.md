# WASM Mod System Documentation

## Overview

The game now uses a **WebAssembly (WASM)** based mod system where mods are written in **Odin** and compiled to WASM. This provides:

- ✅ **Native Performance** - Near-native speed (1.5-3x slower vs 10-50x with Lua)
- ✅ **Type Safety** - Compile-time checks, no runtime type errors
- ✅ **Hot Reload** - Automatic recompilation and reload on file changes
- ✅ **Same Language** - Mods written in Odin, same as the engine
- ✅ **Sandboxing** - WASM provides memory isolation and security

## Directory Structure

```
mods/
  core/                      # Core game mod (required)
    mod.json                 # Mod metadata
    core.odin                # Main entry point
    core.wasm                # Compiled WASM (auto-generated)
    entities/
      player.odin
      wanderer.odin
      spinner.odin
  
  example_mod/               # Example custom mod
    mod.json
    example_mod.odin
    example_mod.wasm         # Compiled WASM (auto-generated)
    entities/
      orbiter.odin

shared/
  host_api/                  # Shared API definitions
    host_api.odin            # Used by both host and mods
```

## How It Works

### 1. Architecture

```
┌─────────────────────────────────────────┐
│         Host Engine (Native Odin)       │
│  ┌───────────────────────────────────┐  │
│  │      Wasmtime Runtime             │  │
│  │  ┌─────────────┐  ┌─────────────┐ │  │
│  │  │  Core Mod   │  │ Custom Mod  │ │  │
│  │  │  (WASM)     │  │  (WASM)     │ │  │
│  │  └─────────────┘  └─────────────┘ │  │
│  └───────────────────────────────────┘  │
│              ↕                           │
│         Host Functions                   │
│  (entity manipulation, input, etc.)     │
└─────────────────────────────────────────┘
```

### 2. Compilation Flow

1. **File Watcher** detects changes to `.odin` files in `mods/`
2. **Mod Compiler** runs: `odin build mods/core -target:freestanding_wasm32 -out:mods/core/core.wasm`
3. **WASM Runtime** reloads the compiled `.wasm` module
4. Game continues running with updated code

### 3. Host ↔ Guest Communication

**Guest (Mod) calls Host:**
```odin
// Mod code
import api "shared:host_api"

pos := api.entity_get_pos(entity_id)
api.entity_set_pos(entity_id, new_pos)
```

**Host calls Guest:**
```odin
// Engine code
wasm.call_mod_init(mod)
wasm.call_entity_update(mod, entity_id, dt)
```

## Creating a Mod

### Step 1: Create Mod Structure

```
mods/
  my_mod/
    mod.json
    my_mod.odin
    entities/
      my_entity.odin
```

### Step 2: Write `mod.json`

```json
{
  "name": "My Mod",
  "version": "1.0.0",
  "author": "Your Name",
  "description": "Description of your mod",
  "entry_script": "my_mod.odin"
}
```

### Step 3: Write Main Entry Point

**`mods/my_mod/my_mod.odin`:**
```odin
package my_mod

import api "shared:host_api"

// Entity registry maps entity ID → update function
Entity_Update_Func :: proc(entity_id: u64, dt: f32)
entity_registry: map[u64]Entity_Update_Func

// Called once when mod loads
@(export)
mod_init :: proc "c" () {
    api.log_info("My mod initializing...")
    entity_registry = make(map[u64]Entity_Update_Func)
    
    // Spawn entities
    my_entity_id := api.spawn_entity("my_entity", 0, 0)
    entity_registry[my_entity_id] = my_entity_update
    
    api.log_info("My mod initialized!")
}

// Called every frame
@(export)
mod_update :: proc "c" (dt: f32) {
    // Global mod logic here
}

// Called for each entity this mod owns
@(export)
entity_update :: proc "c" (entity_id: u64, dt: f32) {
    if update_func, ok := entity_registry[entity_id]; ok {
        update_func(entity_id, dt)
    }
}

// Called when mod unloads
@(export)
mod_shutdown :: proc "c" () {
    api.log_info("My mod shutting down...")
    delete(entity_registry)
}

// Include entity implementations
#load "entities/my_entity.odin"
```

### Step 4: Create Entity

**`mods/my_mod/entities/my_entity.odin`:**
```odin
package my_mod

import api "shared:host_api"

// Per-entity state
My_Entity_State :: struct {
    custom_data: f32,
}

my_entity_states: map[u64]My_Entity_State

my_entity_init :: proc(entity_id: u64) {
    if entity_id not_in my_entity_states {
        my_entity_states[entity_id] = My_Entity_State{
            custom_data = 42.0,
        }
    }
}

my_entity_update :: proc(entity_id: u64, dt: f32) {
    my_entity_init(entity_id)
    state := &my_entity_states[entity_id]
    
    // Get position
    pos := api.entity_get_pos(entity_id)
    
    // Move entity
    new_pos := api.Vec2{
        x = pos.x + 10.0 * dt,
        y = pos.y,
    }
    api.entity_set_pos(entity_id, new_pos)
    
    // Set animation
    api.entity_set_animation(entity_id, "player_idle", 0.3, true)
}
```

### Step 5: Compile and Load

The mod system will **automatically**:
1. Detect your `.odin` files
2. Compile to WASM
3. Load the `.wasm` module
4. Call `mod_init()`

**Hot reload** works automatically - just save your `.odin` file!

## Available API Functions

### Entity Manipulation

```odin
// Position
entity_get_pos(entity_id: u64) -> Vec2
entity_set_pos(entity_id: u64, pos: Vec2)

// Rotation
entity_get_rotation(entity_id: u64) -> f32
entity_set_rotation(entity_id: u64, rotation: f32)

// Sprite
entity_get_flip_x(entity_id: u64) -> bool
entity_set_flip_x(entity_id: u64, flip: bool)

// Animation
entity_set_animation(entity_id: u64, sprite_name: string, frame_duration: f32, loop := true)

// Spawning/Destroying
spawn_entity(script_name: string, x, y: f32) -> u64
destroy_entity(entity_id: u64)
```

### Input

```odin
get_input_vector() -> Vec2
key_down(action_name: string) -> bool
key_pressed(action_name: string) -> bool
```

### Game State

```odin
get_delta_time() -> f32
get_game_time() -> f64
```

### Logging

```odin
log_info(message: string)
log_warn(message: string)
log_error(message: string)
```

## Examples

### Example 1: Simple Moving Entity

```odin
my_entity_update :: proc(entity_id: u64, dt: f32) {
    pos := api.entity_get_pos(entity_id)
    
    // Move right
    new_pos := api.Vec2{
        x = pos.x + 50.0 * dt,
        y = pos.y,
    }
    api.entity_set_pos(entity_id, new_pos)
}
```

### Example 2: Player-Controlled Entity

```odin
player_update :: proc(entity_id: u64, dt: f32) {
    // Get input
    input := api.get_input_vector()
    
    // Get position
    pos := api.entity_get_pos(entity_id)
    
    // Move
    move_speed: f32 = 100.0
    new_pos := api.Vec2{
        x = pos.x + input.x * move_speed * dt,
        y = pos.y + input.y * move_speed * dt,
    }
    api.entity_set_pos(entity_id, new_pos)
    
    // Animation
    if input.x == 0 && input.y == 0 {
        api.entity_set_animation(entity_id, "player_idle", 0.3)
    } else {
        api.entity_set_animation(entity_id, "player_run", 0.1)
    }
}
```

### Example 3: Orbiting Entity

See `mods/example_mod/entities/orbiter.odin` for a complete example of an entity that orbits around a center point.

## Building and Testing

### Manual Compilation

```bash
# Compile a mod
odin build mods/my_mod -target:freestanding_wasm32 -out:mods/my_mod/my_mod.wasm -no-bounds-check -o:speed
```

### Hot Reload

1. Run the game
2. Edit any `.odin` file in `mods/`
3. Save the file
4. The game automatically recompiles and reloads!

### Debugging

- Use `api.log_info()`, `api.log_warn()`, `api.log_error()` for logging
- Compilation errors appear in the console
- Runtime errors are trapped by WASM and logged

## Performance

**Benchmark vs Lua:**

| Operation | Lua (interpreted) | WASM (JIT) | Native |
|-----------|-------------------|------------|--------|
| Entity Update | ~20-50x slower | ~1.5-3x slower | 1x |
| Math Operations | ~10-30x slower | ~1.2-2x slower | 1x |

**Net improvement:** 5-30x faster than Lua!

## Advanced Topics

### Shared State Between Entities

Use global maps in your mod:

```odin
shared_state: map[string]f32

my_entity_update :: proc(entity_id: u64, dt: f32) {
    shared_value := shared_state["some_key"]
    // ...
}
```

### Entity Communication

Entities can communicate through the host:

```odin
// Find all entities within radius (TODO: add to API)
nearby_entities := api.find_entities_in_radius(pos, 50.0)

for nearby_id in nearby_entities {
    // Do something with nearby entity
}
```

### Custom Game Modes

Implement game logic in `mod_update`:

```odin
@(export)
mod_update :: proc "c" (dt: f32) {
    game_time := api.get_game_time()
    
    // Wave spawning
    if game_time > next_wave_time {
        spawn_wave()
        next_wave_time = game_time + wave_interval
    }
}
```

## Troubleshooting

### Mod Doesn't Load

1. Check console for compilation errors
2. Ensure `mod.json` is valid JSON
3. Verify `@(export)` on entry point functions
4. Check that functions use `"c"` calling convention

### Entities Don't Update

1. Ensure entity is registered in `entity_registry`
2. Check that `entity_update` is exported
3. Verify entity was spawned successfully (non-zero ID)

### Hot Reload Not Working

1. Check file watcher is initialized
2. Verify `.odin` file is in `mods/` directory
3. Look for compilation errors in console
4. Try manual recompilation

## Future Enhancements

The API can be easily extended to support:
- **Drawing API** - Custom UI, effects, particles
- **Sound API** - Play sounds, music control
- **Query API** - Find entities by tag, radius, etc.
- **Event System** - Subscribe to game events
- **Save/Load** - Serialize mod state
- **Networking** - Multiplayer hooks (WASM can be sent over network!)

## Conclusion

The WASM mod system provides a powerful, type-safe, and performant way to mod the game. By developing the core game as a mod itself, we ensure the API is robust and capable of supporting complex gameplay.

Happy modding! 🎮


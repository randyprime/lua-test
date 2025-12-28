# Project Overview

A 2D game engine written in Odin with a DLL-based mod system. The engine runs the core game loop while mods (built as DLLs) implement gameplay logic via a foreign function interface.

## Architecture

### Host Engine (`sauce/`)
- **Main game loop**: [game.odin](sauce/game.odin) - Core game state, entity system, update/draw loops
- **Rendering**: Sokol-based graphics with custom sprite/quad system
- **Audio**: FMOD integration
- **Entity system**: Component-based with ID handles, free list management
- **Hot-reload**: File watcher monitors mod source changes and recompiles/reloads DLLs automatically

### Mod System
Mods are compiled as DLLs that link against the host executable's exports. The host provides a C-compatible API that mods import.

**Mod structure:**
- `mod_init()` - Called once when mod loads (spawn initial entities)
- `mod_update(dt)` - Called every frame for general logic
- `entity_update_by_name(script_name, entity_id, dt)` - Dispatches entity updates by name
- `mod_shutdown()` - Cleanup on unload

**Current mods:**
- [mods/core/](mods/core/) - Main gameplay mod (player, wanderer, spinner entities)
- [mods/example_mod/](mods/example_mod/) - Example mod template

### Shared API (`shared/host_api/`)
[host_api.odin](shared/host_api/host_api.odin) defines the boundary between host and mods:
- When compiled as DLL (`ODIN_BUILD_MODE == .Dynamic`): imports functions from host
- When compiled as host: provides stub declarations (real implementations in [dll_host_api.odin](sauce/dll_host_api.odin))

**API categories:**
- Entity API: position, rotation, flip, animation, spawn/destroy
- Input API: input vectors, key states
- Game State API: delta time, game time

### Hot-Reload Workflow
1. File watcher detects changes in `mods/` directory
2. Mod compiler ([mod_compiler.odin](sauce/mod_compiler.odin)) rebuilds changed mod
3. DLL runtime ([dll_runtime.odin](sauce/dll_runtime.odin)) reloads the DLL
4. Entity function pointers are re-bound to new DLL code
5. Game continues running with updated logic

Alternative: External build with `build_mod.bat` → window focus triggers reload

## Build Instructions

### Building the Project
```bash
# Build game + core mod (this is the main build command)
./build.bat
```

This runs the build system which:
1. Builds the main game executable with exported API functions
2. Builds the core mod as a DLL that links against the game executable

**Other build scripts:**
- `build_game.bat` - Build only the game executable
- `build_mod.bat` - Build only the core mod DLL (for external builds)

**Note:** No need to run the .exe after building - test manually when ready.

## Key Files

### Core Systems
- [sauce/game.odin](sauce/game.odin) - Main game loop, entity system, save/load
- [sauce/entity.odin](sauce/entity.odin) - Entity management, handles, lifecycle
- [sauce/dll_runtime.odin](sauce/dll_runtime.odin) - DLL loading/unloading, function binding
- [sauce/dll_host_api.odin](sauce/dll_host_api.odin) - Host-side API implementations
- [sauce/mod_compiler.odin](sauce/mod_compiler.odin) - Compiles mod source to DLL
- [sauce/file_watcher.odin](sauce/file_watcher.odin) - Watches for file changes

### Rendering
- [sauce/core_draw.odin](sauce/core_draw.odin) - Drawing primitives, sprites, quads
- [sauce/core_render.odin](sauce/core_render.odin) - Rendering pipeline, batching
- [sauce/core_draw_text.odin](sauce/core_draw_text.odin) - Text rendering

### Input & Audio
- [sauce/core_input.odin](sauce/core_input.odin) - Input handling
- [sauce/core_sound.odin](sauce/core_sound.odin) - FMOD audio wrapper

### Build System
- [sauce/build/build.odin](sauce/build/build.odin) - Custom build orchestration

## Entity System

Entities are data-driven with function pointers for behavior:

Entities are managed by:
- Fixed array `entities: [MAX_ENTITIES]Entity`
- Free list for recycling slots
- Handle system with generation counters to detect stale references

## Save/Load System

- Save: Alt+F → serializes game state to `worlds/save.cbor` using CBOR format
- Load: Alt+V → clears state, deserializes from disk
- Entity function pointers are re-established via `entity_setup()`
- Note: WASM/DLL entity state serialization is TODO

## Coordinate Systems

The engine uses multiple coordinate spaces:
- **World space**: Game world coordinates (camera follows player)
- **Screen space**: UI/HUD coordinates
- **Clip space**: NDC coordinates for low-level rendering

Use `push_coord_space()` to switch between them.

## Development Notes

- Built with [Odin programming language](https://odin-lang.org/)
- Uses Sokol for cross-platform graphics/input
- FMOD for audio
- Project was originally Lua-based, then WASM-based (hence `wasm_` prefixes), now uses native DLL mods
- Entity system supports both native and DLL-based entities
- Hot-reload works in real-time during development

## Common Tasks

**Add a new entity type:**
1. Add update function to [mods/core/core.odin](mods/core/core.odin)
2. Add case to `entity_update_by_name` dispatcher
3. Spawn in `mod_init()` or via `api.spawn_entity()`

**Add new sprites:**
1. Put PNG in `res/images/`
2. Add to `Sprite_Name` enum in [game.odin](sauce/game.odin)
3. Add metadata to `sprite_data` if multi-frame

**Add host API function:**
1. Declare in [shared/host_api/host_api.odin](shared/host_api/host_api.odin)
2. Implement in [sauce/dll_host_api.odin](sauce/dll_host_api.odin)
3. Export from game executable

## Project State

Recent changes (from git history):
- Transitioned from Lua to WASM to DLL mod system
- Removed old WASM runtime (wasmtime-c bindings)
- Implemented DLL hot-reload with file watcher
- Core mod contains player, wanderer, spinner entities
- Save/load system uses CBOR serialization
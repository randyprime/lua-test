# WASM Mod System Setup Guide

## Prerequisites

### 1. Wasmtime Library

The game requires the **Wasmtime** C library to run WASM modules.

#### Windows

1. Download Wasmtime C API:
   ```bash
   # Download from https://github.com/bytecodealliance/wasmtime/releases
   # Get: wasmtime-v*-x86_64-windows-c-api.zip
   ```

2. Extract and place `wasmtime.lib` in:
   ```
   sauce/wasm/lib/wasmtime.lib
   ```

3. Place `wasmtime.dll` in:
   ```
   res/build/windows_debug/wasmtime.dll
   ```

#### Mac

```bash
brew install wasmtime
```

#### Linux

```bash
# Ubuntu/Debian
sudo apt install libwasmtime-dev

# Arch
sudo pacman -S wasmtime
```

### 2. Odin Compiler

Ensure you have a recent version of Odin (dev-2024-12 or later):

```bash
odin version
```

Download from: https://odin-lang.org/

## Project Setup

### 1. Initialize the Mod System

The first time you run the game after switching to WASM:

1. **Compile the core mod:**
   ```bash
   odin build mods/core -target:freestanding_wasm32 -out:mods/core/core.wasm -no-bounds-check -o:speed
   ```

2. **Build the game:**
   ```bash
   # Windows
   build.bat

   # Mac
   ./build_mac.sh

   # Linux
   ./build_linux.sh
   ```

3. **Run the game:**
   ```bash
   # Windows
   res/build/windows_debug/game.exe

   # Mac/Linux
   ./res/build/game
   ```

### 2. Verify Setup

You should see in the console:

```
[INFO] Initializing WASM runtime...
[INFO] WASM runtime initialized successfully
[INFO] Compiling mod: mods/core
[INFO] Compiled mod: core
[INFO] Loading WASM module: mods/core/core.wasm
[INFO] Successfully loaded WASM module: core
[INFO] [WASM] Core mod initializing...
[INFO] [WASM] Spawned player entity
[INFO] [WASM] Spawned wanderer entity
[INFO] [WASM] Spawned spinner entity
[INFO] [WASM] Core mod initialized successfully
```

## Development Workflow

### Hot Reload

The game automatically watches for changes to `.odin` files in `mods/` and recompiles:

1. **Edit** any `.odin` file in `mods/core/` or your custom mod
2. **Save** the file
3. **Watch** the console - you'll see:
   ```
   [INFO] Files changed, recompiling mods...
   [INFO] Compiling mod: mods/core
   [INFO] Compiled mod: core
   [INFO] Hot-reloading WASM module: core
   [INFO] [WASM] Core mod shutting down...
   [INFO] Successfully reloaded module: core
   [INFO] [WASM] Core mod initializing...
   ```
4. **Continue playing** with the updated code!

### Creating a New Mod

1. **Create directory structure:**
   ```bash
   mkdir -p mods/my_mod/entities
   ```

2. **Copy example mod as template:**
   ```bash
   cp mods/example_mod/mod.json mods/my_mod/
   cp mods/example_mod/example_mod.odin mods/my_mod/my_mod.odin
   ```

3. **Edit `mod.json`** with your mod info

4. **Compile your mod:**
   ```bash
   odin build mods/my_mod -target:freestanding_wasm32 -out:mods/my_mod/my_mod.wasm -no-bounds-check -o:speed
   ```

5. **Load it in the game** (you'll need to add it to `game.odin`'s mod loading code, or wait for dynamic mod loading feature)

## Troubleshooting

### Problem: "Failed to create Wasmtime engine"

**Solution:** Wasmtime library not found.
- **Windows:** Ensure `wasmtime.lib` is in `sauce/wasm/lib/` and `wasmtime.dll` is in your PATH or next to the exe
- **Mac/Linux:** Install Wasmtime via package manager

### Problem: "Failed to compile mod"

**Solution:** Odin compilation error.
- Check console output for Odin compiler errors
- Ensure you're using `freestanding_wasm32` target
- Verify your code compiles for WASM (no OS-specific functions)

### Problem: "Failed to load WASM module"

**Solution:** Invalid WASM file.
- Delete the `.wasm` file and recompile
- Check for Odin compilation warnings
- Ensure all `@(export)` functions use `"c"` calling convention

### Problem: "Hot reload not working"

**Solution:** File watcher issue.
- Check that files are actually in `mods/` directory
- Look for compilation errors (hot reload stops if compilation fails)
- Try manual recompilation: `odin build mods/core -target:freestanding_wasm32 -out:mods/core/core.wasm`

### Problem: Entities don't move/update

**Solution:** Check entity registration.
- Verify entity was added to `entity_registry` in `mod_init`
- Ensure `entity_update` function is exported
- Check console for WASM errors

## Performance Tips

### Compilation Flags

**Development (faster compile):**
```bash
odin build mods/my_mod -target:freestanding_wasm32 -out:mods/my_mod/my_mod.wasm
```

**Release (faster runtime):**
```bash
odin build mods/my_mod -target:freestanding_wasm32 -out:mods/my_mod/my_mod.wasm -no-bounds-check -o:speed
```

### WASM Optimization

- Use `-o:speed` for maximum performance
- Use `-no-bounds-check` to remove array bounds checks (only if you're confident!)
- Profile your code to find hot spots

### Memory Management

- WASM has its own linear memory space
- Keep per-entity state maps reasonable in size
- Clean up state when entities are destroyed

## Migration from Lua

If you're migrating existing Lua code:

1. **Entity state** - Lua tables → Odin structs in global maps
2. **Functions** - Lua functions → Odin procedures
3. **API calls** - Same names, just use `api.` prefix
4. **Type safety** - Add explicit types (Odin catches errors at compile time!)

### Example Migration

**Before (Lua):**
```lua
function entity:update(dt)
    local pos = get_pos()
    set_pos(pos.x + 10 * dt, pos.y)
end
```

**After (Odin):**
```odin
entity_update :: proc(entity_id: u64, dt: f32) {
    pos := api.entity_get_pos(entity_id)
    new_pos := api.Vec2{x = pos.x + 10 * dt, y = pos.y}
    api.entity_set_pos(entity_id, new_pos)
}
```

## Next Steps

1. ✅ Set up Wasmtime library
2. ✅ Compile core mod
3. ✅ Run the game and verify it works
4. 📖 Read `WASM_MOD_SYSTEM.md` for API documentation
5. 🎮 Create your first custom mod!
6. 🚀 Explore the example mod for inspiration

For more information, see `WASM_MOD_SYSTEM.md`.

Happy modding! 🎮✨


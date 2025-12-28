package main

import "core:dynlib"
import "core:time"
import "core:log"
import "core:os"
import "core:strings"
import "core:fmt"

/*

DLL Mod Runtime

Simple native DLL loading system for mods.
Replaces the entire Wasmtime/WASM infrastructure.

*/

// DLL_Mod represents a loaded mod DLL
DLL_Mod :: struct {
	name: string,
	path: string,
	dll_handle: dynlib.Library,

	// Function pointers (exported from mod DLL)
	mod_init: proc "c" (),
	mod_update: proc "c" (f32),
	entity_update_by_name: proc "c" (cstring, u64, f32),
	mod_shutdown: proc "c" (),

	// Hot-reload tracking
	last_modified_time: time.Time,
	version: int,  // For DLL versioning on Windows
}

// Aliased to Wasm_Mod for compatibility with existing code
Wasm_Mod :: DLL_Mod

// Initialize the DLL runtime (no-op, unlike Wasmtime)
dll_runtime_init :: proc() {
	log.info("DLL runtime initialized (native)")
}

// Get platform-specific DLL extension
get_dll_extension :: proc() -> string {
	when ODIN_OS == .Windows {
		return ".dll"
	} else when ODIN_OS == .Darwin {
		return ".dylib"
	} else {
		return ".so"
	}
}

// Load a mod DLL
load_dll_mod :: proc(path: string, name: string) -> (^DLL_Mod, bool) {
	log.infof("Loading DLL mod: %s from %s", name, path)

	mod := new(DLL_Mod)
	mod.name = name
	mod.path = path
	mod.version = 0

	// Load the DLL
	lib, ok := dynlib.load_library(path)
	if !ok {
		log.errorf("Failed to load DLL: %s", path)
		free(mod)
		return nil, false
	}
	mod.dll_handle = lib

	// Look up exported functions
	mod.mod_init = auto_cast dynlib.symbol_address(lib, "mod_init")
	mod.mod_update = auto_cast dynlib.symbol_address(lib, "mod_update")
	mod.entity_update_by_name = auto_cast dynlib.symbol_address(lib, "entity_update_by_name")
	mod.mod_shutdown = auto_cast dynlib.symbol_address(lib, "mod_shutdown")

	// Verify we have the required exports
	if mod.mod_init == nil {
		log.warn("DLL missing mod_init export")
	}
	if mod.entity_update_by_name == nil {
		log.warn("DLL missing entity_update_by_name export")
	}

	log.infof("Successfully loaded DLL mod: %s", name)
	return mod, true
}

// Unload a mod DLL
unload_dll_mod :: proc(mod: ^DLL_Mod) {
	if mod == nil do return

	log.infof("Unloading DLL mod: %s", mod.name)

	// Call shutdown if available
	if mod.mod_shutdown != nil {
		mod.mod_shutdown()
	}

	// Unload the DLL
	if mod.dll_handle != nil {
		dynlib.unload_library(mod.dll_handle)
	}

	free(mod)
}

// Call mod initialization
call_mod_init :: proc(mod: ^DLL_Mod) {
	if mod == nil do return
	if mod.mod_init != nil {
		log.infof("Calling mod_init for: %s", mod.name)
		mod.mod_init()
	}
}

// Call mod update
call_mod_update :: proc(mod: ^DLL_Mod, dt: f32) {
	if mod == nil do return
	if mod.mod_update != nil {
		mod.mod_update(dt)
	}
}

// Call entity update by name
call_entity_update_by_name :: proc(mod: ^DLL_Mod, script_name: cstring, entity_id: u64, dt: f32) {
	if mod == nil do return
	if mod.entity_update_by_name != nil {
		mod.entity_update_by_name(script_name, entity_id, dt)
	}
}

// Hot-reload a mod DLL (handles Windows DLL locking)
reload_dll_mod :: proc(mod: ^DLL_Mod) -> bool {
	if mod == nil do return false

	log.infof("Hot-reloading DLL mod: %s", mod.name)

	// Call shutdown
	if mod.mod_shutdown != nil {
		mod.mod_shutdown()
	}

	// Unload old DLL
	if mod.dll_handle != nil {
		dynlib.unload_library(mod.dll_handle)
		mod.dll_handle = nil
	}

	// Increment version for Windows DLL locking workaround
	mod.version += 1

	// Load new DLL
	lib, ok := dynlib.load_library(mod.path)
	if !ok {
		log.errorf("Failed to reload DLL: %s", mod.path)
		return false
	}
	mod.dll_handle = lib

	// Re-lookup exported functions
	mod.mod_init = auto_cast dynlib.symbol_address(lib, "mod_init")
	mod.mod_update = auto_cast dynlib.symbol_address(lib, "mod_update")
	mod.entity_update_by_name = auto_cast dynlib.symbol_address(lib, "entity_update_by_name")
	mod.mod_shutdown = auto_cast dynlib.symbol_address(lib, "mod_shutdown")

	// Call init on reloaded mod
	if mod.mod_init != nil {
		mod.mod_init()
	}

	log.infof("Successfully reloaded DLL mod: %s", mod.name)
	return true
}

// ============================================================================
// Backwards Compatibility Aliases (for transition from WASM)
// ============================================================================

load_wasm_mod :: load_dll_mod
unload_wasm_mod :: unload_dll_mod
reload_wasm_mod :: reload_dll_mod

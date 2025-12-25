package wasm

import "core:log"
import "core:fmt"
import "core:os"
import "core:strings"
import "core:mem"
import "core:c"
import "core:time"

/*

WASM Module Runtime

Manages loading, instantiation, and execution of WASM modules (mods).
Provides hot-reload capability for development.

*/

// Global WASM engine (shared across all modules)
wasm_engine: ^wasmtime_engine_t

// A loaded WASM mod
Wasm_Mod :: struct {
	name: string,
	version: string,
	path: string,
	
	// Wasmtime objects
	store: ^wasmtime_store_t,
	module: ^wasmtime_module_t,
	linker: ^wasmtime_linker_t,
	instance: wasmtime_instance_t,
	memory: ^wasmtime_memory_t,
	
	// Exported functions from the WASM module
	mod_init: wasmtime_func_t,
	mod_update: wasmtime_func_t,
	mod_shutdown: wasmtime_func_t,
	entity_update: wasmtime_func_t,
	
	// State
	initialized: bool,
	last_modified_time: time.Time,
}

// Initialize the WASM runtime
wasm_runtime_init :: proc() -> bool {
	log.info("Initializing WASM runtime...")
	
	wasm_engine = wasmtime_engine_new()
	if wasm_engine == nil {
		log.error("Failed to create Wasmtime engine")
		return false
	}
	
	log.info("WASM runtime initialized successfully")
	return true
}

// Shutdown the WASM runtime
wasm_runtime_shutdown :: proc() {
	if wasm_engine != nil {
		wasmtime_engine_delete(wasm_engine)
		wasm_engine = nil
	}
	log.info("WASM runtime shut down")
}

// Load a WASM module from a .wasm file
load_wasm_mod :: proc(wasm_path: string, mod_name: string) -> (^Wasm_Mod, bool) {
	log.infof("Loading WASM module: %s", wasm_path)
	
	// Read the WASM file
	wasm_data, read_ok := os.read_entire_file(wasm_path)
	if !read_ok {
		log.errorf("Failed to read WASM file: %s", wasm_path)
		return nil, false
	}
	defer delete(wasm_data)
	
	// Debug: Check magic header
	if len(wasm_data) >= 4 {
		log.infof("WASM file size: %d bytes, magic: %02x %02x %02x %02x", 
			len(wasm_data), wasm_data[0], wasm_data[1], wasm_data[2], wasm_data[3])
	}
	
	// Create the mod structure
	mod := new(Wasm_Mod)
	mod.name = strings.clone(mod_name)
	mod.path = strings.clone(wasm_path)
	mod.version = "1.0.0" // TODO: Read from mod.json
	
	// Create store
	mod.store = wasmtime_store_new(wasm_engine, nil, nil)
	if mod.store == nil {
		log.error("Failed to create Wasmtime store")
		free(mod)
		return nil, false
	}
	
	// Create linker
	mod.linker = wasmtime_linker_new(wasm_engine)
	if mod.linker == nil {
		log.error("Failed to create Wasmtime linker")
		wasmtime_store_delete(mod.store)
		free(mod)
		return nil, false
	}
	
	// Register host functions
	if !register_host_functions(mod.linker) {
		log.error("Failed to register host functions")
		wasmtime_linker_delete(mod.linker)
		wasmtime_store_delete(mod.store)
		free(mod)
		return nil, false
	}
	
	// Load the module
	log.infof("wasm_bytes size: %d, first 4 bytes: %02x %02x %02x %02x",
		len(wasm_data), wasm_data[0], wasm_data[1], wasm_data[2], wasm_data[3])
	error := wasmtime_module_new(wasm_engine, raw_data(wasm_data), c.size_t(len(wasm_data)), &mod.module)
	if error != nil {
		msg: wasm_name_t
		wasmtime_error_message(error, &msg)
		error_str := string(msg.data[:msg.size])
		log.errorf("Failed to load WASM module: %s", error_str)
		wasmtime_error_delete(error)
		wasmtime_linker_delete(mod.linker)
		wasmtime_store_delete(mod.store)
		free(mod)
		return nil, false
	}
	
	// Instantiate the module
	ctx := wasmtime_store_context(mod.store)
	trap: ^wasm_trap_t
	inst_error := wasmtime_linker_instantiate(mod.linker, ctx, mod.module, &mod.instance, &trap)
	
	if inst_error != nil {
		msg: wasm_name_t
		wasmtime_error_message(inst_error, &msg)
		error_str := string(msg.data[:msg.size])
		log.errorf("Failed to instantiate WASM module: %s", error_str)
		wasmtime_error_delete(inst_error)
		wasmtime_module_delete(mod.module)
		wasmtime_linker_delete(mod.linker)
		wasmtime_store_delete(mod.store)
		free(mod)
		return nil, false
	}
	
	if trap != nil {
		msg: wasm_name_t
		wasmtime_trap_message(trap, &msg)
		trap_str := string(msg.data[:msg.size])
		log.errorf("Trap during WASM instantiation: %s", trap_str)
		wasmtime_trap_delete(trap)
		wasmtime_module_delete(mod.module)
		wasmtime_linker_delete(mod.linker)
		wasmtime_store_delete(mod.store)
		free(mod)
		return nil, false
	}
	
	// Get exported functions
	get_export_func :: proc(mod: ^Wasm_Mod, name: cstring) -> (wasmtime_func_t, bool) {
		ctx := wasmtime_store_context(mod.store)
		extern: wasmtime_extern_t
		name_len := c.size_t(len(name))
		
		found := wasmtime_instance_export_get(ctx, &mod.instance, transmute([^]u8)name, name_len, &extern)
		if !found || extern.kind != .FUNC {
			return {}, false
		}
		
		return extern.of.func, true
	}
	
	// Try to get optional exported functions
	mod.mod_init, _ = get_export_func(mod, "mod_init")
	mod.mod_update, _ = get_export_func(mod, "mod_update")
	mod.mod_shutdown, _ = get_export_func(mod, "mod_shutdown")
	mod.entity_update, _ = get_export_func(mod, "entity_update")
	
	// Get memory export
	{
		ctx := wasmtime_store_context(mod.store)
		extern: wasmtime_extern_t
		memory_name := "memory"
		found := wasmtime_instance_export_get(ctx, &mod.instance, raw_data(memory_name), 6, &extern)
		if found && extern.kind == .MEMORY {
			mod.memory = &extern.of.memory
		}
	}
	
	// Get file modified time for hot-reload
	file_info, stat_err := os.stat(wasm_path)
	if stat_err == 0 {
		mod.last_modified_time = file_info.modification_time
	}
	
	log.infof("Successfully loaded WASM module: %s", mod_name)
	return mod, true
}

// Unload a WASM module
unload_wasm_mod :: proc(mod: ^Wasm_Mod) {
	if mod == nil do return
	
	log.infof("Unloading WASM module: %s", mod.name)
	
	// Call shutdown if available
	if mod.initialized {
		call_mod_shutdown(mod)
	}
	
	// Cleanup Wasmtime objects
	if mod.module != nil do wasmtime_module_delete(mod.module)
	if mod.linker != nil do wasmtime_linker_delete(mod.linker)
	if mod.store != nil do wasmtime_store_delete(mod.store)
	
	// Free strings
	delete(mod.name)
	delete(mod.path)
	delete(mod.version)
	
	free(mod)
}

// Call mod_init on a loaded module
call_mod_init :: proc(mod: ^Wasm_Mod) -> bool {
	if mod == nil || mod.initialized do return false
	
	// Get the "mod_init" export
	ctx := wasmtime_store_context(mod.store)
	func_extern: wasmtime_extern_t
	name := "mod_init"
	if !wasmtime_instance_export_get(ctx, &mod.instance, raw_data(name), c.size_t(len(name)), &func_extern) {
		log.warnf("Module %s does not export 'mod_init'", mod.name)
		return false
	}
	
	// Verify it's a function
	if func_extern.kind != .FUNC {
		log.warnf("Export 'mod_init' is not a function in module %s", mod.name)
		return false
	}
	
	// Copy the func out of the union
	func := func_extern.of.func
	log.infof("Calling mod_init, func store_id=%d", func.store_id)
	
	// Call the function (no arguments, no return values)
	trap: ^wasm_trap_t = nil
	error := wasmtime_func_call(ctx, &func, nil, 0, nil, 0, &trap)
	
	if error != nil {
		msg: wasm_name_t
		wasmtime_error_message(error, &msg)
		log.errorf("Error calling mod_init on %s: %s", mod.name, string(msg.data[:msg.size]))
		wasmtime_error_delete(error)
		return false
	}
	
	if trap != nil {
		msg: wasm_name_t
		wasm_trap_message(trap, &msg)
		log.errorf("Trap calling mod_init on %s: %s", mod.name, string(msg.data[:msg.size]))
		wasm_trap_delete(trap)
		return false
	}
	
	mod.initialized = true
	log.infof("Called mod_init on: %s", mod.name)
	return true
}

// Call mod_update on a loaded module
call_mod_update :: proc(mod: ^Wasm_Mod, dt: f32) -> bool {
	if mod == nil || !mod.initialized do return false
	
	// Get the "mod_update" export
	ctx := wasmtime_store_context(mod.store)
	func_extern: wasmtime_extern_t
	name := "mod_update"
	if !wasmtime_instance_export_get(ctx, &mod.instance, raw_data(name), c.size_t(len(name)), &func_extern) {
		// mod_update is optional
		return true
	}
	
	// Verify it's a function
	if func_extern.kind != .FUNC do return true
	
	// Set up arguments
	args := [1]wasmtime_val_t{
		{kind = .F32, of = {f32 = dt}},
	}
	
	// Call the function
	trap: ^wasm_trap_t = nil
	error := wasmtime_func_call(ctx, &func_extern.of.func, raw_data(args[:]), 1, nil, 0, &trap)
	
	if error != nil {
		msg: wasm_name_t
		wasmtime_error_message(error, &msg)
		log.errorf("Error calling mod_update on %s: %s", mod.name, string(msg.data[:msg.size]))
		wasmtime_error_delete(error)
		return false
	}
	
	if trap != nil {
		msg: wasm_name_t
		wasm_trap_message(trap, &msg)
		log.errorf("Trap calling mod_update on %s: %s", mod.name, string(msg.data[:msg.size]))
		wasm_trap_delete(trap)
		return false
	}
	
	return true
}

// Call mod_shutdown on a loaded module
call_mod_shutdown :: proc(mod: ^Wasm_Mod) -> bool {
	if mod == nil do return false
	
	// Get the "mod_shutdown" export
	ctx := wasmtime_store_context(mod.store)
	func_extern: wasmtime_extern_t
	name := "mod_shutdown"
	if !wasmtime_instance_export_get(ctx, &mod.instance, raw_data(name), c.size_t(len(name)), &func_extern) {
		// mod_shutdown is optional
		mod.initialized = false
		return true
	}
	
	// Verify it's a function
	if func_extern.kind != .FUNC {
		mod.initialized = false
		return true
	}
	
	// Call the function (no arguments, no return values)
	trap: ^wasm_trap_t = nil
	error := wasmtime_func_call(ctx, &func_extern.of.func, nil, 0, nil, 0, &trap)
	
	if error != nil {
		msg: wasm_name_t
		wasmtime_error_message(error, &msg)
		log.errorf("Error calling mod_shutdown on %s: %s", mod.name, string(msg.data[:msg.size]))
		wasmtime_error_delete(error)
		mod.initialized = false
		return false
	}
	
	if trap != nil {
		msg: wasm_name_t
		wasm_trap_message(trap, &msg)
		log.errorf("Trap calling mod_shutdown on %s: %s", mod.name, string(msg.data[:msg.size]))
		wasm_trap_delete(trap)
		mod.initialized = false
		return false
	}
	
	mod.initialized = false
	log.infof("Called mod_shutdown on: %s", mod.name)
	return true
}

// Call entity_update_by_name for a specific entity
call_entity_update_by_name :: proc(mod: ^Wasm_Mod, script_name: string, entity_id: u64, dt: f32) -> bool {
	if mod == nil || !mod.initialized do return false
	
	// Get the "entity_update_by_name" export
	ctx := wasmtime_store_context(mod.store)
	func_extern: wasmtime_extern_t
	name := "entity_update_by_name"
	if !wasmtime_instance_export_get(ctx, &mod.instance, raw_data(name), c.size_t(len(name)), &func_extern) {
		// entity_update_by_name is optional
		return true
	}
	
	// Verify it's a function
	if func_extern.kind != .FUNC do return true
	
	// We need to allocate the script_name in WASM memory
	// For now, we'll pass the cstring pointer directly (this assumes the WASM module can access host memory)
	// In a proper implementation, you'd allocate in WASM linear memory
	
	// Set up arguments: script_name (i32 pointer), entity_id (i64), dt (f32)
	// NOTE: Passing host pointers to WASM won't work - we need to use shared memory
	// For now, pass 0 and the WASM mod will need to be updated to not use the string
	script_name_cstr := strings.clone_to_cstring(script_name, context.temp_allocator)
	args := [3]wasmtime_val_t{
		{kind = .I32, of = {i32 = 0}},  // TODO: Write string to WASM memory
		{kind = .I64, of = {i64 = i64(entity_id)}},
		{kind = .F32, of = {f32 = dt}},
	}
	
	// Call the function
	trap: ^wasm_trap_t = nil
	error := wasmtime_func_call(ctx, &func_extern.of.func, raw_data(args[:]), 3, nil, 0, &trap)
	
	if error != nil {
		msg: wasm_name_t
		wasmtime_error_message(error, &msg)
		log.errorf("Error calling entity_update_by_name on %s: %s", mod.name, string(msg.data[:msg.size]))
		wasmtime_error_delete(error)
		return false
	}
	
	if trap != nil {
		msg: wasm_name_t
		wasm_trap_message(trap, &msg)
		log.errorf("Trap calling entity_update_by_name on %s: %s", mod.name, string(msg.data[:msg.size]))
		wasm_trap_delete(trap)
		return false
	}
	
	return true
}

// Check if a module needs reloading (file changed)
should_reload_mod :: proc(mod: ^Wasm_Mod) -> bool {
	if mod == nil do return false
	
	file_info, stat_err := os.stat(mod.path)
	if stat_err != 0 do return false
	
	return file_info.modification_time != mod.last_modified_time
}

// Reload a WASM module (hot reload)
reload_wasm_mod :: proc(mod: ^Wasm_Mod) -> bool {
	if mod == nil do return false
	
	log.infof("Hot-reloading WASM module: %s", mod.name)
	
	// Save state
	name := strings.clone(mod.name)
	path := strings.clone(mod.path)
	defer delete(name)
	defer delete(path)
	
	// Unload old module
	unload_wasm_mod(mod)
	
	// Load new module
	new_mod, ok := load_wasm_mod(path, name)
	if !ok {
		log.errorf("Failed to reload module: %s", name)
		return false
	}
	
	// Replace the old mod pointer contents with new mod
	mod^ = new_mod^
	free(new_mod)
	
	// Re-initialize
	call_mod_init(mod)
	
	log.infof("Successfully reloaded module: %s", name)
	return true
}

// Get a slice of WASM linear memory
get_wasm_memory_slice :: proc(mod: ^Wasm_Mod, offset: u32, length: int) -> []byte {
	if mod == nil || mod.memory == nil do return nil
	
	ctx := wasmtime_store_context(mod.store)
	data := wasmtime_memory_data(ctx, mod.memory)
	size := wasmtime_memory_data_size(ctx, mod.memory)
	
	if u64(offset) + u64(length) > u64(size) {
		log.warnf("WASM memory access out of bounds: offset=%d, length=%d, size=%d", offset, length, size)
		return nil
	}
	
	return data[offset:][:length]
}

// Write data to WASM linear memory
write_wasm_memory :: proc(mod: ^Wasm_Mod, offset: u32, data: []byte) -> bool {
	if mod == nil || mod.memory == nil do return false
	
	ctx := wasmtime_store_context(mod.store)
	mem_data := wasmtime_memory_data(ctx, mod.memory)
	size := wasmtime_memory_data_size(ctx, mod.memory)
	
	if u64(offset) + u64(len(data)) > u64(size) {
		log.errorf("WASM memory write out of bounds")
		return false
	}
	
	mem.copy(&mem_data[offset], raw_data(data), len(data))
	return true
}


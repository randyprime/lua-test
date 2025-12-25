package wasm

import "core:log"
import "core:fmt"
import "core:strings"
import "core:reflect"
import "core:c"
import "base:runtime"

/*

Host API Implementation

These functions are exported to WASM modules and can be called by guest code.
They provide access to engine functionality from within sandboxed WASM mods.

*/

// Context stored globally so C callbacks can access it
// Note: This will be set from game.odin
host_context: rawptr
host_our_context: ^runtime.Context

// Set the host context for API calls
set_host_context :: proc(ctx: rawptr, our_ctx: ^runtime.Context) {
	host_context = ctx
	host_our_context = our_ctx
}

// ============================================================================
// Host Function Registration
// ============================================================================

// Register all host functions with the Wasmtime linker
register_host_functions :: proc(linker: ^wasmtime_linker_t) -> bool {
	log.info("Registering host functions...")
	
	// Helper to register a function
	define_host_func :: proc(
		linker: ^wasmtime_linker_t,
		name: string,
		param_kinds: []c.uint8_t,
		result_kinds: []c.uint8_t,
		callback: proc "c" (env: rawptr, caller: ^wasmtime_caller_t, args: [^]wasmtime_val_t, nargs: c.size_t, results: [^]wasmtime_val_t, nresults: c.size_t) -> ^wasm_trap_t,
	) -> bool {
		module := "env"
		log.infof("Registering function: %s", name)
		
		// Create functype
		functype := make_functype(param_kinds, result_kinds)
		if functype == nil {
			log.errorf("Failed to create functype for %s", name)
			return false
		}
		// Note: functype ownership is transferred to linker, don't delete it
		
		err := wasmtime_linker_define_func(
			linker,
			raw_data(module),
			c.size_t(len(module)),
			raw_data(name),
			c.size_t(len(name)),
			functype,
			callback,
			nil, // No data
			nil, // No finalizer
		)
		if err != nil {
			msg: wasm_name_t
			wasmtime_error_message(err, &msg)
			log.errorf("Failed to register %s: %s", name, string(msg.data[:msg.size]))
			wasmtime_error_delete(err)
			return false
		}
		return true
	}
	
	// Register entity functions
	define_host_func(linker, "host_entity_get_pos", {WASM_I64, WASM_I32, WASM_I32}, {}, host_entity_get_pos_wrapper) or_return
	define_host_func(linker, "host_entity_set_pos", {WASM_I64, WASM_F32, WASM_F32}, {}, host_entity_set_pos_wrapper) or_return
	define_host_func(linker, "host_entity_get_flip_x", {WASM_I64}, {WASM_I32}, host_entity_get_flip_x_wrapper) or_return
	define_host_func(linker, "host_entity_set_flip_x", {WASM_I64, WASM_I32}, {}, host_entity_set_flip_x_wrapper) or_return
	define_host_func(linker, "host_entity_get_rotation", {WASM_I64}, {WASM_F32}, host_entity_get_rotation_wrapper) or_return
	define_host_func(linker, "host_entity_set_rotation", {WASM_I64, WASM_F32}, {}, host_entity_set_rotation_wrapper) or_return
	define_host_func(linker, "host_entity_set_animation", {WASM_I64, WASM_I32, WASM_F32, WASM_I32}, {}, host_entity_set_animation_wrapper) or_return
	define_host_func(linker, "host_spawn_entity", {WASM_I32, WASM_F32, WASM_F32}, {WASM_I64}, host_spawn_entity_wrapper) or_return
	define_host_func(linker, "host_destroy_entity", {WASM_I64}, {}, host_destroy_entity_wrapper) or_return
	
	// Register input functions
	define_host_func(linker, "host_get_input_vector", {WASM_I32, WASM_I32}, {}, host_get_input_vector_wrapper) or_return
	define_host_func(linker, "host_key_down", {WASM_I32}, {WASM_I32}, host_key_down_wrapper) or_return
	define_host_func(linker, "host_key_pressed", {WASM_I32}, {WASM_I32}, host_key_pressed_wrapper) or_return
	
	// Register time functions
	define_host_func(linker, "host_get_delta_time", {}, {WASM_F32}, host_get_delta_time_wrapper) or_return
	define_host_func(linker, "host_get_game_time", {}, {WASM_F64}, host_get_game_time_wrapper) or_return
	
	// Register log functions
	define_host_func(linker, "host_log_info", {WASM_I32}, {}, host_log_info_wrapper) or_return
	define_host_func(linker, "host_log_warn", {WASM_I32}, {}, host_log_warn_wrapper) or_return
	define_host_func(linker, "host_log_error", {WASM_I32}, {}, host_log_error_wrapper) or_return
	
	log.info("Host functions registered successfully")
	return true
}

// ============================================================================
// Function Wrappers - Convert between Wasmtime calling convention and our API
// ============================================================================

host_entity_get_pos_wrapper :: proc "c" (
	env: rawptr,
	caller: ^wasmtime_caller_t,
	args: [^]wasmtime_val_t,
	nargs: c.size_t,
	results: [^]wasmtime_val_t,
	nresults: c.size_t,
) -> ^wasm_trap_t {
	// For now, just return nil (no-op)
	return nil
}

host_entity_set_pos_wrapper :: proc "c" (
	env: rawptr,
	caller: ^wasmtime_caller_t,
	args: [^]wasmtime_val_t,
	nargs: c.size_t,
	results: [^]wasmtime_val_t,
	nresults: c.size_t,
) -> ^wasm_trap_t {
	return nil
}

host_entity_get_flip_x_wrapper :: proc "c" (env: rawptr, caller: ^wasmtime_caller_t, args: [^]wasmtime_val_t, nargs: c.size_t, results: [^]wasmtime_val_t, nresults: c.size_t) -> ^wasm_trap_t {
	results[0].kind = .I32
	results[0].of.i32 = 0
	return nil
}

host_entity_set_flip_x_wrapper :: proc "c" (env: rawptr, caller: ^wasmtime_caller_t, args: [^]wasmtime_val_t, nargs: c.size_t, results: [^]wasmtime_val_t, nresults: c.size_t) -> ^wasm_trap_t {
	return nil
}

host_entity_get_rotation_wrapper :: proc "c" (env: rawptr, caller: ^wasmtime_caller_t, args: [^]wasmtime_val_t, nargs: c.size_t, results: [^]wasmtime_val_t, nresults: c.size_t) -> ^wasm_trap_t {
	results[0].kind = .F32
	results[0].of.f32 = 0
	return nil
}

host_entity_set_rotation_wrapper :: proc "c" (env: rawptr, caller: ^wasmtime_caller_t, args: [^]wasmtime_val_t, nargs: c.size_t, results: [^]wasmtime_val_t, nresults: c.size_t) -> ^wasm_trap_t {
	return nil
}

host_entity_set_animation_wrapper :: proc "c" (env: rawptr, caller: ^wasmtime_caller_t, args: [^]wasmtime_val_t, nargs: c.size_t, results: [^]wasmtime_val_t, nresults: c.size_t) -> ^wasm_trap_t {
	return nil
}

host_spawn_entity_wrapper :: proc "c" (env: rawptr, caller: ^wasmtime_caller_t, args: [^]wasmtime_val_t, nargs: c.size_t, results: [^]wasmtime_val_t, nresults: c.size_t) -> ^wasm_trap_t {
	results[0].kind = .I64
	results[0].of.i64 = 0
	return nil
}

host_destroy_entity_wrapper :: proc "c" (env: rawptr, caller: ^wasmtime_caller_t, args: [^]wasmtime_val_t, nargs: c.size_t, results: [^]wasmtime_val_t, nresults: c.size_t) -> ^wasm_trap_t {
	return nil
}

host_get_input_vector_wrapper :: proc "c" (env: rawptr, caller: ^wasmtime_caller_t, args: [^]wasmtime_val_t, nargs: c.size_t, results: [^]wasmtime_val_t, nresults: c.size_t) -> ^wasm_trap_t {
	return nil
}

host_key_down_wrapper :: proc "c" (env: rawptr, caller: ^wasmtime_caller_t, args: [^]wasmtime_val_t, nargs: c.size_t, results: [^]wasmtime_val_t, nresults: c.size_t) -> ^wasm_trap_t {
	results[0].kind = .I32
	results[0].of.i32 = 0
	return nil
}

host_key_pressed_wrapper :: proc "c" (env: rawptr, caller: ^wasmtime_caller_t, args: [^]wasmtime_val_t, nargs: c.size_t, results: [^]wasmtime_val_t, nresults: c.size_t) -> ^wasm_trap_t {
	results[0].kind = .I32
	results[0].of.i32 = 0
	return nil
}

host_get_delta_time_wrapper :: proc "c" (env: rawptr, caller: ^wasmtime_caller_t, args: [^]wasmtime_val_t, nargs: c.size_t, results: [^]wasmtime_val_t, nresults: c.size_t) -> ^wasm_trap_t {
	results[0].kind = .F32
	results[0].of.f32 = 0.016
	return nil
}

host_get_game_time_wrapper :: proc "c" (env: rawptr, caller: ^wasmtime_caller_t, args: [^]wasmtime_val_t, nargs: c.size_t, results: [^]wasmtime_val_t, nresults: c.size_t) -> ^wasm_trap_t {
	results[0].kind = .F64
	results[0].of.f64 = 0
	return nil
}

host_log_info_wrapper :: proc "c" (env: rawptr, caller: ^wasmtime_caller_t, args: [^]wasmtime_val_t, nargs: c.size_t, results: [^]wasmtime_val_t, nresults: c.size_t) -> ^wasm_trap_t {
	return nil
}

host_log_warn_wrapper :: proc "c" (env: rawptr, caller: ^wasmtime_caller_t, args: [^]wasmtime_val_t, nargs: c.size_t, results: [^]wasmtime_val_t, nresults: c.size_t) -> ^wasm_trap_t {
	return nil
}

host_log_error_wrapper :: proc "c" (env: rawptr, caller: ^wasmtime_caller_t, args: [^]wasmtime_val_t, nargs: c.size_t, results: [^]wasmtime_val_t, nresults: c.size_t) -> ^wasm_trap_t {
	return nil
}

// ============================================================================
// Entity API - Exported to WASM
// ============================================================================

@(export, link_name="host_entity_get_pos")
host_entity_get_pos :: proc "c" (entity_id: u64, out_x, out_y: ^f32) {
	if host_context == nil do return
	context = host_our_context^
	
	// TODO: Implement entity lookup
	out_x^ = 0
	out_y^ = 0
}

@(export, link_name="host_entity_set_pos")
host_entity_set_pos :: proc "c" (entity_id: u64, x, y: f32) {
	if host_context == nil do return
	context = host_our_context^
	
	// TODO: Implement entity position setting
}

@(export, link_name="host_entity_get_flip_x")
host_entity_get_flip_x :: proc "c" (entity_id: u64) -> c.bool {
	if host_context == nil do return false
	context = host_our_context^
	
	// TODO: Implement flip_x getter
	return false
}

@(export, link_name="host_entity_set_flip_x")
host_entity_set_flip_x :: proc "c" (entity_id: u64, flip: c.bool) {
	if host_context == nil do return
	context = host_our_context^
	
	// TODO: Implement flip_x setter
}

@(export, link_name="host_entity_get_rotation")
host_entity_get_rotation :: proc "c" (entity_id: u64) -> f32 {
	if host_context == nil do return 0
	context = host_our_context^
	
	// TODO: Implement rotation getter
	return 0
}

@(export, link_name="host_entity_set_rotation")
host_entity_set_rotation :: proc "c" (entity_id: u64, rotation: f32) {
	if host_context == nil do return
	context = host_our_context^
	
	// TODO: Implement rotation setter
}

@(export, link_name="host_entity_set_animation")
host_entity_set_animation :: proc "c" (entity_id: u64, sprite_name: cstring, frame_duration: f32, loop: c.bool) {
	if host_context == nil do return
	context = host_our_context^
	
	entity := entity_from_id(entity_id)
	if entity == nil {
		log.warnf("host_entity_set_animation: Invalid entity ID %d", entity_id)
		return
	}
	
	// TODO: Convert sprite name to enum and call entity_set_animation
	// For now, just log
	log.infof("host_entity_set_animation: entity_id=%d, sprite=%s", entity_id, sprite_name)
}

@(export, link_name="host_spawn_entity")
host_spawn_entity :: proc "c" (script_name: cstring, x, y: f32) -> u64 {
	if host_context == nil do return 0
	context = host_our_context^
	
	// TODO: Implement entity spawning
	log.infof("host_spawn_entity: %s at (%f, %f)", script_name, x, y)
	return 1 // Return dummy ID
}

@(export, link_name="host_destroy_entity")
host_destroy_entity :: proc "c" (entity_id: u64) {
	if host_context == nil do return
	context = host_our_context^
	
	entity := entity_from_id(entity_id)
	if entity == nil {
		log.warnf("host_destroy_entity: Invalid entity ID %d", entity_id)
		return
	}
	
	// TODO: Call entity_destroy
	log.infof("host_destroy_entity: entity_id=%d", entity_id)
}

// ============================================================================
// Input API - Exported to WASM
// ============================================================================

@(export, link_name="host_get_input_vector")
host_get_input_vector :: proc "c" (out_x, out_y: ^f32) {
	if host_context == nil do return
	context = host_our_context^
	
	// TODO: Get input vector
	out_x^ = 0
	out_y^ = 0
}

@(export, link_name="host_key_down")
host_key_down :: proc "c" (action_name: cstring) -> c.bool {
	if host_context == nil do return false
	context = host_our_context^
	
	// TODO: Check key down
	return false
}

@(export, link_name="host_key_pressed")
host_key_pressed :: proc "c" (action_name: cstring) -> c.bool {
	if host_context == nil do return false
	context = host_our_context^
	
	// TODO: Check key pressed
	return false
}

// ============================================================================
// Game State API - Exported to WASM
// ============================================================================

@(export, link_name="host_get_delta_time")
host_get_delta_time :: proc "c" () -> f32 {
	if host_context == nil do return 0
	// TODO: Get actual delta_t from context
	return 0.016
}

@(export, link_name="host_get_game_time")
host_get_game_time :: proc "c" () -> f64 {
	if host_context == nil do return 0
	// TODO: Get actual game time from context
	return 0
}

// ============================================================================
// Logging API - Exported to WASM
// ============================================================================

@(export, link_name="host_log_info")
host_log_info :: proc "c" (message: cstring) {
	context = host_our_context^
	log.infof("[WASM] %s", message)
}

@(export, link_name="host_log_warn")
host_log_warn :: proc "c" (message: cstring) {
	context = host_our_context^
	log.warnf("[WASM] %s", message)
}

@(export, link_name="host_log_error")
host_log_error :: proc "c" (message: cstring) {
	context = host_our_context^
	log.errorf("[WASM] %s", message)
}

// ============================================================================
// Helper Functions
// ============================================================================

// Find entity by ID (not handle)
// TODO: Implement proper entity lookup once we can access game state
entity_from_id :: proc(id: u64) -> rawptr {
	return nil
}

// Spawn a WASM-controlled entity
// TODO: Implement proper entity spawning
spawn_wasm_entity :: proc(script_name: string) -> rawptr {
	log.infof("Spawned WASM entity: %s", script_name)
	return nil
}

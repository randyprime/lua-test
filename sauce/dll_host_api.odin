package main

import "core:log"
import "core:c"
import "base:runtime"

/*

Host API Implementation for DLL Mods

These functions are exported with C ABI and can be called directly by DLL mods.
Much simpler than the WASM version - no wrappers or linker registration needed.

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
// Entity API - Exported to DLL Mods
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

	// TODO: Implement animation setter
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

	// TODO: Implement entity destroy
	log.infof("host_destroy_entity: entity_id=%d", entity_id)
}

// ============================================================================
// Input API - Exported to DLL Mods
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
// Game State API - Exported to DLL Mods
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
// Logging API - Exported to DLL Mods
// ============================================================================

@(export, link_name="host_log_info")
host_log_info :: proc "c" (message: cstring) {
	context = host_our_context^
	log.infof("[MOD] %s", message)
}

@(export, link_name="host_log_warn")
host_log_warn :: proc "c" (message: cstring) {
	context = host_our_context^
	log.warnf("[MOD] %s", message)
}

@(export, link_name="host_log_error")
host_log_error :: proc "c" (message: cstring) {
	context = host_our_context^
	log.errorf("[MOD] %s", message)
}

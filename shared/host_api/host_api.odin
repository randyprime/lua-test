package host_api

import "core:c"

/*

Host API Definitions

This package is used by BOTH the host engine and WASM guest mods.
- When compiled as WASM (guest), these are foreign imports from the host
- When compiled as native (host), these are stub declarations

This ensures type safety across the host/guest boundary.

*/

Vec2 :: struct {
	x, y: f32,
}

// ============================================================================
// Entity API
// ============================================================================

when ODIN_ARCH == .wasm32 {
	// Guest side: import from host
	foreign import host "env"
	
	@(default_calling_convention="c")
	foreign host {
		// Position
		host_entity_get_pos :: proc(entity_id: u64, out_x, out_y: ^f32) ---
		host_entity_set_pos :: proc(entity_id: u64, x, y: f32) ---
		
		// Flip
		host_entity_get_flip_x :: proc(entity_id: u64) -> c.bool ---
		host_entity_set_flip_x :: proc(entity_id: u64, flip: c.bool) ---
		
		// Rotation
		host_entity_get_rotation :: proc(entity_id: u64) -> f32 ---
		host_entity_set_rotation :: proc(entity_id: u64, rotation: f32) ---
		
		// Animation
		host_entity_set_animation :: proc(entity_id: u64, sprite_name: cstring, frame_duration: f32, loop: c.bool) ---
		
		// Spawning/Destroying
		host_spawn_entity :: proc(script_name: cstring, x, y: f32) -> u64 ---
		host_destroy_entity :: proc(entity_id: u64) ---
	}
	
} else {
	// Host side: stub declarations (actual implementations in wasm_host_api.odin)
	host_entity_get_pos :: proc(entity_id: u64, out_x, out_y: ^f32) { }
	host_entity_set_pos :: proc(entity_id: u64, x, y: f32) { }
	host_entity_get_flip_x :: proc(entity_id: u64) -> c.bool { return false }
	host_entity_set_flip_x :: proc(entity_id: u64, flip: c.bool) { }
	host_entity_get_rotation :: proc(entity_id: u64) -> f32 { return 0 }
	host_entity_set_rotation :: proc(entity_id: u64, rotation: f32) { }
	host_entity_set_animation :: proc(entity_id: u64, sprite_name: cstring, frame_duration: f32, loop: c.bool) { }
	host_spawn_entity :: proc(script_name: cstring, x, y: f32) -> u64 { return 0 }
	host_destroy_entity :: proc(entity_id: u64) { }
}

// ============================================================================
// Input API
// ============================================================================

when ODIN_ARCH == .wasm32 {
	@(default_calling_convention="c")
	foreign host {
		host_get_input_vector :: proc(out_x, out_y: ^f32) ---
		host_key_down :: proc(action_name: cstring) -> c.bool ---
		host_key_pressed :: proc(action_name: cstring) -> c.bool ---
	}
} else {
	host_get_input_vector :: proc(out_x, out_y: ^f32) { }
	host_key_down :: proc(action_name: cstring) -> c.bool { return false }
	host_key_pressed :: proc(action_name: cstring) -> c.bool { return false }
}

// ============================================================================
// Game State API
// ============================================================================

when ODIN_ARCH == .wasm32 {
	@(default_calling_convention="c")
	foreign host {
		host_get_delta_time :: proc() -> f32 ---
		host_get_game_time :: proc() -> f64 ---
	}
} else {
	host_get_delta_time :: proc() -> f32 { return 0 }
	host_get_game_time :: proc() -> f64 { return 0 }
}

// ============================================================================
// Logging API
// ============================================================================

when ODIN_ARCH == .wasm32 {
	@(default_calling_convention="c")
	foreign host {
		host_log_info :: proc(message: cstring) ---
		host_log_warn :: proc(message: cstring) ---
		host_log_error :: proc(message: cstring) ---
	}
} else {
	host_log_info :: proc(message: cstring) { }
	host_log_warn :: proc(message: cstring) { }
	host_log_error :: proc(message: cstring) { }
}

// ============================================================================
// Convenience wrappers for WASM guest code
// ============================================================================

when ODIN_ARCH == .wasm32 {
	// Nicer API for getting position as Vec2
	entity_get_pos :: proc "contextless" (entity_id: u64) -> Vec2 {
		pos: Vec2
		host_entity_get_pos(entity_id, &pos.x, &pos.y)
		return pos
	}
	
	entity_set_pos :: proc "contextless" (entity_id: u64, pos: Vec2) {
		host_entity_set_pos(entity_id, pos.x, pos.y)
	}
	
	entity_get_flip_x :: proc "contextless" (entity_id: u64) -> bool {
		return bool(host_entity_get_flip_x(entity_id))
	}
	
	entity_set_flip_x :: proc "contextless" (entity_id: u64, flip: bool) {
		host_entity_set_flip_x(entity_id, c.bool(flip))
	}
	
	entity_get_rotation :: proc "contextless" (entity_id: u64) -> f32 {
		return host_entity_get_rotation(entity_id)
	}
	
	entity_set_rotation :: proc "contextless" (entity_id: u64, rotation: f32) {
		host_entity_set_rotation(entity_id, rotation)
	}
	
	entity_set_animation :: proc "contextless" (entity_id: u64, sprite_name: string, frame_duration: f32, loop := true) {
		cstr := cstring(raw_data(sprite_name))
		host_entity_set_animation(entity_id, cstr, frame_duration, c.bool(loop))
	}
	
	spawn_entity :: proc "contextless" (script_name: string, x, y: f32) -> u64 {
		cstr := cstring(raw_data(script_name))
		return host_spawn_entity(cstr, x, y)
	}
	
	destroy_entity :: proc "contextless" (entity_id: u64) {
		host_destroy_entity(entity_id)
	}
	
	get_input_vector :: proc "contextless" () -> Vec2 {
		input: Vec2
		host_get_input_vector(&input.x, &input.y)
		return input
	}
	
	key_down :: proc "contextless" (action_name: string) -> bool {
		cstr := cstring(raw_data(action_name))
		return bool(host_key_down(cstr))
	}
	
	key_pressed :: proc "contextless" (action_name: string) -> bool {
		cstr := cstring(raw_data(action_name))
		return bool(host_key_pressed(cstr))
	}
	
	get_delta_time :: proc "contextless" () -> f32 {
		return host_get_delta_time()
	}
	
	get_game_time :: proc "contextless" () -> f64 {
		return host_get_game_time()
	}
	
	log_info :: proc "contextless" (message: string) {
		cstr := cstring(raw_data(message))
		host_log_info(cstr)
	}
	
	log_warn :: proc "contextless" (message: string) {
		cstr := cstring(raw_data(message))
		host_log_warn(cstr)
	}
	
	log_error :: proc "contextless" (message: string) {
		cstr := cstring(raw_data(message))
		host_log_error(cstr)
	}
}


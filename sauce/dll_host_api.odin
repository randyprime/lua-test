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

	// Look up entity by ID
	for i in 1..=ctx.gs.entity_top_count {
		e := &ctx.gs.entities[i]
		if u64(e.handle.id) == entity_id {
			out_x^ = e.pos.x
			out_y^ = e.pos.y
			return
		}
	}
	out_x^ = 0
	out_y^ = 0
}

@(export, link_name="host_entity_set_pos")
host_entity_set_pos :: proc "c" (entity_id: u64, x, y: f32) {
	if host_context == nil do return
	context = host_our_context^

	// Look up entity by ID and set position
	for i in 1..=ctx.gs.entity_top_count {
		e := &ctx.gs.entities[i]
		if u64(e.handle.id) == entity_id {
			e.pos.x = x
			e.pos.y = y
			return
		}
	}
}

@(export, link_name="host_entity_get_flip_x")
host_entity_get_flip_x :: proc "c" (entity_id: u64) -> c.bool {
	if host_context == nil do return false
	context = host_our_context^

	// Look up entity by ID
	for i in 1..=ctx.gs.entity_top_count {
		e := &ctx.gs.entities[i]
		if u64(e.handle.id) == entity_id {
			return c.bool(e.flip_x)
		}
	}
	return false
}

@(export, link_name="host_entity_set_flip_x")
host_entity_set_flip_x :: proc "c" (entity_id: u64, flip: c.bool) {
	if host_context == nil do return
	context = host_our_context^

	// Look up entity by ID and set flip_x
	for i in 1..=ctx.gs.entity_top_count {
		e := &ctx.gs.entities[i]
		if u64(e.handle.id) == entity_id {
			e.flip_x = bool(flip)
			return
		}
	}
}

@(export, link_name="host_entity_get_rotation")
host_entity_get_rotation :: proc "c" (entity_id: u64) -> f32 {
	if host_context == nil do return 0
	context = host_our_context^

	// Look up entity by ID
	for i in 1..=ctx.gs.entity_top_count {
		e := &ctx.gs.entities[i]
		if u64(e.handle.id) == entity_id {
			return e.rotation
		}
	}
	return 0
}

@(export, link_name="host_entity_set_rotation")
host_entity_set_rotation :: proc "c" (entity_id: u64, rotation: f32) {
	if host_context == nil do return
	context = host_our_context^

	// Look up entity by ID and set rotation
	for i in 1..=ctx.gs.entity_top_count {
		e := &ctx.gs.entities[i]
		if u64(e.handle.id) == entity_id {
			e.rotation = rotation
			return
		}
	}
}

@(export, link_name="host_entity_set_animation")
host_entity_set_animation :: proc "c" (entity_id: u64, sprite_name: cstring, frame_duration: f32, loop: c.bool) {
	if host_context == nil do return
	context = host_our_context^

	// Look up entity by ID and set animation
	for i in 1..=ctx.gs.entity_top_count {
		e := &ctx.gs.entities[i]
		if u64(e.handle.id) == entity_id {
			// Convert sprite name string to Sprite_Name enum
			name := string(sprite_name)
			sprite := Sprite_Name.nil
			switch name {
			case "player_idle": sprite = .player_idle
			case "player_run": sprite = .player_run
			case "player_still": sprite = .player_still
			case "player_death": sprite = .player_death
			}

			if sprite != .nil {
				entity_set_animation(e, sprite, frame_duration, bool(loop))
			}
			return
		}
	}
}

@(export, link_name="host_spawn_entity")
host_spawn_entity :: proc "c" (script_name: cstring, x, y: f32) -> u64 {
	if host_context == nil do return 0
	context = host_our_context^

	// Create entity with the script name
	e := entity_create(string(script_name))
	e.pos = Vec2{x, y}

	// Set default sprite based on script name
	name := string(script_name)
	switch name {
	case "player": e.sprite = .player_idle
	case "wanderer": e.sprite = .player_idle
	case "spinner": e.sprite = .player_still
	}

	log.infof("host_spawn_entity: %s at (%f, %f) -> ID %d", script_name, x, y, e.handle.id)
	return u64(e.handle.id)
}

@(export, link_name="host_destroy_entity")
host_destroy_entity :: proc "c" (entity_id: u64) {
	if host_context == nil do return
	context = host_our_context^

	// Look up entity by ID and destroy it
	for i in 1..=ctx.gs.entity_top_count {
		e := &ctx.gs.entities[i]
		if u64(e.handle.id) == entity_id {
			entity_destroy(e)
			log.infof("host_destroy_entity: entity_id=%d", entity_id)
			return
		}
	}
}

// ============================================================================
// Input API - Exported to DLL Mods
// ============================================================================

@(export, link_name="host_get_input_vector")
host_get_input_vector :: proc "c" (out_x, out_y: ^f32) {
	if host_context == nil do return
	context = host_our_context^

	// Get input vector from game utils
	input := get_input_vector()
	out_x^ = input.x
	out_y^ = input.y
}

@(export, link_name="host_key_down")
host_key_down :: proc "c" (action_name: cstring) -> c.bool {
	if host_context == nil do return false
	context = host_our_context^

	// Convert action name to Input_Action enum
	name := string(action_name)
	action := Input_Action.left // default
	switch name {
	case "left": action = .left
	case "right": action = .right
	case "up": action = .up
	case "down": action = .down
	case "click": action = .click
	case "use": action = .use
	case "interact": action = .interact
	}

	return c.bool(is_action_down(action))
}

@(export, link_name="host_key_pressed")
host_key_pressed :: proc "c" (action_name: cstring) -> c.bool {
	if host_context == nil do return false
	context = host_our_context^

	// Convert action name to Input_Action enum
	name := string(action_name)
	action := Input_Action.left // default
	switch name {
	case "left": action = .left
	case "right": action = .right
	case "up": action = .up
	case "down": action = .down
	case "click": action = .click
	case "use": action = .use
	case "interact": action = .interact
	}

	return c.bool(is_action_pressed(action))
}

// ============================================================================
// Game State API - Exported to DLL Mods
// ============================================================================

@(export, link_name="host_get_delta_time")
host_get_delta_time :: proc "c" () -> f32 {
	if host_context == nil do return 0
	context = host_our_context^
	return ctx.delta_t
}

@(export, link_name="host_get_game_time")
host_get_game_time :: proc "c" () -> f64 {
	if host_context == nil do return 0
	context = host_our_context^
	return ctx.gs.game_time_elapsed
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

#+feature global-context
package core_mod

import api "../../shared/host_api"

/*

Core Mod - Main Entry Point

This is the core game mod, containing all base gameplay logic.
By building the entire game as a mod, we ensure the modding API is robust.

*/

// Mod initialization - called once when mod loads
@(export)
mod_init :: proc "c" () {
	// Spawn initial entities
	// The host will track entity script names and call entity_update_by_name
	_ = api.spawn_entity("player", 0, 0)
	_ = api.spawn_entity("wanderer", -60, 0)
	_ = api.spawn_entity("spinner", 60, 0)
}

// Mod update - called every frame
@(export)
mod_update :: proc "c" (dt: f32) {
	// General game logic can go here
}

// Entity update dispatch - called for each entity by script name
@(export)
entity_update_by_name :: proc "c" (script_name: cstring, entity_id: u64, dt: f32) {
	// Dispatch based on script name
	name := string(script_name)
	switch name {
	case "player":
		player_update(entity_id, dt)
	case "wanderer":
		wanderer_update(entity_id, dt)
	case "spinner":
		spinner_update(entity_id, dt)
	}
}

// Mod shutdown - called when mod unloads
@(export)
mod_shutdown :: proc "c" () {
	// Cleanup if needed
}

// ============================================================================
// Entity Implementations
// ============================================================================

// Player Entity
// -----------------------------------------------------------------------------

player_update :: proc "contextless" (entity_id: u64, dt: f32) {
	input := api.get_input_vector()
	pos := api.entity_get_pos(entity_id)
	
	move_speed: f32 = 100.0
	new_pos := api.Vec2{
		x = pos.x + input.x * move_speed * dt,
		y = pos.y + input.y * move_speed * dt,
	}
	api.entity_set_pos(entity_id, new_pos)
	
	// Flip sprite based on direction
	if input.x < 0 {
		api.entity_set_flip_x(entity_id, true)
	} else if input.x > 0 {
		api.entity_set_flip_x(entity_id, false)
	}
	
	if input.x == 0 && input.y == 0 {
		api.entity_set_animation(entity_id, "player_idle", 0.3, true)
	} else {
		api.entity_set_animation(entity_id, "player_run", 0.1, true)
	}
}

// Wanderer Entity
// -----------------------------------------------------------------------------

wanderer_update :: proc "contextless" (entity_id: u64, dt: f32) {
	pos := api.entity_get_pos(entity_id)
	
	// Simple back-and-forth movement
	wander_speed: f32 = 50.0
	new_x := pos.x + wander_speed * dt
	
	// TODO: Add proper state tracking for direction changes
	new_pos := api.Vec2{
		x = new_x,
		y = pos.y,
	}
	api.entity_set_pos(entity_id, new_pos)
	
	api.entity_set_animation(entity_id, "player_idle", 0.3, true)
}

// Spinner Entity
// -----------------------------------------------------------------------------

spinner_update :: proc "contextless" (entity_id: u64, dt: f32) {
	// Spin the entity
	spin_speed: f32 = 2.0
	current_rotation := api.entity_get_rotation(entity_id)
	api.entity_set_rotation(entity_id, current_rotation + spin_speed * dt)
	
	api.entity_set_animation(entity_id, "player_still", 0.2, true)
}


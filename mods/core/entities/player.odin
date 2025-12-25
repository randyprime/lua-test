package core_mod

import api "shared:host_api"

/*

Player Entity

Main player character controlled by user input.
Migrated from player.lua to native Odin WASM.

*/

// Player state (stored per-instance, could be expanded)
Player_State :: struct {
	last_known_x_dir: f32,
}

// Global player states (indexed by entity ID)
// In a real implementation, you might want a better way to manage per-entity state
player_states: map[u64]Player_State

// Initialize player (called first time)
player_init :: proc(entity_id: u64) {
	if entity_id not_in player_states {
		player_states[entity_id] = Player_State{
			last_known_x_dir = 1.0,
		}
	}
}

// Player update function
player_update :: proc(entity_id: u64, dt: f32) {
	// Ensure state exists
	player_init(entity_id)
	state := &player_states[entity_id]
	
	// Get input
	input := api.get_input_vector()
	
	// Get current position
	pos := api.entity_get_pos(entity_id)
	
	// Move player
	move_speed: f32 = 100.0
	new_pos := api.Vec2{
		x = pos.x + input.x * move_speed * dt,
		y = pos.y + input.y * move_speed * dt,
	}
	api.entity_set_pos(entity_id, new_pos)
	
	// Track last known direction
	if input.x != 0 {
		state.last_known_x_dir = input.x
	}
	
	// Flip sprite based on direction
	api.entity_set_flip_x(entity_id, state.last_known_x_dir < 0)
	
	// Set animation based on movement
	if input.x == 0 && input.y == 0 {
		api.entity_set_animation(entity_id, "player_idle", 0.3, true)
	} else {
		api.entity_set_animation(entity_id, "player_run", 0.1, true)
	}
}


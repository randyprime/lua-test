package core_mod

import api "shared:host_api"
import "core:math"
import "core:math/rand"

/*

Wanderer Entity

Wanders left and right, changing direction periodically.
Tests timer countdown and discrete state changes.

*/

Wanderer_State :: struct {
	wander_speed: f32,
	wander_dir: f32,             // current direction: 1 or -1
	change_dir_timer: f32,       // counts down to direction change
	change_dir_interval: f32,    // seconds between direction changes
}

// Global wanderer states
wanderer_states: map[u64]Wanderer_State

// Initialize wanderer
wanderer_init :: proc(entity_id: u64) {
	if entity_id not_in wanderer_states {
		wanderer_states[entity_id] = Wanderer_State{
			wander_speed = 50.0,
			wander_dir = 1.0,
			change_dir_timer = 2.0,
			change_dir_interval = 2.0,
		}
	}
}

// Wanderer update function
wanderer_update :: proc(entity_id: u64, dt: f32) {
	// Ensure state exists
	wanderer_init(entity_id)
	state := &wanderer_states[entity_id]
	
	// Get current position
	pos := api.entity_get_pos(entity_id)
	
	// Update direction change timer
	state.change_dir_timer -= dt
	if state.change_dir_timer <= 0 {
		// Randomly change direction
		state.wander_dir = rand.float32() > 0.5 ? 1.0 : -1.0
		state.change_dir_timer = state.change_dir_interval
	}
	
	// Move entity
	new_pos := api.Vec2{
		x = pos.x + state.wander_dir * state.wander_speed * dt,
		y = pos.y,
	}
	api.entity_set_pos(entity_id, new_pos)
	
	// Flip sprite based on direction
	api.entity_set_flip_x(entity_id, state.wander_dir < 0)
	
	// Set animation
	api.entity_set_animation(entity_id, "player_idle", 0.3, true)
}


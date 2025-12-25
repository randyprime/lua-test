package core_mod

import api "shared:host_api"
import "core:math"

/*

Spinner Entity

Spins and bobs up and down.
Tests time accumulation and computed values.

*/

Spinner_State :: struct {
	spin_speed: f32,      // radians per second
	bob_speed: f32,
	bob_amount: f32,
	start_y: f32,         // computed on first frame
	time: f32,            // accumulates over time
	initialized: bool,
}

// Global spinner states
spinner_states: map[u64]Spinner_State

// Initialize spinner
spinner_init :: proc(entity_id: u64) {
	if entity_id not_in spinner_states {
		spinner_states[entity_id] = Spinner_State{
			spin_speed = 2.0,
			bob_speed = 1.0,
			bob_amount = 10.0,
			start_y = 0.0,
			time = 0.0,
			initialized = false,
		}
	}
}

// Spinner update function
spinner_update :: proc(entity_id: u64, dt: f32) {
	// Ensure state exists
	spinner_init(entity_id)
	state := &spinner_states[entity_id]
	
	// Get current position
	pos := api.entity_get_pos(entity_id)
	
	// Initialize start_y on first frame
	if !state.initialized {
		state.start_y = pos.y
		state.initialized = true
	}
	
	// Update time
	state.time += dt
	
	// Spin
	current_rotation := api.entity_get_rotation(entity_id)
	api.entity_set_rotation(entity_id, current_rotation + state.spin_speed * dt)
	
	// Bob up and down
	bob_offset := math.sin_f32(state.time * state.bob_speed) * state.bob_amount
	new_pos := api.Vec2{
		x = pos.x,
		y = state.start_y + bob_offset,
	}
	api.entity_set_pos(entity_id, new_pos)
	
	// Set animation
	api.entity_set_animation(entity_id, "player_still", 0.2, true)
}


#+feature global-context
package example_mod

import api "../../shared/host_api"

/*

Example Mod

Demonstrates how to create a custom mod with custom entities.
Shows off the DLL modding API capabilities.

*/

// Mod initialization - called once when mod loads
@(export)
mod_init :: proc "c" () {
	// Spawn a custom orbiter entity
	_ = api.spawn_entity("orbiter", 30, 30)
}

// Mod update - called every frame
@(export)
mod_update :: proc "c" (dt: f32) {
	// Could add global mod logic here
	// For example, wave spawning, game mode logic, etc.
}

// Entity update dispatch - called for each entity by script name
@(export)
entity_update_by_name :: proc "c" (script_name: cstring, entity_id: u64, dt: f32) {
	name := string(script_name)
	switch name {
	case "orbiter":
		orbiter_update(entity_id, dt)
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

// Orbiter Entity
// -----------------------------------------------------------------------------

import "core:math"

Orbiter_State :: struct {
	center: api.Vec2,
	orbit_radius: f32,
	orbit_speed: f32,
	angle: f32,
	initialized: bool,
}

// Global orbiter states
orbiter_states: map[u64]Orbiter_State

// Initialize orbiter
orbiter_init :: proc "contextless" (entity_id: u64) {
	if entity_id not_in orbiter_states {
		// Get initial position as center
		pos := api.entity_get_pos(entity_id)

		orbiter_states[entity_id] = Orbiter_State{
			center = pos,
			orbit_radius = 50.0,
			orbit_speed = 2.0,
			angle = 0.0,
			initialized = true,
		}
	}
}

// Orbiter update function
orbiter_update :: proc "contextless" (entity_id: u64, dt: f32) {
	// Ensure state exists
	orbiter_init(entity_id)
	state := &orbiter_states[entity_id]

	// Update angle
	state.angle += state.orbit_speed * dt

	// Calculate orbital position
	orbit_x := state.center.x + math.cos_f32(state.angle) * state.orbit_radius
	orbit_y := state.center.y + math.sin_f32(state.angle) * state.orbit_radius

	// Set position
	api.entity_set_pos(entity_id, api.Vec2{x = orbit_x, y = orbit_y})

	// Rotate sprite to face direction of movement
	rotation := state.angle + math.PI / 2.0 // +90 degrees to face forward
	api.entity_set_rotation(entity_id, rotation)

	// Set animation
	api.entity_set_animation(entity_id, "player_still", 0.2, true)

	// Visual feedback: flip based on which half of orbit we're on
	api.entity_set_flip_x(entity_id, orbit_x < state.center.x)
}


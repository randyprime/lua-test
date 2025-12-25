package example_mod

import api "shared:host_api"

/*

Example Mod

Demonstrates how to create a custom mod with custom entities.
Shows off the WASM modding API capabilities.

*/

// Entity registry
Entity_Update_Func :: proc(entity_id: u64, dt: f32)
entity_registry: map[u64]Entity_Update_Func

// Mod initialization
@(export)
mod_init :: proc "c" () {
	api.log_info("Example mod initializing...")
	
	// Initialize entity registry
	entity_registry = make(map[u64]Entity_Update_Func)
	
	// Spawn a custom orbiter entity
	orbiter_id := api.spawn_entity("orbiter", 30, 30)
	if orbiter_id != 0 {
		entity_registry[orbiter_id] = orbiter_update
		api.log_info("Spawned orbiter entity")
	}
	
	api.log_info("Example mod initialized successfully")
}

// Mod update
@(export)
mod_update :: proc "c" (dt: f32) {
	// Could add global mod logic here
	// For example, wave spawning, game mode logic, etc.
}

// Entity update dispatch
@(export)
entity_update :: proc "c" (entity_id: u64, dt: f32) {
	if update_func, ok := entity_registry[entity_id]; ok {
		update_func(entity_id, dt)
	}
}

// Mod shutdown
@(export)
mod_shutdown :: proc "c" () {
	api.log_info("Example mod shutting down...")
	delete(entity_registry)
	api.log_info("Example mod shut down")
}

// Include entity implementations
#load "entities/orbiter.odin"


package main

/*

This is a nice lil cosy spot for the backbone of the entity system.

Entity structure can vary greatly or subtly from game to game depending on the constraints.
So it doesn't really make sense to abstract this away into a package.
It adds too much friction.

*/

MAX_ENTITIES :: 2048 // increase this as needed.

import "base:runtime"
import "core:log"
import "core:fmt"

Entity_Handle :: struct {
	index: int,

	// I prefer assigning a unique ID to each entity, instead of going the generational
	// handle route. Makes trying to debug things a bit easier if we know for a fact
	// an entity cannot have the same ID as another one.
	id: int,
}

zero_entity: Entity // #readonlytodo

get_all_ents :: proc() -> []Entity_Handle {
	return ctx.gs.scratch.all_entities
}

is_valid :: proc {
	entity_is_valid,
	entity_is_valid_ptr,
}
entity_is_valid :: proc(entity: Entity) -> bool {
	return entity.handle.id != 0
}
entity_is_valid_ptr :: proc(entity: ^Entity) -> bool {
	return entity != nil && entity_is_valid(entity^)
}

entity_init_core :: proc() {
	// make sure the zero entity has good defaults, so we don't crash on stuff like functions pointers
	entity_setup(&zero_entity)
}

entity_from_handle :: proc(handle: Entity_Handle) -> (entity: ^Entity, ok:bool) #optional_ok {
	if handle.index <= 0 || handle.index > ctx.gs.entity_top_count {
		return &zero_entity, false
	}

	ent := &ctx.gs.entities[handle.index]
	if ent.handle.id != handle.id {
		return &zero_entity, false
	}

	return ent, true
}

entity_create :: proc(script_name: string) -> ^Entity {
	// Simply forward to spawn_lua_entity which handles everything
	return spawn_lua_entity(script_name)
}

entity_destroy :: proc(e: ^Entity) {
	// Clean up Lua references if this is a Lua entity
	if e.is_lua_entity {
		lua_release_entity(e)
	}
	
	append(&ctx.gs.entity_free_list, e.handle.index)
	e^ = {}
}
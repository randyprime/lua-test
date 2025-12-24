package main

/*

Lua Scripting System

Handles Lua state initialization, script loading, and entity script management.

*/

import "core:log"
import "core:fmt"
import "core:c"
import "core:os"
import "base:runtime"
import lua "vendor:lua/5.4"

// Global Lua state
lua_state: ^lua.State

// Lua registry indices for entity references
LUA_ENTITY_REGISTRY :: "ENTITY_REGISTRY"
LUA_CURRENT_ENTITY :: "CURRENT_ENTITY"

// Initialize Lua state and register API
lua_init :: proc() {
	log.info("Initializing Lua scripting system...")
	
	// Try to create Lua state with default allocator first
	lua_state = lua.L_newstate()
	
	if lua_state == nil {
		log.error("Failed to create Lua state - Lua support disabled")
		return
	}
	
	// Load standard libraries
	lua.L_openlibs(lua_state)
	
	// Register our game API functions
	register_lua_api()
	
	log.info("Lua scripting system initialized successfully")
}

// Shutdown Lua state
lua_shutdown :: proc() {
	if lua_state != nil {
		lua.close(lua_state)
		lua_state = nil
	}
}

// Custom allocator for Lua that uses Odin's memory management
lua_allocator :: proc "c" (ud: rawptr, ptr: rawptr, osize, nsize: c.size_t) -> rawptr {
	old_size := int(osize)
	new_size := int(nsize)
	context = (^runtime.Context)(ud)^
	
	if ptr == nil {
		if new_size == 0 do return nil
		data, err := runtime.mem_alloc(new_size)
		return raw_data(data) if err == .None else nil
	} else {
		if nsize > 0 {
			data, err := runtime.mem_resize(ptr, old_size, new_size)
			return raw_data(data) if err == .None else nil
		} else {
			runtime.mem_free(ptr)
			return nil
		}
	}
}

// Load a Lua entity script and create an entity from it
load_lua_entity :: proc(script_path: string) -> ^Entity {
	if lua_state == nil {
		log.error("Lua state not initialized - call lua_init() first!")
		return nil
	}
	
	log.infof("Loading Lua entity from: %s", script_path)
	
	// Check if file exists first
	if !os.exists(script_path) {
		log.errorf("Lua script file not found: %s", script_path)
		return nil
	}
	
	// Create the entity first
	entity := entity_create(.lua_scripted)
	
	// Load and execute the Lua script
	cpath := fmt.ctprintf("%s", script_path)
	load_result := lua.L_loadfile(lua_state, cpath)
	if load_result != .OK {
		error_msg := lua.tostring(lua_state, -1)
		log.errorf("Failed to load Lua script '%s': %s (error code: %v)", script_path, error_msg, load_result)
		lua.pop(lua_state, 1)
		entity_destroy(entity)
		return nil
	}
	
	// Execute the script (should return a table)
	if lua.pcall(lua_state, 0, 1, 0) != 0 {
		error_msg := lua.tostring(lua_state, -1)
		log.errorf("Failed to execute Lua script '%s': %s", script_path, error_msg)
		lua.pop(lua_state, 1)
		entity_destroy(entity)
		return nil
	}
	
	// The script should return a table with the entity definition
	if !lua.istable(lua_state, -1) {
		log.errorf("Lua script '%s' did not return a table", script_path)
		lua.pop(lua_state, 1)
		entity_destroy(entity)
		return nil
	}
	
	// Store the entity table in the registry with the entity's ID as the key
	ref := lua.L_ref(lua_state, lua.REGISTRYINDEX)
	entity.lua_data_ref = int(ref)
	
	log.infof("Loaded Lua entity from '%s' (ref: %d)", script_path, ref)
	
	return entity
}

// Call the update function for a Lua entity
lua_call_entity_update :: proc(entity: ^Entity) {
	if lua_state == nil || entity.lua_data_ref == 0 {
		return
	}
	
	// Push the entity table onto the stack
	lua.rawgeti(lua_state, lua.REGISTRYINDEX, lua.Integer(entity.lua_data_ref))
	
	if !lua.istable(lua_state, -1) {
		log.error("Invalid Lua entity reference")
		lua.pop(lua_state, 1)
		return
	}
	
	// Set the current entity so API functions can access it
	lua.pushlightuserdata(lua_state, entity)
	lua.setglobal(lua_state, LUA_CURRENT_ENTITY)
	
	// Get the update function from the table
	lua.getfield(lua_state, -1, "update")
	
	if !lua.isfunction(lua_state, -1) {
		// No update function, that's okay
		lua.pop(lua_state, 2)
		return
	}
	
	// Push self (the entity table) as first argument
	lua.pushvalue(lua_state, -2)
	
	// Push delta time as second argument
	lua.pushnumber(lua_state, lua.Number(ctx.delta_t))
	
	// Call entity:update(dt)
	if lua.pcall(lua_state, 2, 0, 0) != 0 {
		error_msg := lua.tostring(lua_state, -1)
		log.errorf("Error calling Lua entity update: %s", error_msg)
		lua.pop(lua_state, 1)
	}
	
	// Clean up
	lua.pop(lua_state, 1) // Pop the entity table
}

// Release Lua references when entity is destroyed
lua_release_entity :: proc(entity: ^Entity) {
	if lua_state == nil || entity.lua_data_ref == 0 {
		return
	}
	
	lua.L_unref(lua_state, lua.REGISTRYINDEX, i32(entity.lua_data_ref))
	entity.lua_data_ref = 0
}

// Get the currently active entity (for API calls)
lua_get_current_entity :: proc() -> ^Entity {
	if lua_state == nil do return nil
	
	lua.getglobal(lua_state, LUA_CURRENT_ENTITY)
	entity := (^Entity)(lua.touserdata(lua_state, -1))
	lua.pop(lua_state, 1)
	
	return entity
}


package main

/*

Lua Scripting System

Handles Lua state initialization, script loading, and entity script management.

*/

import "core:log"
import "core:fmt"
import "core:c"
import "core:os"
import "core:strings"
import "core:path/filepath"
import "base:runtime"
import lua "vendor:lua/5.4"

// Global Lua state
lua_state: ^lua.State

// Script registry: maps script name -> Lua registry reference
lua_script_registry: map[string]int

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
	
	// Pre-load all Lua scripts
	lua_preload_all_scripts("res/scripts")
	
	log.info("Lua scripting system initialized successfully")
}

// Shutdown Lua state
lua_shutdown :: proc() {
	if lua_state != nil {
		// Clean up script registry
		for name, ref in lua_script_registry {
			lua.L_unref(lua_state, lua.REGISTRYINDEX, i32(ref))
			delete(name) // Free the cloned string key
		}
		delete(lua_script_registry)
		
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

// Pre-load all Lua scripts from a directory
lua_preload_all_scripts :: proc(scripts_dir: string) {
	if lua_state == nil {
		log.error("Lua state not initialized - cannot preload scripts")
		return
	}
	
	// Initialize the registry map
	lua_script_registry = make(map[string]int)
	
	log.infof("Pre-loading Lua scripts from: %s", scripts_dir)
	
	// Check if directory exists
	if !os.exists(scripts_dir) {
		log.warnf("Scripts directory not found: %s", scripts_dir)
		return
	}
	
	// Read directory contents
	dir_handle, open_err := os.open(scripts_dir)
	if open_err != 0 {
		log.errorf("Failed to open scripts directory: %s", scripts_dir)
		return
	}
	defer os.close(dir_handle)
	
	file_infos, read_err := os.read_dir(dir_handle, -1)
	if read_err != 0 {
		log.errorf("Failed to read scripts directory: %s", scripts_dir)
		return
	}
	defer os.file_info_slice_delete(file_infos)
	
	// Load each .lua file
	scripts_loaded := 0
	for file_info in file_infos {
		// Skip directories
		if file_info.is_dir do continue
		
		// Only process .lua files
		ext := filepath.ext(file_info.name)
		if ext != ".lua" do continue
		
		// Get script name without extension
		script_name := strings.trim_suffix(file_info.name, ".lua")
		
		// Build full path
		script_path := filepath.join({scripts_dir, file_info.name})
		defer delete(script_path)
		
		// Load and execute the script
		cpath := fmt.ctprintf("%s", script_path)
		load_result := lua.L_loadfile(lua_state, cpath)
		if load_result != .OK {
			error_msg := lua.tostring(lua_state, -1)
			log.errorf("Failed to load Lua script '%s': %s", script_path, error_msg)
			lua.pop(lua_state, 1)
			continue
		}
		
		// Execute the script (should return a table)
		if lua.pcall(lua_state, 0, 1, 0) != 0 {
			error_msg := lua.tostring(lua_state, -1)
			log.errorf("Failed to execute Lua script '%s': %s", script_path, error_msg)
			lua.pop(lua_state, 1)
			continue
		}
		
		// The script should return a table
		if !lua.istable(lua_state, -1) {
			log.errorf("Lua script '%s' did not return a table", script_path)
			lua.pop(lua_state, 1)
			continue
		}
		
		// Store the script table in the registry
		ref := lua.L_ref(lua_state, lua.REGISTRYINDEX)
		lua_script_registry[strings.clone(script_name)] = int(ref)
		
		log.infof("Pre-loaded script '%s' (ref: %d)", script_name, ref)
		scripts_loaded += 1
	}
	
	log.infof("Successfully pre-loaded %d Lua script(s)", scripts_loaded)
}

// Spawn a Lua entity from a pre-loaded script
spawn_lua_entity :: proc(script_name: string) -> ^Entity {
	if lua_state == nil {
		log.error("Lua state not initialized - call lua_init() first!")
		return nil
	}
	
	// Look up the script in the registry
	script_ref, found := lua_script_registry[script_name]
	if !found {
		log.errorf("Lua script '%s' not found in registry. Available scripts:", script_name)
		for name in lua_script_registry {
			log.infof("  - %s", name)
		}
		return nil
	}
	
	log.infof("Spawning Lua entity from script: %s", script_name)
	
	// Create the entity
	entity := entity_create(.lua_scripted)
	
	// Get the script table from the registry
	lua.rawgeti(lua_state, lua.REGISTRYINDEX, lua.Integer(script_ref))
	
	if !lua.istable(lua_state, -1) {
		log.errorf("Invalid script reference for '%s'", script_name)
		lua.pop(lua_state, 1)
		entity_destroy(entity)
		return nil
	}
	
	// Clone the script table for this entity instance
	// This ensures each entity has its own copy of the data
	lua.newtable(lua_state) // Create new table for this instance
	
	// Copy all fields from the script table to the instance table
	lua.pushnil(lua_state) // First key
	for lua.next(lua_state, -3) != 0 {
		// Stack: script_table, instance_table, key, value
		lua.pushvalue(lua_state, -2) // Copy key
		lua.pushvalue(lua_state, -2) // Copy value
		// Stack: script_table, instance_table, key, value, key, value
		lua.settable(lua_state, -5) // instance_table[key] = value
		// Stack: script_table, instance_table, key, value
		lua.pop(lua_state, 1) // Pop value, keep key for next iteration
	}
	// Stack: script_table, instance_table
	
	// Remove the script table, keep the instance table
	lua.remove(lua_state, -2)
	
	// Store the instance table in the registry
	ref := lua.L_ref(lua_state, lua.REGISTRYINDEX)
	entity.lua_data_ref = int(ref)
	entity.lua_script_name = strings.clone(script_name)
	
	log.infof("Spawned Lua entity from '%s' (instance ref: %d)", script_name, ref)
	
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
	
	// Free the script name string
	if entity.lua_script_name != "" {
		delete(entity.lua_script_name)
		entity.lua_script_name = ""
	}
}

// Get the currently active entity (for API calls)
lua_get_current_entity :: proc() -> ^Entity {
	if lua_state == nil do return nil
	
	lua.getglobal(lua_state, LUA_CURRENT_ENTITY)
	entity := (^Entity)(lua.touserdata(lua_state, -1))
	lua.pop(lua_state, 1)
	
	return entity
}

//
// Lua Entity Serialization
//

// Union type for Lua values that can be serialized
Lua_Value :: union {
	f64,
	bool,
	string,
}

// Save data for a Lua entity
Lua_Entity_Save_Data :: struct {
	script_name: string,
	entity_data: map[string]Lua_Value,
}

// Extract Lua entity data into a serializable format
lua_extract_entity_data :: proc(entity: ^Entity) -> Lua_Entity_Save_Data {
	data := Lua_Entity_Save_Data{
		script_name = strings.clone(entity.lua_script_name, context.temp_allocator),
		entity_data = make(map[string]Lua_Value, allocator = context.temp_allocator),
	}
	
	if lua_state == nil || entity.lua_data_ref == 0 {
		return data
	}
	
	// Push the entity table onto the stack
	lua.rawgeti(lua_state, lua.REGISTRYINDEX, lua.Integer(entity.lua_data_ref))
	
	if !lua.istable(lua_state, -1) {
		log.error("Invalid Lua entity reference during extraction")
		lua.pop(lua_state, 1)
		return data
	}
	
	// Iterate through all key-value pairs in the table
	lua.pushnil(lua_state) // First key
	for lua.next(lua_state, -2) != 0 {
		// Stack: table, key, value
		
		// Get the key (must be a string)
		if lua.type(lua_state, -2) == .STRING {
			key := lua.tostring(lua_state, -2)
			key_copy := strings.clone(string(key), context.temp_allocator)
			
			// Extract value based on type
			value_type := lua.type(lua_state, -1)
			#partial switch value_type {
				case .NUMBER:
					data.entity_data[key_copy] = f64(lua.tonumber(lua_state, -1))
				case .BOOLEAN:
					data.entity_data[key_copy] = bool(lua.toboolean(lua_state, -1))
				case .STRING:
					str := lua.tostring(lua_state, -1)
					data.entity_data[key_copy] = strings.clone(string(str), context.temp_allocator)
				case .FUNCTION:
					// Skip functions - they can't be serialized
				case .TABLE:
					// Skip nested tables for now (could be expanded later)
				case:
					log.warnf("Skipping Lua value of type %v for key '%s'", value_type, key)
			}
		}
		
		// Pop value, keep key for next iteration
		lua.pop(lua_state, 1)
	}
	
	// Pop the table
	lua.pop(lua_state, 1)
	
	log.infof("Extracted %d values from Lua entity '%s'", len(data.entity_data), data.script_name)
	
	return data
}

// Restore Lua entity data from saved data
lua_restore_entity_data :: proc(entity: ^Entity, data: Lua_Entity_Save_Data) {
	if lua_state == nil || entity.lua_data_ref == 0 {
		return
	}
	
	// Push the entity table onto the stack
	lua.rawgeti(lua_state, lua.REGISTRYINDEX, lua.Integer(entity.lua_data_ref))
	
	if !lua.istable(lua_state, -1) {
		log.error("Invalid Lua entity reference during restoration")
		lua.pop(lua_state, 1)
		return
	}
	
	// Set all saved values back into the table
	for key, value in data.entity_data {
		// Push the key
		lua.pushstring(lua_state, strings.clone_to_cstring(key, context.temp_allocator))
		
		// Push the value based on type
		switch v in value {
			case f64:
				lua.pushnumber(lua_state, lua.Number(v))
			case bool:
				lua.pushboolean(lua_state, b32(v))
			case string:
				lua.pushstring(lua_state, strings.clone_to_cstring(v, context.temp_allocator))
		}
		
		// Set table[key] = value
		lua.settable(lua_state, -3)
	}
	
	// Pop the table
	lua.pop(lua_state, 1)
	
	log.infof("Restored %d values to Lua entity '%s'", len(data.entity_data), data.script_name)
}


package main

/*

Lua API Bindings

Exposes Odin game functions to Lua scripts.

Uses lua_api_helpers.odin to reduce boilerplate.

*/

import "core:log"
import "core:fmt"
import "base:runtime"
import lua "vendor:lua/5.4"

// Register all Lua API functions
register_lua_api :: proc() {
	if lua_state == nil do return
	
	// Entity manipulation
	lua_register_func("get_pos", lua_api_get_pos)
	lua_register_func("set_pos", lua_api_set_pos)
	lua_register_func("get_flip_x", lua_api_get_flip_x)
	lua_register_func("set_flip_x", lua_api_set_flip_x)
	lua_register_func("get_rotation", lua_api_get_rotation)
	lua_register_func("set_rotation", lua_api_set_rotation)
	
	// Animation
	lua_register_func("set_animation", lua_api_set_animation)
	
	// Input
	lua_register_func("get_input_vector", lua_api_get_input_vector)
	lua_register_func("key_down", lua_api_key_down)
	lua_register_func("key_pressed", lua_api_key_pressed)
	
	// Helpers
	lua_register_func("delta_time", lua_api_delta_time)
	lua_register_func("game_time", lua_api_game_time)
	
	log.info("Registered Lua API functions")
}

// Helper to register a Lua function
lua_register_func :: proc(name: string, func: lua.CFunction) {
	lua.pushcfunction(lua_state, func)
	cname := fmt.ctprintf("%s", name)
	lua.setglobal(lua_state, cname)
}

// === Entity Manipulation API ===

// get_pos() -> {x, y}
lua_api_get_pos :: proc "c" (L: ^lua.State) -> i32 {
	context = runtime_context()
	entity, ok := current_entity_or_nil(L)
	if !ok do return 1
	return GETTER_VEC2(L, entity.pos)
}

// set_pos(x, y)
lua_api_set_pos :: proc "c" (L: ^lua.State) -> i32 {
	context = runtime_context()
	entity, ok := current_entity_or_nil(L)
	if !ok do return 0
	SETTER_VEC2(L, &entity.pos)
	return 0
}

// get_flip_x() -> bool
lua_api_get_flip_x :: proc "c" (L: ^lua.State) -> i32 {
	context = runtime_context()
	entity, ok := current_entity_or_nil(L)
	if !ok do return 1
	return GETTER_BOOL(L, entity.flip_x)
}

// set_flip_x(bool)
lua_api_set_flip_x :: proc "c" (L: ^lua.State) -> i32 {
	context = runtime_context()
	entity, ok := current_entity_or_nil(L)
	if !ok do return 0
	SETTER_BOOL(L, &entity.flip_x)
	return 0
}

// get_rotation() -> number
lua_api_get_rotation :: proc "c" (L: ^lua.State) -> i32 {
	context = runtime_context()
	entity, ok := current_entity_or_nil(L)
	if !ok do return 1
	return GETTER_F32(L, entity.rotation)
}

// set_rotation(angle)
lua_api_set_rotation :: proc "c" (L: ^lua.State) -> i32 {
	context = runtime_context()
	entity, ok := current_entity_or_nil(L)
	if !ok do return 0
	SETTER_F32(L, &entity.rotation)
	return 0
}

// === Animation API ===

// set_animation(sprite_name, frame_duration, loop)
lua_api_set_animation :: proc "c" (L: ^lua.State) -> i32 {
	context = runtime_context()
	entity, ok := current_entity_or_nil(L)
	if !ok do return 0
	
	if !check_args(L, 2) do return 0
	
	sprite_name := lua.tostring(L, 1)
	frame_duration := lua_to_f32(L, 2)
	loop := check_args(L, 3) ? lua_to_bool(L, 3) : true
	
	sprite, sprite_ok := string_to_sprite(sprite_name)
	if sprite_ok && sprite != .nil {
		entity_set_animation(entity, sprite, frame_duration, loop)
	}
	
	return 0
}

// === Input API ===

// get_input_vector() -> {x, y}
lua_api_get_input_vector :: proc "c" (L: ^lua.State) -> i32 {
	context = runtime_context()
	input_dir := get_input_vector()
	return GETTER_VEC2(L, input_dir)
}

// key_down(action_name) -> bool
lua_api_key_down :: proc "c" (L: ^lua.State) -> i32 {
	context = runtime_context()
	
	if !check_args(L, 1) {
		push_bool(L, false)
		return 1
	}
	
	action_name := lua.tostring(L, 1)
	action, ok := string_to_action(action_name)
	if !ok {
		push_bool(L, false)
		return 1
	}
	
	result := is_action_down(action)
	return GETTER_BOOL(L, result)
}

// key_pressed(action_name) -> bool
lua_api_key_pressed :: proc "c" (L: ^lua.State) -> i32 {
	context = runtime_context()
	
	if !check_args(L, 1) {
		push_bool(L, false)
		return 1
	}
	
	action_name := lua.tostring(L, 1)
	action, ok := string_to_action(action_name)
	if !ok {
		push_bool(L, false)
		return 1
	}
	
	result := is_action_pressed(action)
	return GETTER_BOOL(L, result)
}

// === Helper API ===

// delta_time() -> number
lua_api_delta_time :: proc "c" (L: ^lua.State) -> i32 {
	context = runtime_context()
	return GETTER_F32(L, ctx.delta_t)
}

// game_time() -> number
lua_api_game_time :: proc "c" (L: ^lua.State) -> i32 {
	context = runtime_context()
	push_f32(L, f32(ctx.gs.game_time_elapsed))
	return 1
}

// Global context for Lua C functions
runtime_context :: proc() -> runtime.Context {
	return runtime.default_context()
}

